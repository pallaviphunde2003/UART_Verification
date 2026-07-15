 //tx agent
class uart_tx_agent extends uvm_agent;
    `uvm_component_utils(uart_tx_agent)
  
    uart_tx_driver    drv;
    uart_tx_monitor   mon;
  
    uvm_sequencer #(uart_tx_transaction) sqr;
  
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
  
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
      
        mon = uart_tx_monitor::type_id::create("tx_mon", this);
      
        if (get_is_active() == UVM_ACTIVE) begin
            drv = uart_tx_driver::type_id::create("tx_drv", this);
            sqr = uvm_sequencer #(uart_tx_transaction)::type_id::create("tx_sqr", this);
        end
      
    endfunction
  
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (get_is_active() == UVM_ACTIVE) begin
            drv.seq_item_port.connect(sqr.seq_item_export);
        end
    endfunction
  
    virtual function void set_is_active(uvm_active_passive_enum mode);
        is_active = mode;
    endfunction
endclass
