class uart_rx_transaction extends uvm_sequence_item;
    `uvm_object_utils(uart_rx_transaction)

    typedef enum {RX_DATA, RX_ERROR, RX_CONFIG} rx_type_e;
    rx_type_e rx_type;
    rand bit [7:0] data;
  
    bit       parity_error;
    bit       frame_error;
    bit       overflow_error;
    bit [7:0] expected_data_width;
    bit [1:0] expected_parity_type;
    bit [7:0] expected_stop_bits;
    int       start_time;
    int       end_time;
    int       serial_start_time;
    bit [7:0] expected_data;
    bit       match;

    function new(string name = "uart_rx_transaction");
        super.new(name);
    endfunction

    virtual function string convert2string();
        string s;
        s = $sformatf("RX type=%s data=0x%02x", rx_type.name(), data);
        if (parity_error) s = {s, " PARITY_ERR"};
        if (frame_error)  s = {s, " FRAME_ERR"};
        return s;
    endfunction
endclass
