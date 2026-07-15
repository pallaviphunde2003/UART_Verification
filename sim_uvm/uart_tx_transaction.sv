 class uart_tx_transaction extends uvm_sequence_item;
    `uvm_object_utils(uart_tx_transaction)
   
    typedef enum {TX_DATA, TX_CONFIG} tx_type_e;
    tx_type_e tx_type;
   
    rand bit [7:0] data;
    rand bit [31:0] baud_rate;
    rand bit [7:0]  data_width;
    rand bit [7:0]  parity_type;
    rand bit [7:0]  stop_bits;
    rand bit [7:0]  config_selector;
    int start_time;
    int end_time;
   
    function new(string name = "uart_tx_transaction");
        super.new(name);
    endfunction
   
    virtual function string convert2string();
        string s;
        s = $sformatf("TX type=%s data=0x%02x", tx_type.name(), data);
        if (tx_type == TX_CONFIG)
            s = {s, $sformatf(" baud=%0d width=%0d parity=%0d stops=%0d",
                   baud_rate, data_width, parity_type, stop_bits)};
        return s;
    endfunction
endclass
