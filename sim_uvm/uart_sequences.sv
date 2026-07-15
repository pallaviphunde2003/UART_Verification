class uart_tx_base_sequence extends uvm_sequence #(uart_tx_transaction);
    `uvm_object_utils(uart_tx_base_sequence)
  
    function new(string name = "uart_tx_base_sequence"); 
      super.new(name); 
    endfunction
  
endclass

class uart_config_sequence extends uart_tx_base_sequence;
    `uvm_object_utils(uart_config_sequence)
  
    rand int baud_rate; 
  	rand int data_width; 
  	rand int parity_type; 
  	rand int stop_bits;
  
    constraint c_baud   { baud_rate inside {[100:1000]}; }
    constraint c_width  { data_width inside {5,6,7,8}; }
    constraint c_parity { parity_type inside {0,1,2}; }
    constraint c_stop   { stop_bits inside {1,2}; }
  
    function new(string name="uart_config_sequence"); 
      super.new(name); 
    endfunction
  
    virtual task body();
        uart_tx_transaction tr;
        tr = uart_tx_transaction::type_id::create("tr");
        start_item(tr);
        tr.tx_type=uart_tx_transaction::TX_CONFIG; tr.config_selector=0; tr.baud_rate=baud_rate;
        finish_item(tr);
        tr = uart_tx_transaction::type_id::create("tr");
        start_item(tr);
        tr.tx_type=uart_tx_transaction::TX_CONFIG; tr.config_selector=1;
        tr.data_width=data_width; tr.parity_type=parity_type; tr.stop_bits=stop_bits;
        finish_item(tr);
    endtask
  
endclass

class uart_tx_sequence extends uart_tx_base_sequence;
    `uvm_object_utils(uart_tx_sequence)
  
    rand bit [7:0] tx_data;
  
    function new(string name="uart_tx_sequence"); 
      super.new(name); 
    endfunction
  
  
    virtual task body();
        uart_tx_transaction tr;
        tr = uart_tx_transaction::type_id::create("tr");
        start_item(tr);
        tr.tx_type=uart_tx_transaction::TX_DATA; tr.data=tx_data;
        finish_item(tr);
    endtask
  
endclass

class uart_loopback_sequence extends uart_tx_base_sequence;
    `uvm_object_utils(uart_loopback_sequence)
  
    rand int num_packets; 
  	
  	constraint c_num { num_packets inside {[1:10]}; }
  
    function new(string name="uart_loopback_sequence"); 
      super.new(name); 
    endfunction
    virtual task body();
        uart_tx_transaction tr;
        for (int i=0; i<num_packets; i++) begin
            tr = uart_tx_transaction::type_id::create("tr");
            start_item(tr);
            tr.tx_type=uart_tx_transaction::TX_DATA; tr.data=$urandom_range(0,255);
            finish_item(tr);
        end
    endtask
  
endclass

class uart_random_sequence extends uart_tx_base_sequence;
    `uvm_object_utils(uart_random_sequence)
  
    rand int num_transactions; 
  
  	constraint c_num { num_transactions inside {[10:50]}; }
  
    function new(string name="uart_random_sequence"); 
      super.new(name);
    endfunction
  
    virtual task body();
        uart_tx_transaction tr;
        uart_config_sequence cfg_seq;
        cfg_seq = uart_config_sequence::type_id::create("cfg_seq");
        cfg_seq.randomize(); cfg_seq.start(m_sequencer);
        for (int i=0; i<num_transactions; i++) begin
            tr = uart_tx_transaction::type_id::create("tr");
            start_item(tr);
            tr.randomize() with { tx_type == uart_tx_transaction::TX_DATA; };
            finish_item(tr);
        end
    endtask
  
endclass

class uart_rx_sequence extends uvm_sequence #(uart_rx_transaction);
    `uvm_object_utils(uart_rx_sequence)
  
    rand bit [7:0] rx_data;
  
    function new(string name="uart_rx_sequence"); 
      super.new(name); 
    endfunction
  
    virtual task body();
        uart_rx_transaction tr;
        tr = uart_rx_transaction::type_id::create("tr");
        start_item(tr);
        tr.rx_type=uart_rx_transaction::RX_DATA; tr.data=rx_data;
        finish_item(tr);
    endtask
endclass
