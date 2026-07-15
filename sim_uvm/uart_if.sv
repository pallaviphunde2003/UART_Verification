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
endinterface    
    
    
    
