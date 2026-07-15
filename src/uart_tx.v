 module uart_tx #(
    /* Global Parameters */
   parameter PHY_FIFO_WIDTH  = 8,
   parameter UART_DATA_WIDTH = 8,
   parameter CONFIG_DATA_WIDTH = 40
)(
    /* Clock Signals */
    input                           i_Clock,
    input                           i_reset,
    
    /* Configuration Control Signal */
    input [CONFIG_DATA_WIDTH-1:0]   uart_config_data,
    input                           i_config_dv,
    
    /* UART Tx Signals */
    input                           i_Tx_DV,
    input [UART_DATA_WIDTH-1:0]     i_Tx_Byte,
    output                          o_Tx_Active,
    output reg                      o_Tx_Serial = 1,
    output                          o_Tx_Done
);

/* Local Paramters */
localparam BAUD_RATE_WIDTH   = 32;
localparam STOP_PARITY_WIDTH = 8;
localparam CONFIG_WIDTH      = 32;
localparam FIELD_SIZE        = 8;
/* Parity Type Definitions */
localparam NO_PARITY   = 0;
localparam EVEN_PARITY = 1;
localparam ODD_PARITY  = 2;

/* Register declaration and initialization */
reg [BAUD_RATE_WIDTH-1:0]   r_Clock_Count   = 0;
reg [2:0]                   r_Bit_Index     = 0;
reg [UART_DATA_WIDTH-1:0]   r_Tx_Data       = 0;
reg                         r_Tx_Done       = 0;
reg                         r_Tx_Active     = 0;
reg [STOP_PARITY_WIDTH:0]   r_Stop_Count    = 0;
reg                         r_Parity_Bit    = 0;

/* Configuration parsing registers */
reg [BAUD_RATE_WIDTH-1:0]   r_baud_rate   = 32'd437;
reg [STOP_PARITY_WIDTH-1:0] r_parity_type = 8'd0;
reg [STOP_PARITY_WIDTH-1:0] r_Stop_Bits   = 8'd1;
reg [UART_DATA_WIDTH-1:0]   r_data_width  = 8'd8;

/* State Machine Parameters */
reg [2:0] r_SM_Main = 0;
localparam s_IDLE           = 3'b000;
localparam s_TX_START_BIT   = 3'b001;
localparam s_TX_DATA_BITS   = 3'b010;
localparam s_TX_PARITY_BIT  = 3'b011;
localparam s_TX_STOP_BIT    = 3'b100;
localparam s_CLEANUP        = 3'b101;

always @(posedge i_Clock) begin
    if (i_reset) begin
        r_Clock_Count  <= 0;
        r_Bit_Index    <= 0;
        r_Tx_Data      <= 0;
        r_Tx_Done      <= 0;
        r_Tx_Active    <= 0;
        r_Stop_Count   <= 0;
        r_Parity_Bit   <= 0;
        r_baud_rate    <= 0;
        r_parity_type  <= 0;
        r_Stop_Bits    <= 0;
        r_data_width   <= 0;
        r_SM_Main      <= 0;
        o_Tx_Serial    <= 0;
    end else begin

        case (r_SM_Main)
            s_IDLE: begin
                /* Drive Line High for Idle */
                o_Tx_Serial <= 1'b1;
                r_Tx_Done <= 1'b0;
                r_Clock_Count <= 0;
                r_Bit_Index <= 0;
                r_Parity_Bit <= 0;
                r_Stop_Count <= 0;

                if (i_config_dv) begin 
                    if (uart_config_data[CONFIG_DATA_WIDTH - 1
                            : CONFIG_DATA_WIDTH - 8] == 0) begin
                        r_baud_rate <= uart_config_data[CONFIG_WIDTH - 1 : 0] - 1;

                    end else if (uart_config_data[CONFIG_DATA_WIDTH - 1
                            : CONFIG_DATA_WIDTH - 8] == 1) begin

                        r_data_width  <= uart_config_data[CONFIG_WIDTH - 1
                                : CONFIG_WIDTH - FIELD_SIZE];

                        r_parity_type <= uart_config_data[CONFIG_WIDTH - FIELD_SIZE - 1 
                                : CONFIG_WIDTH - 2 * FIELD_SIZE];

                        r_Stop_Bits <= uart_config_data[CONFIG_WIDTH - 2 * FIELD_SIZE - 1
                                : CONFIG_WIDTH - 3 * FIELD_SIZE];
                    end
                end

                if (i_Tx_DV == 1'b1) begin
                    r_Tx_Active <= 1'b1;
                    r_Tx_Data <= i_Tx_Byte;
                    r_SM_Main <= s_TX_START_BIT;
                end else begin
                    r_SM_Main <= s_IDLE;
                end
            end // case: s_IDLE

            /* Send out Start Bit. Start bit = 0 */
            s_TX_START_BIT: begin
                o_Tx_Serial <= 1'b0;

                /* Wait CLKS_PER_BIT-1 clock cycles for start bit to finish */
                if (r_Clock_Count < r_baud_rate) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main <= s_TX_START_BIT;
                end else begin
                    r_Clock_Count <= 0;
                    r_SM_Main <= s_TX_DATA_BITS;
                end
            end // case: s_TX_START_BIT

            /* Wait CLKS_PER_BIT-1 clock cycles for data bits to finish */
            s_TX_DATA_BITS: begin
                o_Tx_Serial <= r_Tx_Data[r_Bit_Index];

                /* Calculate parity bit */
                if (r_Clock_Count == 0) begin
                    r_Parity_Bit <= r_Parity_Bit ^ r_Tx_Data[r_Bit_Index];
                end

                if (r_Clock_Count < r_baud_rate) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main <= s_TX_DATA_BITS;
                end else begin
                    r_Clock_Count <= 0;

                    /* Check if we have sent out all bits based on data width */
                    if ({5'd0,r_Bit_Index} < (r_data_width - 1)) begin
                        r_Bit_Index <= r_Bit_Index + 1;
                        r_SM_Main <= s_TX_DATA_BITS;
                    end else begin
                        r_Bit_Index <= 0;

                        /* Check if parity is enabled */
                        if (r_parity_type != NO_PARITY) begin
                            r_SM_Main <= s_TX_PARITY_BIT;
                        end else begin
                            r_SM_Main <= s_TX_STOP_BIT;
                        end
                    end
                end
            end // case: s_TX_DATA_BITS

            /* Send out Parity bit if enabled */
            s_TX_PARITY_BIT: begin
                case (r_parity_type)
                    EVEN_PARITY: o_Tx_Serial <= r_Parity_Bit;      /* Even parity */
                    ODD_PARITY:  o_Tx_Serial <= ~r_Parity_Bit;     /* Odd parity */
                    default:     o_Tx_Serial <= 1'b0;              
                endcase

                if (r_Clock_Count < r_baud_rate) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main <= s_TX_PARITY_BIT;
                end else begin
                    r_Clock_Count <= 0;
                    r_Stop_Count <= 0;
                    r_SM_Main <= s_TX_STOP_BIT;
                end
            end // case: s_TX_PARITY_BIT

            s_TX_STOP_BIT: begin
                o_Tx_Serial <= 1'b1;

                /* Wait CLKS_PER_BIT-1 clock cycles for Stop bit to finish */
                if (r_Clock_Count < r_baud_rate) begin
                    r_Clock_Count <= r_Clock_Count + 1;
                    r_SM_Main <= s_TX_STOP_BIT;
                end else begin
                    r_Stop_Count <= r_Stop_Count + 1;
                    r_Clock_Count <= 0;

                    /* Check if we have sent all stop bits */
                    if (r_Stop_Count < (r_Stop_Bits - 1)) begin
                        r_SM_Main <= s_TX_STOP_BIT;
                    end else begin
                        r_Tx_Done <= 1'b1;
                        r_SM_Main <= s_CLEANUP;
                        r_Tx_Active <= 1'b0;
                    end
                end
            end // case: s_Tx_STOP_BIT

            s_CLEANUP: begin
                r_Tx_Done <= 1'b1;
                r_SM_Main <= s_IDLE;
            end

            default: r_SM_Main <= s_IDLE;
        endcase
    end
end

assign o_Tx_Active = r_Tx_Active;
assign o_Tx_Done = r_Tx_Done;

endmodule
