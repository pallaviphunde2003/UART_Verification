 //rx driver (Read Path)
class uart_rx_driver extends uvm_driver #(uart_rx_transaction);
    `uvm_component_utils(uart_rx_driver)
    virtual uart_if vif;
    int clks_per_bit;
    bit [7:0] data_width;
    bit [1:0] parity_type;
    bit [7:0] stop_bits;

    uvm_analysis_port #(uart_rx_transaction) exp_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        exp_ap = new("exp_ap", this);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "RX Driver: Virtual interface not found")
    endfunction
    virtual task run_phase(uvm_phase phase);
        uart_rx_transaction req;
      
        fork
            monitor_config();
        join_none
        forever begin
            seq_item_port.get_next_item(req);
            `uvm_info("RX_DRIVER", $sformatf("Driving RX frame: %s", req.convert2string()), UVM_MEDIUM)
            case (req.rx_type)
                uart_rx_transaction::RX_DATA:  drive_rx_frame(req);
                uart_rx_transaction::RX_ERROR: drive_error_frame(req);
            endcase
            seq_item_port.item_done();
        end
    endtask
    virtual task monitor_config();
        forever begin
            @(posedge vif.clk);
            
            if (vif.config_fifo_en) begin
                bit [39:0] cfg = vif.config_fifo_data;
                if (cfg[39:32] == 0) clks_per_bit = cfg[31:0];
                else if (cfg[39:32] == 1) begin
                    data_width  = cfg[31:24];
                    parity_type = cfg[23:16];
                    stop_bits   = cfg[15:8];
                end
            end
        end
    endtask
    virtual task drive_rx_frame(uart_rx_transaction req);
        bit parity_bit;
        int bit_time = clks_per_bit + 1;
        parity_bit = ^req.data;
        if (parity_type == 2) parity_bit = ~parity_bit;
        if (parity_type == 0) parity_bit = 0;

        
        begin
            uart_rx_transaction exp = uart_rx_transaction::type_id::create("exp_tr");
            exp.rx_type = uart_rx_transaction::RX_DATA;
            exp.data    = req.data;
            exp.serial_start_time = $time + 1;
            exp_ap.write(exp);
        end

        // Start bit
        vif.rx_serial <= 1'b0;
        repeat(bit_time) @(posedge vif.clk);
        // Data bits
        for (int i = 0; i < 8; i++) begin
            vif.rx_serial <= req.data[i];
            repeat(bit_time) @(posedge vif.clk);
        end
        // Parity
        if (parity_type != 0) begin
            vif.rx_serial <= parity_bit;
            repeat(bit_time) @(posedge vif.clk);
        end
        // Stop bits
        for (int j = 0; j < stop_bits; j++) begin
            vif.rx_serial <= 1'b1;
            repeat(bit_time) @(posedge vif.clk);
        end
        vif.rx_serial <= 1'b1;
    endtask
    virtual task drive_error_frame(uart_rx_transaction req);
        bit parity_bit;
        int bit_time = clks_per_bit + 1;
        
        parity_bit = ^req.data;
        if (parity_type == 1) parity_bit = ~parity_bit;
        if (parity_type == 2) parity_bit = parity_bit;
        vif.rx_serial <= 1'b0;
        repeat(bit_time) @(posedge vif.clk);
        for (int i = 0; i < 8; i++) begin
            vif.rx_serial <= req.data[i];
            repeat(bit_time) @(posedge vif.clk);
        end
        if (parity_type != 0) begin
            vif.rx_serial <= parity_bit;
            repeat(bit_time) @(posedge vif.clk);
        end
        vif.rx_serial <= 1'b1;
        repeat(bit_time) @(posedge vif.clk);
        vif.rx_serial <= 1'b1;
    endtask
    virtual function void set_config(int baud, bit [7:0] width, bit [1:0] parity, bit [7:0] stops);
        clks_per_bit = baud; data_width = width; parity_type = parity; stop_bits = stops;
    endfunction
endclass
