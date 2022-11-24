module controller_fsm #(
  parameter int LOG2_OF_MEM_HEIGHT = 20,
  parameter int FEATURE_MAP_WIDTH = 1024,
  parameter int FEATURE_MAP_HEIGHT = 1024,
  parameter int INPUT_NB_CHANNELS = 64,
  parameter int OUTPUT_NB_CHANNELS = 64,
  parameter int KERNEL_SIZE = 3
  )
  (input logic clk,
  input logic arst_n_in, //asynchronous reset, active low

  input logic start,
  output logic running,

  //memory control interface
  output logic mem_we,
  output logic [LOG2_OF_MEM_HEIGHT-1:0] mem_write_addr,
  output logic mem_re,
  output logic [LOG2_OF_MEM_HEIGHT-1:0] mem_read_addr,

  //datapad control interface & external handshaking communication of a and b
  input logic data_ready,
  output logic int_mem_re,

  output logic fsm_done,

  input logic a_valid,
  input logic b_valid,
  output logic b_ready,
  output logic a_ready,
  output logic write_a,
  output logic write_b,
  output logic mac_valid,
  output logic mac_accumulate_internal,
  output logic mac_accumulate_with_0,

  output logic [31:0] ky_out,
  output logic [31:0] kx_out,
  output logic [31:0] outch_out,
  output logic [31:0] inch_out,
  output logic [31:0] y_out,
  output logic [31:0] x_out,

  output logic output_valid,
  output logic [32-1:0] output_x,
  output logic [32-1:0] output_y,
  output logic [32-1:0] output_ch

  );

  typedef enum {IDLE, LOAD, FETCH, MAC, MAC2} fsm_state;
  fsm_state current_state;
  fsm_state next_state;
  always @ (posedge clk or negedge arst_n_in) begin
    if(arst_n_in==0) begin
      current_state <= IDLE;
    end else begin
      current_state <= next_state;
    end
  end

  //loop counters (see register.sv for macro)
  `REG(32, k_v);
  `REG(32, k_h);
  `REG(32, x);
  `REG(32, y);
  `REG(32, ch_in);
  `REG(32, ch_out);

  //addr counters (see register.sv for macro)
  `REG(32, k_v_m);
  `REG(32, k_h_m);
  `REG(32, x_m);
  `REG(32, y_m);
  `REG(32, ch_in_m);
  `REG(32, ch_out_m);

  logic reset_k_v, reset_k_h, reset_x, reset_y, reset_ch_in, reset_ch_out;
  assign k_v_next = reset_k_v ? 0 : k_v + 1;
  assign k_h_next = reset_k_h ? 0 : k_h + 1;
  assign x_next = reset_x ? 0 : x + 1;
  assign y_next = reset_y ? 0 : y + 1;
  assign ch_in_next = reset_ch_in ? 0 : ch_in + 1;
  assign ch_out_next = reset_ch_out ? 0 : ch_out + 1;

  logic reset_k_v_m, reset_k_h_m, reset_x_m, reset_y_m, reset_ch_in_m, reset_ch_out_m;
  assign k_v_m_next = reset_k_v_m ? 0 : k_v_m + 1;
  assign k_h_m_next = reset_k_h_m ? 0 : k_h_m + 1;
  assign x_m_next = reset_x_m ? 0 : x_m + 1;
  assign y_m_next = reset_y_m ? 0 : y_m + 1;
  assign ch_in_m_next = reset_ch_in_m ? 0 : ch_in_m + 1;
  assign ch_out_m_next = reset_ch_out_m ? 0 : ch_out_m + 1;

  assign ky_out = k_v_m;
  assign kx_out = k_h_m;
  assign outch_out = ch_out_m;
  assign inch_out = ch_in_m;
  assign y_out = y_m;
  assign x_out = x_m;

  logic last_k_v, last_k_h, last_x, last_y, last_ch_in, last_ch_out;
  assign last_k_v = k_v == KERNEL_SIZE - 1;
  assign last_k_h = k_h == KERNEL_SIZE - 1;
  assign last_x = x == FEATURE_MAP_WIDTH-1;
  assign last_y = y == FEATURE_MAP_HEIGHT-1;
  assign last_ch_in = ch_in == INPUT_NB_CHANNELS - 1;
  assign last_ch_out = ch_out == OUTPUT_NB_CHANNELS - 1;

  logic last_k_v_m, last_k_h_m, last_x_m, last_y_m, last_ch_in_m, last_ch_out_m;
  assign last_k_v_m = k_v_m == KERNEL_SIZE - 1;
  assign last_k_h_m = k_h_m == KERNEL_SIZE - 1;
  assign last_x_m = x_m == FEATURE_MAP_WIDTH-1;
  assign last_y_m = y_m == FEATURE_MAP_HEIGHT-1;
  assign last_ch_in_m = ch_in_m == INPUT_NB_CHANNELS - 1;
  assign last_ch_out_m = ch_out_m == OUTPUT_NB_CHANNELS - 1;

  assign reset_k_v = last_k_v;
  assign reset_k_h = last_k_h || current_state == LOAD;
  assign reset_x = last_x;
  assign reset_y = last_y;
  assign reset_ch_in = last_ch_in;
  assign reset_ch_out = last_ch_out;

  assign reset_k_v_m = last_k_v_m;
  assign reset_k_h_m = last_k_h_m || current_state == LOAD;
  assign reset_x_m = last_x_m;
  assign reset_y_m = last_y_m;
  assign reset_ch_in_m = last_ch_in_m;
  assign reset_ch_out_m = last_ch_out_m;

  /*
  chosen loop order:
  for x
    for y
      for ch_in
        for ch_out     (with this order, accumulations need to be kept because ch_out is inside ch_in)
          for k_v
            for k_h
              body
  */
  // ==>
  assign k_h_we    = mac_valid || (current_state == LOAD); //each time a mac is done, or in case of kickstarting the pipeline, k_h_we increments (or resets to 0 if last)
  assign k_v_we    = mac_valid && last_k_h; //only if last of k_h loop
  assign ch_out_we = mac_valid && last_k_h && last_k_v; //only if last of all enclosed loops
  assign ch_in_we  = mac_valid && last_k_h && last_k_v && last_ch_out; //only if last of all enclosed loops
  assign y_we      = mac_valid && last_k_h && last_k_v && last_ch_out && last_ch_in; //only if last of all enclosed loops
  assign x_we      = mac_valid && last_k_h && last_k_v && last_ch_out && last_ch_in && last_y; //only if last of all enclosed loops

  assign k_h_m_we    = int_mem_re || (current_state == LOAD); 
  assign k_v_m_we    = int_mem_re && last_k_h_m; 
  assign ch_out_m_we = int_mem_re && last_k_h_m && last_k_v_m;
  assign ch_in_m_we  = int_mem_re && last_k_h_m && last_k_v_m && last_ch_out_m;
  assign y_m_we      = int_mem_re && last_k_h_m && last_k_v_m && last_ch_out_m && last_ch_in_m;
  assign x_m_we      = int_mem_re && last_k_h_m && last_k_v_m && last_ch_out_m && last_ch_in_m && last_y_m;

  logic last_overall;
  assign last_overall   = last_k_h && last_k_v && last_ch_out && last_ch_in && last_y && last_x;
  assign fsm_done = last_overall || ((x == 32'd64) && (current_state == MAC)); // Actually, FSM is not done. Trigger at the end of each half of the feature map.

  `REG(32, prev_ch_out);
  assign prev_ch_out_next = ch_out;
  assign prev_ch_out_we = ch_out_we;
  //given loop order, partial sums need be saved over input channels
  assign mem_we         = k_v == 0 && k_h == 0; // Note: one cycle after last_k_v and last_k_h, because of register in mac unit
  assign mem_write_addr = prev_ch_out;

  //and loaded back
  assign mem_re         = k_v == 0 && k_h == 0;
  assign mem_read_addr  = ch_out;


  //mark outputs
  `REG(1, output_valid_reg);
  assign output_valid_reg_next = mac_valid && last_ch_in && last_k_v && last_k_h;
  assign output_valid_reg_we   = 1;
  assign output_valid = output_valid_reg;

  assign mac_accumulate_internal = ! (k_v == 0 && k_h == 0);
  assign mac_accumulate_with_0   = (ch_in ==0 && k_v == 0 && k_h == 0);

  register #(.WIDTH(32)) output_x_r (.clk(clk), .arst_n_in(arst_n_in),
                                                .din(x),
                                                .qout(output_x),
                                                .we(mac_valid && last_ch_in && last_k_v && last_k_h));
  register #(.WIDTH(32)) output_y_r (.clk(clk), .arst_n_in(arst_n_in),
                                                .din(y),
                                                .qout(output_y),
                                                .we(mac_valid && last_ch_in && last_k_v && last_k_h));
  register #(.WIDTH(32)) output_ch_r (.clk(clk), .arst_n_in(arst_n_in),
                                                .din(ch_out),
                                                .qout(output_ch),
                                                .we(mac_valid && last_ch_in && last_k_v && last_k_h));

  //typedef enum {IDLE, FETCH, MAC} fsm_state;
  


  always_comb begin
    //defaults: applicable if not overwritten below
    next_state = current_state;
    write_a = 0;
    write_b = 0;
    mac_valid = 0;
    running = 1;
    a_ready = 0;
    b_ready = 0;
    int_mem_re = 0;

    case (current_state)
      IDLE: begin
        running = 0;
        next_state = start ? LOAD : IDLE;
      end
      LOAD: begin
        a_ready = 1;
        b_ready = 1;
        next_state = data_ready ? FETCH : LOAD;
      end
      FETCH: begin
        a_ready = 1;
        b_ready = 1;
        int_mem_re = 1;
        write_a = 1;
        write_b = 1;
        next_state = (x == 32'd64) ? MAC2 : MAC;
      end
      MAC: begin
        mac_valid = 1;
        a_ready = 1;
        b_ready = 1;
        int_mem_re = 1;
        write_a = 1;
        write_b = 1;
        next_state = (output_valid && (x == 32'd64)) ? LOAD : MAC;
      end
      MAC2: begin
        mac_valid = 1;
        a_ready = 1;
        b_ready = 1;
        int_mem_re = 1;
        write_a = 1;
        write_b = 1;
        next_state = last_overall ? IDLE : MAC2;
      end
    endcase
  end
endmodule
