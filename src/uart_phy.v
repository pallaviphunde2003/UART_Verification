 module uart_phy#(
    /* Global Parameters */
    parameter PHY_FIFO_WIDTH  = 8,
    parameter UART_DATA_WIDTH = 8,
    parameter CONFIG_DATA_WIDTH = 40
)(
    /* Clock inputs */
    input                           clk,
    /* UART Signals */
    output                          tx_active,
    output                          tx_done,
    output                          tx_serial,
    input                           rx_serial,
    
    /* wr_phy_fifo access */
    input                           wr_phy_fifo_empty,
    output                          wr_phy_fifo_en,
    input [PHY_FIFO_WIDTH-1:0]      wr_phy_fifo_data,
    
    /* Config_fifo access */
    output                          config_fifo_en,
    input [CONFIG_DATA_WIDTH-1:0]   config_fifo_data,
    input                           config_fifo_empty,
    
    /* rd_phy_fifo access */
    output                          rd_phy_fifo_en,
    output [PHY_FIFO_WIDTH-1:0]     rd_phy_fifo_data,
    /*reset uart */
    output reg                      reset
);
/* Connecting Wires */
wire                        w_uart_dv;
wire [PHY_FIFO_WIDTH-1:0]   w_uart_data;
/* Configuration FIFO access */
reg                         flag_data_sample = 0;
reg [CONFIG_DATA_WIDTH-1:0] r_config_data = 0;
reg                         r_config_fifo_en = 0;
reg                         r_config_dv = 0;
assign config_fifo_en = r_config_fifo_en;
always @(posedge clk) begin
    if(!config_fifo_empty) 
        r_config_fifo_en <= 1;
    else 
        r_config_fifo_en <= 0;
    
    if (r_config_fifo_en) 
        flag_data_sample <= 1;
    else 
        flag_data_sample <= 0;
    
    if(flag_data_sample) begin
        if (config_fifo_data == 40'hffffffffff) 
            reset <= 1;
        else begin
            reset <= 0;
            r_config_data <= config_fifo_data;
            r_config_dv <= 1; 
        end    
    end else begin
        r_config_data <= r_config_data;
        r_config_dv <= 0;
        reset <= 0;
    end
end
/* Module Instantiation */
/* UART Tx Modules */
uart_ctrl #(
    .PHY_FIFO_WIDTH(PHY_FIFO_WIDTH),
    .UART_DATA_WIDTH(PHY_FIFO_WIDTH)
) uart_write_ctrl(
    .clk            (clk),
    .i_reset        (reset),
    .f_empty        (wr_phy_fifo_empty),
    .fifo_read_en   (wr_phy_fifo_en),
    .fifo_read_data (wr_phy_fifo_data),
    .uart_tx_done   (tx_done),
    .uart_dv        (w_uart_dv),
    .uart_data      (w_uart_data)
);
uart_tx #(
    .PHY_FIFO_WIDTH(PHY_FIFO_WIDTH),
    .UART_DATA_WIDTH(PHY_FIFO_WIDTH),
    .CONFIG_DATA_WIDTH(CONFIG_DATA_WIDTH)
) uarttx (
    .i_Clock            (clk),
    .i_Tx_DV            (w_uart_dv),
    .i_Tx_Byte          (w_uart_data),
    .i_config_dv        (r_config_dv),
    .i_reset            (reset),
    .uart_config_data   (r_config_data),
    .o_Tx_Active        (tx_active),
    .o_Tx_Serial        (tx_serial),
    .o_Tx_Done          (tx_done)
);
/* UART Rx Modules */
uart_rx #(
    .PHY_FIFO_WIDTH(PHY_FIFO_WIDTH),
    .UART_DATA_WIDTH(PHY_FIFO_WIDTH),
    .CONFIG_DATA_WIDTH(CONFIG_DATA_WIDTH)
) uartrx(
    .i_Clock            (clk),
    .i_Rx_Serial        (rx_serial),
    .i_config_dv        (r_config_dv),
    .i_reset            (reset),
    .uart_config_data   (r_config_data),
    .o_Rx_DV            (rd_phy_fifo_en),
    .o_Rx_Byte          (rd_phy_fifo_data)
);
endmodule
