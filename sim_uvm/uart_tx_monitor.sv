 class uart_tx_monitor extends uvm_monitor;
    `uvm_component_utils(uart_tx_monitor)
   
    virtual uart_if vif;
    uvm_analysis_port #(uart_tx_transaction) ap;
    int clks_per_bit;
    bit [7:0] data_width;
    bit [1:0] parity_type;
    bit [7:0] stop_bits;
   
    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
   
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("tx_ap", this);
        if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF", "TX Monitor: Virtual interface not found")
    endfunction
          
    virtual task run_phase(uvm_phase phase);
        fork
            monitor_config();
            monitor_serial_output();
        join_none
    endtask
      
    virtual task monitor_config();
        forever begin
            @(posedge vif.clk);

            if (vif.config_fifo_en) begin
                bit [39:0] cfg = vif.config_fifo_data;
                if (cfg[39:32] == 0) clks_per_bit = cfg[31:0];
                else if (cfg[39:32] == 1) begin
                    data_width = cfg[31:24]; 
                  	parity_type = cfg[23:16]; 
                  	stop_bits = cfg[15:8];
                end
            end
        end
    endtask
      
      
    virtual task monitor_serial_output();
        bit [7:0] shift_reg; 
      	bit [3:0] bit_count; 
      	int timer;
        bit parity_calc;
      	bit parity_received; 
      	bit [7:0] stop_count; 
      	bit [2:0] state;
      
        int frame_start_time;
      
        localparam IDLE=3'd0; 
     	localparam START=3'd1; 
      	localparam DATA=3'd2; 
      	localparam PARITY=3'd3;
      	localparam STOP=3'd4;
      
        state = IDLE;
      
        forever begin
            @(posedge vif.clk);
            case (state)
                IDLE: begin
                    timer=0; 
                  	bit_count=0; 
                  	parity_calc=0; 
                  	stop_count=0;
                    if (vif.tx_serial==0 && vif.tx_active) begin
                        state=START; frame_start_time=$time;
                    end
                end
                START: begin
                    if (timer==(clks_per_bit>>1)) begin
                        if (vif.tx_serial==0) 
                          begin timer=0; 
                            state=DATA; 
                          end
                        else state=IDLE;
                    end else timer++;
                end
                DATA: begin
                    if (timer<clks_per_bit) timer++;
                    else begin
                        timer=0; 
                      	shift_reg[bit_count]=vif.tx_serial;
                        parity_calc=parity_calc^vif.tx_serial;
                        if (bit_count<(data_width-1)) bit_count++;
                        else begin bit_count=0; state=(parity_type!=0)?PARITY:STOP; end
                    end
                end
                PARITY: begin
                    if (timer<clks_per_bit) timer++;
                    else begin timer=0; parity_received=vif.tx_serial; state=STOP; end
                end
                STOP: begin
                    if (timer<clks_per_bit) timer++;
                    else begin
                        timer=0;
                        if (vif.tx_serial!=1'b1) begin state=IDLE; end
                        else if (stop_count<(stop_bits-1)) stop_count++;
                        else begin
                            uart_tx_transaction tr=new("tx_mon_tr");
                            tr.tx_type=uart_tx_transaction::TX_DATA;
                            tr.data=shift_reg; tr.start_time=frame_start_time; tr.end_time=$time;
                            ap.write(tr);
                            `uvm_info("TX_MON", $sformatf("TX frame captured: 0x%02x", shift_reg), UVM_MEDIUM)
                            state=IDLE;
                        end
                    end
                end
            endcase
        end
    endtask
endclass
