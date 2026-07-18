class uart_tx_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(uart_tx_scoreboard)

    uvm_analysis_imp #(uart_tx_transaction, uart_tx_scoreboard) expected_export;
    uvm_analysis_imp #(uart_tx_transaction, uart_tx_scoreboard) actual_export;

    uart_tx_transaction expected_queue[$];
    uart_tx_transaction actual_queue[$];
    int total_checked, pass_count, fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        expected_export = new("tx_expected_export", this);
        actual_export = new("tx_actual_export", this);
    endfunction

    virtual function void write_expected(uart_tx_transaction tr);
        if (tr.tx_type == uart_tx_transaction::TX_DATA) begin
            expected_queue.push_back(tr);
            check_queues();
        end
    endfunction

    virtual function void write_actual(uart_tx_transaction tr);
        if (tr.tx_type == uart_tx_transaction::TX_DATA) begin
            actual_queue.push_back(tr);
            check_queues();
        end
    endfunction

    virtual function void write(uart_tx_transaction tr);
        if (tr.start_time != 0) write_actual(tr);
        else write_expected(tr);
    endfunction

    virtual function void check_queues();
        uart_tx_transaction expected, actual;
        while (expected_queue.size() > 0 && actual_queue.size() > 0) begin
            expected = expected_queue.pop_front();
            actual = actual_queue.pop_front();
            total_checked++;
            if (expected.data === actual.data) begin
                pass_count++;
                `uvm_info("TX_SB", $sformatf("PASS: Sent=0x%02x TX'd=0x%02x",
                          expected.data, actual.data), UVM_MEDIUM)
            end else begin
                fail_count++;
                `uvm_error("TX_SB", $sformatf("FAIL: Sent=0x%02x TX'd=0x%02x",
                           expected.data, actual.data))
            end
        end
    endfunction

    virtual function void check_phase(uvm_phase phase);
        if (expected_queue.size() > 0)
            `uvm_error("TX_SB", $sformatf("%0d expected not transmitted", expected_queue.size()))
    endfunction

    virtual function void report_phase(uvm_phase phase);
        `uvm_info("TX_SB", "============================================", UVM_LOW)
        `uvm_info("TX_SB", "  TX SCOREBOARD REPORT", UVM_LOW)
        `uvm_info("TX_SB", $sformatf("  Total: %0d  Passed: %0d  Failed: %0d",
                  total_checked, pass_count, fail_count), UVM_LOW)
        `uvm_info("TX_SB", "============================================", UVM_LOW)
    endfunction
endclass
