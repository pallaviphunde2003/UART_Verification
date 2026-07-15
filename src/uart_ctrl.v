 module uart_ctrl #(
    /* Global Parameters */
    parameter PHY_FIFO_WIDTH  = 8,
    parameter UART_DATA_WIDTH = 8
 )(
    /* Clock Signal */
    input                           clk,
    input                           i_reset,
    /* FIFO Signals */
    input                           f_empty,
    input [PHY_FIFO_WIDTH-1:0]      fifo_read_data,
    output                          fifo_read_en,
    /* UART Tx Signals */
    input                           uart_tx_done,
    output                          uart_dv,
    output [UART_DATA_WIDTH-1:0]    uart_data
);
/* Register declaration and instantiations */
reg                                 r_fifo_read_en = 0;
reg                                 r_uart_dv = 0;
reg [UART_DATA_WIDTH-1:0]           r_uart_data = 0;
/* State Machine Parameters */
reg [1:0] state = 0;
localparam IDLE     = 2'b00;
localparam READ     = 2'b01;
localparam TRANSFER = 2'b10;
localparam ACK      = 2'b11;
always @(posedge clk) begin
    if(i_reset) begin
        r_fifo_read_en  <= 0;
        r_uart_dv       <= 0;
        r_uart_data     <= 0;
        state           <= 0;
    end else begin
        case (state)
            IDLE: begin
                r_uart_dv <= 0;
                r_uart_data <= 0;
                if(!f_empty) begin
                    state <= READ;
                    r_fifo_read_en <= 1;
                end else begin
                    state <= IDLE;
                end
            end
            READ: begin
                r_fifo_read_en <= 0;
                state <= TRANSFER;
            end
            TRANSFER: begin
                r_uart_dv <= 1;
                r_uart_data <= fifo_read_data;
                state <= ACK;
            end
            ACK: begin
                r_uart_dv <= 0;
                r_uart_data <= 0;
                if(uart_tx_done) begin
                    state <= IDLE;
                end else begin
                    state <= ACK;
                end
            end
        endcase
    end
end
assign uart_dv = r_uart_dv;
assign uart_data = r_uart_data;
assign fifo_read_en = r_fifo_read_en;
endmodule
