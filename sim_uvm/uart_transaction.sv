`ifndef UART_TRANSACTION_SV
`define UART_TRANSACTION_SV

class uart_transaction extends uvm_sequence_item;
    `uvm_object_utils(uart_transaction)
  
    typedef enum { TX_DATA, RX_DATA, CONFIG } tx_type_e;
    rand tx_type_e tx_type;
    rand bit [7:0] data;
    rand bit [1:0] parity_type;
    rand bit [7:0] stop_bits;
    rand bit [7:0] data_width;
    rand int baud_rate;
    rand bit [7:0] config_selector;
    bit parity_error;
    bit frame_error;
  
    function new(string name = "uart_transaction");
        super.new(name);
    endfunction
  
    virtual function string convert2string();
        return $sformatf("type=%s data=0x%02x parity=%0d stop=%0d width=%0d baud=%0d",
            tx_type.name(), data, parity_type, stop_bits, data_width, baud_rate);
    endfunction
  
endclass
`endif
