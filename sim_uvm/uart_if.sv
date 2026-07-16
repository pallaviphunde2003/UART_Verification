  interface uart_if (
    input logic clk
);
    logic reset;
    logic tx_active; 
   	logic tx_done; 
   	logic tx_serial;
    logic rx_serial;
    logic wr_phy_fifo_empty;
   	logic wr_phy_fifo_en;
   
    logic [7:0] wr_phy_fifo_data;
    logic config_fifo_en;
    logic [39:0] config_fifo_data;
    logic config_fifo_empty;
    logic rd_phy_fifo_en;
    logic [7:0] rd_phy_fifo_data;
   
    clocking cb @(posedge clk);
        input  reset;
      
        output wr_phy_fifo_empty; 
      	output wr_phy_fifo_data;
        output config_fifo_empty; 
      	output config_fifo_data;
        output rx_serial;
      
        input tx_active; 
      	input tx_done; 
      	input tx_serial;
        input wr_phy_fifo_en; 
      	input config_fifo_en;
        input rd_phy_fifo_en; 
      	input rd_phy_fifo_data;
      
    endclocking
   
    modport DUT (
        input clk, 
      	input wr_phy_fifo_empty, 
      	input wr_phy_fifo_data,
        input config_fifo_empty, 
      	input config_fifo_data, 
      	input rx_serial,
        output tx_active, 
      	output tx_done, 
      	output tx_serial, 
      	output reset,
        output wr_phy_fifo_en, 
      	output config_fifo_en,
        output rd_phy_fifo_en, 
      	output rd_phy_fifo_data
    );
   
    modport TB (clocking cb);
    task automatic send_config(input [39:0] cfg);
        cb.config_fifo_empty <= 1'b0;
        cb.config_fifo_data  <= cfg;
        @(cb);
        cb.config_fifo_empty <= 1'b1;
        repeat(5) @(cb);
    endtask
      
    task automatic send_tx_data(input [7:0] data);
        cb.wr_phy_fifo_empty <= 1'b0;
        cb.wr_phy_fifo_data  <= data;
        @(cb);
        cb.wr_phy_fifo_empty <= 1'b1;
    endtask
      
    task automatic send_rx_frame(
        input [7:0] data, input [1:0] parity_type,
        input [7:0] stop_bits, input [31:0] baud_rate
    );
       
      	reg parity_bit;
        int bit_time;
        bit_time = baud_rate + 1;
        parity_bit = ^data;
      
        if (parity_type == 2) parity_bit = ~parity_bit;
        if (parity_type == 0) parity_bit = 0;
      
        cb.rx_serial <= 1'b0;
        repeat(bit_time) @(cb);
      
        for (int i = 0; i < 8; i++) begin
            cb.rx_serial <= data[i];
            repeat(bit_time) @(cb);
        end
        if (parity_type != 0) begin
            cb.rx_serial <= parity_bit;
            repeat(bit_time) @(cb);
        end
        for (int j = 0; j < stop_bits; j++) begin
            cb.rx_serial <= 1'b1;
            repeat(bit_time) @(cb);
        end
        cb.rx_serial <= 1'b1;
    endtask
      
    task automatic wait_for_tx_done();
        @(posedge cb.tx_done);
    endtask
    task automatic wait_for_rx_dv(output [7:0] data);
        @(posedge cb.rd_phy_fifo_en);
        data = cb.rd_phy_fifo_data;
    endtask
endinterface
