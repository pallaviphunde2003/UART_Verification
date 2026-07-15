 module uart_rx #(
    /* Global Parameters */
    parameter PHY_FIFO_WIDTH  = 8,
    parameter UART_DATA_WIDTH = 8,
    parameter CONFIG_DATA_WIDTH = 40
)(
    /* Clock Signals */
    input                          i_Clock,

    /* Configuration Control Signals */
    input [CONFIG_DATA_WIDTH-1:0]  uart_config_data,
    input                          i_config_dv,
    input                          i_reset,
    

    /* UART Rx Signals */
    input                          i_Rx_Serial,
    output                         o_Rx_DV,
    output [UART_DATA_WIDTH-1:0]   o_Rx_Byte
);


/* Local Parameters */
localparam BAUD_RATE_WIDTH   = 32;
localparam STOP_PARITY_WIDTH = 8;
localparam CONFIG_WIDTH      = 32;
localparam FIELD_SIZE        = 8;

/* Parity Type Definitions */
localparam NO_PARITY   = 0;
localparam EVEN_PARITY = 1;
localparam ODD_PARITY  = 2;

/* Register declaration and Initialization */
reg [BAUD_RATE_WIDTH-1:0]   r_Clock_Count     = 0;
reg [2:0]                   r_Bit_Index       = 0;
reg [UART_DATA_WIDTH-1:0]   r_Rx_Byte         = 0;
reg                         r_Rx_DV           = 0;
reg [STOP_PARITY_WIDTH-1:0] r_Stop_Count      = 0;
reg                         r_Parity_Bit      = 0;
reg                         r_Received_Parity = 0;

/* Configuration parsing registers */
reg [UART_DATA_WIDTH-1:0]   r_data_width  = 8'd8;
reg [STOP_PARITY_WIDTH-1:0] r_Parity_Type = 8'd0;
reg [STOP_PARITY_WIDTH-1:0] r_Stop_Bits   = 8'd1;
reg [BAUD_RATE_WIDTH-1:0]   r_baud_rate   = 32'd437;

/* State Machine Parameters */ 
reg [2:0]  r_SM_Main       = 0; 
localparam s_IDLE          = 3'b000;
localparam s_RX_START_BIT  = 3'b001;
localparam s_RX_DATA_BITS  = 3'b010;
localparam s_RX_PARITY_BIT = 3'b011;
localparam s_RX_STOP_BIT   = 3'b100;
localparam s_CLEANUP       = 3'b101;

/* To avoid metastability */
reg r_Rx_Data_R = 1'b1;
reg r_Rx_Data   = 1'b1;


/* Main FSM */
always @(posedge i_Clock) begin
    if (i_reset) begin
        r_baud_rate       <= 0;         
        r_Bit_Index       <= 0;
        r_Received_Parity <= 0;  
        r_Clock_Count     <= 0;
        r_data_width      <= 0;
        r_Parity_Bit      <= 0;
        r_Parity_Type     <= 0;
        r_Rx_Byte         <= 0;
        r_Rx_Data         <= 1; 
        r_Rx_Data_R       <= 1;  
        r_Rx_DV           <= 0;
        r_SM_Main         <= 0;
        r_Stop_Bits       <= 0;
        r_Stop_Count      <= 0;
    end else begin
        r_Rx_Data_R <= i_Rx_Serial;
        r_Rx_Data   <= r_Rx_Data_R;

        case (r_SM_Main)
            s_IDLE : begin
                r_Rx_DV       <= 1'b0;
                r_Clock_Count <= 0;
                r_Bit_Index   <= 0;
                r_Rx_Byte     <= 0;
                r_Parity_Bit  <= 0;
                r_Stop_Count  <= 0;

                if (i_config_dv) begin 
                    if (uart_config_data[CONFIG_DATA_WIDTH - 1
                            : CONFIG_DATA_WIDTH - 8] == 0) begin    
                        r_baud_rate <= uart_config_data[CONFIG_WIDTH - 1 : 0] - 1;  
                    end else if (uart_config_data[CONFIG_DATA_WIDTH - 1
                            : CONFIG_DATA_WIDTH - 8] == 1) begin    
                        r_data_width <= uart_config_data[CONFIG_WIDTH - 1
                                : CONFIG_WIDTH - FIELD_SIZE];   
                        r_Parity_Type <= uart_config_data[CONFIG_WIDTH - FIELD_SIZE - 1 
                                : CONFIG_WIDTH - 2 * FIELD_SIZE];   
                        r_Stop_Bits <=
                                uart_config_data[CONFIG_WIDTH - 2 * FIELD_SIZE - 1
                                    : CONFIG_WIDTH - 3 * FIELD_SIZE];
                    end
                end 
                /* Check if the line is idle */
                if (r_Rx_Data == 1'b0) begin  
                    r_SM_Main <= s_RX_START_BIT;
                end else begin
                    r_SM_Main <= s_IDLE;
                end
            end

            s_RX_START_BIT : begin
                if (r_Clock_Count == (r_baud_rate >> 1)) begin
                    if (r_Rx_Data == 1'b0) begin
                        /* reset counter, found the middle */
                        r_Clock_Count <= 0;
                        r_SM_Main     <= s_RX_DATA_BITS;
                    end else begin
                        r_SM_Main <= s_IDLE;
                    end
                end else begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main     <= s_RX_START_BIT;
                end
            end
        
            s_RX_DATA_BITS : begin
                if (r_Clock_Count < r_baud_rate) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main     <= s_RX_DATA_BITS;
                end else begin
                    r_Clock_Count          <= 0;
                    r_Rx_Byte[r_Bit_Index] <= r_Rx_Data;

                    /* Calculate parity bit */
                    r_Parity_Bit <= r_Parity_Bit ^ r_Rx_Data;

                    /* Check if we have received all bits based on data width */
                    if ({5'd0,r_Bit_Index} < (r_data_width - 1)) begin
                        r_Bit_Index <= r_Bit_Index + 1;
                        r_SM_Main   <= s_RX_DATA_BITS;
                    end else begin
                        r_Bit_Index <= 0;

                        /* Check if parity is enabled */
                        if (r_Parity_Type != NO_PARITY) begin
                            r_SM_Main    <= s_RX_PARITY_BIT;
                        end else begin
                            r_SM_Main    <= s_RX_STOP_BIT;
                            r_Stop_Count <= 0;
                        end
                    end
                end
            end
        
            /* Receive Parity bit if enabled */
            s_RX_PARITY_BIT : begin
                if (r_Clock_Count < r_baud_rate) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main     <= s_RX_PARITY_BIT;
                end else begin
                    r_Clock_Count     <= 0;
                    r_Received_Parity <= r_Rx_Data;
                    r_Stop_Count      <= 0;
                    r_SM_Main         <= s_RX_STOP_BIT;
                end
            end
        
            /* Receive Stop bit.  Stop bit = 1 */
            s_RX_STOP_BIT : begin
                /* Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish */
                if (r_Clock_Count < r_baud_rate) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main     <= s_RX_STOP_BIT;
                end else begin
                    r_Clock_Count <= 0;

                    /* Check if stop bit is valid */
                    if (r_Rx_Data == 1'b1) begin
                        r_Stop_Count <= r_Stop_Count + 1;

                        /* Check if we have received all stop bits */
                        if (r_Stop_Count >= (r_Stop_Bits - 1)) begin
                            r_SM_Main <= s_CLEANUP;

                            /* Check parity if enabled */
                            if (r_Parity_Type != NO_PARITY) begin
                                case (r_Parity_Type)
                                    EVEN_PARITY: r_Rx_DV <=
                                            r_Parity_Bit == r_Received_Parity;

                                    ODD_PARITY: r_Rx_DV <=
                                            r_Parity_Bit != r_Received_Parity;

                                    default: r_Rx_DV <= 1'b1;
                                endcase
                            end else begin
                                r_Rx_DV <= 1'b1;
                            end
                        end else begin
                            r_SM_Main <= s_RX_STOP_BIT;
                        end
                    end else begin
                        r_Rx_DV <= 1'b0;
                        r_SM_Main <= s_CLEANUP;
                    end
                end
            end
        
            /* Stay here 1 clock */
            s_CLEANUP : begin
                r_SM_Main <= s_IDLE;
                r_Rx_DV   <= 1'b0;
            end
        
            default : r_SM_Main <= s_IDLE;
        endcase
    end
end

assign o_Rx_DV   = r_Rx_DV;
assign o_Rx_Byte = r_Rx_DV ? r_Rx_Byte : 0;

endmodule
