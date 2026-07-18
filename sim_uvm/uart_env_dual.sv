class uart_env extends uvm_env;
    `uvm_component_utils(uart_env)
  // Tx Path (Write: CPU - UART - Serial)
    uart_tx_agent      tx_agent;
    uart_tx_scoreboard tx_sb;
    // Coverage
    uart_coverage_collector cov_collector;
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // tx path
        tx_agent = uart_tx_agent::type_id::create("tx_agent", this);
        tx_agent.set_is_active(UVM_ACTIVE);
        tx_sb = uart_tx_scoreboard::type_id::create("tx_sb", this);
    endfunction
    function void connect_phase(phase);
    	super.connect_phase(phase);
    	//tx:monitor capture serial output - scoreboard compares with expected 
    	tx_agent.mon.ap.connect(tx_sb.actual_export);
        tx_agent.drv.exp_ap.connect(tx_sb.expected_export);
    endfunction
    virtual function void report_phase(uvm_phase phase);
        `uvm_info("ENV", "============================================", UVM_LOW)
        `uvm_info("ENV", "  UART ENVIRONMENT FINAL REPORT", UVM_LOW)
        `uvm_info("ENV", "  TX Path: CPU → FIFO → uart_ctrl → uart_tx → Serial", UVM_LOW)
	`uvm_info("ENV", "============================================", UVM_LOW)
    endfunction
endclass

