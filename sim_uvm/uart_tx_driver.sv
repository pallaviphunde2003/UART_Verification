//tx driver  (write path)
class uart_tx_driver extends uvm_driver #(uart_tx_transaction);
    `uvm_component_utils(uart_tx_driver)
  
    virtual uart_if vif;
    int clks_per_bit;
    bit [7:0] current_data_width;
    bit [1:0] current_parity_type;
    bit [7:0] current_stop_bits;

    uvm_analysis_port #(uart_tx_transaction) exp_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
  
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_ap = new("exp_ap", this);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "TX Driver: Virtual interface not found")
    endfunction
          
    virtual task run_phase(uvm_phase phase);
        uart_tx_transaction req;
        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info("TX_DRIVER", $sformatf("Driving: %s", req.convert2string()), UVM_MEDIUM)
            case (req.tx_type)
                uart_tx_transaction::TX_CONFIG: drive_config(req);
                uart_tx_transaction::TX_DATA:  drive_tx_data(req);
            endcase
            seq_item_port.item_done();
        end
    endtask
      
    virtual task drive_config(uart_tx_transaction req);
        bit [39:0] config_word;
        if (req.config_selector == 0) begin
            config_word = {8'd0, req.baud_rate};
            clks_per_bit = req.baud_rate;
        end else begin
            config_word = {8'd1, req.data_width, req.parity_type, req.stop_bits, 8'd0};
            current_data_width = req.data_width;
            current_parity_type = req.parity_type;
            current_stop_bits = req.stop_bits;
        end
        @(posedge vif.clk);
        vif.config_fifo_empty <= 1'b0;
        vif.config_fifo_data  <= config_word;
        @(posedge vif.clk);
        vif.config_fifo_empty <= 1'b1;
        repeat(5) @(posedge vif.clk);
    endtask
      
    virtual task drive_tx_data(uart_tx_transaction req);

        uart_tx_transaction exp = uart_tx_transaction::type_id::create("exp_tr");
        exp.tx_type = uart_tx_transaction::TX_DATA;
        exp.data    = req.data;
        exp_ap.write(exp);

        @(posedge vif.clk);
        vif.wr_phy_fifo_empty <= 1'b0;
        vif.wr_phy_fifo_data  <= req.data;
        @(posedge vif.clk);
        vif.wr_phy_fifo_empty <= 1'b1;
        @(posedge vif.tx_done);
        `uvm_info("TX_DRIVER", $sformatf("TX done for data: 0x%02x", req.data), UVM_HIGH)
    endtask
endclass
