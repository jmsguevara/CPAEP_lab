module top_chip #(
    parameter int IO_DATA_WIDTH = 16,
    parameter int NZ_FLAG_WIDTH = 1,
    parameter int ACCUMULATION_WIDTH = 32,
    parameter int EXT_MEM_HEIGHT = 1<<20,
    parameter int EXT_MEM_WIDTH = ACCUMULATION_WIDTH,
    parameter int FEATURE_MAP_WIDTH = 1024,
    parameter int FEATURE_MAP_HEIGHT = 1024,
    parameter int INPUT_NB_CHANNELS = 64,
    parameter int OUTPUT_NB_CHANNELS = 64,
    parameter int KERNEL_SIZE = 3
  )
  (input logic clk,
   input logic arst_n_in,  //asynchronous reset, active low

   //external_memory
   //read port
   output logic unsigned[$clog2(EXT_MEM_HEIGHT)-1:0] ext_mem_read_addr,
   output logic ext_mem_read_en,
   input logic[EXT_MEM_WIDTH-1:0] ext_mem_qout,

   //write port
   output logic unsigned[$clog2(EXT_MEM_HEIGHT)-1:0] ext_mem_write_addr,
   output logic [EXT_MEM_WIDTH-1:0] ext_mem_din,
   output logic ext_mem_write_en,

   // write-enable driver <-> internal memory
   input logic int_mem_we,
   input logic data_ready,

   output logic fsm_done,

   //system inputs and outputs
   input logic [IO_DATA_WIDTH-1:0] a_input,     // comme l'adresse
   input logic a_valid,
   output logic a_ready,
   input logic [IO_DATA_WIDTH-1:0] b_input,     // pour les données
   input logic b_valid,
   output logic b_ready,

   //output
   output logic signed [IO_DATA_WIDTH-1:0] out,
   output logic output_valid,
   output logic [$clog2(FEATURE_MAP_WIDTH)-1:0] output_x,
   output logic [$clog2(FEATURE_MAP_HEIGHT)-1:0] output_y,
   output logic [$clog2(OUTPUT_NB_CHANNELS)-1:0] output_ch,

   input logic start,
   output logic running
  );

  logic write_a;
  logic write_b;
  
  logic int_mem_re;

  logic mac_valid;
  logic mac_accumulate_internal;
  logic mac_accumulate_with_0;

  logic mem_write_en;
  logic mem_read_en;
  logic unsigned[$clog2(EXT_MEM_HEIGHT)-1:0] mem_write_addr;
  logic unsigned[$clog2(EXT_MEM_HEIGHT)-1:0] mem_read_addr;

  logic [IO_DATA_WIDTH-1:0] input_mem_out;
  logic [IO_DATA_WIDTH-1:0] kernel_mem_out;

  logic [31:0] ky_out;
  logic [31:0] kx_out;
  logic [31:0] outch_out;
  logic [31:0] inch_out;
  logic [31:0] y_out;
  logic [31:0] x_out;


  logic [14:0] input_addr;
  logic [8:0] kernel_addr;

  logic [7:0] y_aux;
  assign y_aux = y_out[6:0]+ky_out[1:0] - KERNEL_SIZE/2;
  logic [7:0] x_aux;
  assign x_aux = x_out[6:0]+kx_out[1:0] - KERNEL_SIZE/2;

  assign input_addr = {inch_out[0], y_aux[6:0], x_aux[6:0]};
  assign kernel_addr = {inch_out[0], ky_out[1:0], kx_out[1:0], outch_out[3:0]};

  memory #(
    .WIDTH(IO_DATA_WIDTH),
    .HEIGHT(1<<15),
    .USED_AS_EXTERNAL_MEM(0)
  )
  input_mem // mémoire sur chip pour matrix
  (
    .clk(clk),

    .read_en(int_mem_re),
    .read_addr(input_addr),
    .qout(input_mem_out),

    .write_addr(a_input[14:0]),
    .write_en(int_mem_we & ~a_input[15]),
    .din(b_input)
  );

  memory #(
    .WIDTH(IO_DATA_WIDTH),
    .HEIGHT(1<<9),
    .USED_AS_EXTERNAL_MEM(0)
  )
  kernel_mem // mémoire sur chip pour matrix
  (
    .clk(clk),

    .read_en(int_mem_re),
    .read_addr(kernel_addr),
    .qout(kernel_mem_out),

    .write_addr(a_input[8:0]),
    .write_en(int_mem_we & a_input[15]),
    .din(b_input)
  );

  controller_fsm #(
  .LOG2_OF_MEM_HEIGHT($clog2(EXT_MEM_HEIGHT)),
  .FEATURE_MAP_WIDTH(FEATURE_MAP_WIDTH),
  .FEATURE_MAP_HEIGHT(FEATURE_MAP_HEIGHT),
  .INPUT_NB_CHANNELS(INPUT_NB_CHANNELS),
  .OUTPUT_NB_CHANNELS(OUTPUT_NB_CHANNELS),
  .KERNEL_SIZE(KERNEL_SIZE)
  )
  controller
  (.clk(clk),
  .arst_n_in(arst_n_in),
  .start(start),
  .running(running),

  .mem_we(ext_mem_write_en),
  .mem_write_addr(ext_mem_write_addr),
  .mem_re(ext_mem_read_en),
  .mem_read_addr(ext_mem_read_addr),

  .data_ready(data_ready),
  .int_mem_re(int_mem_re),

  .fsm_done(fsm_done),

  .a_valid(a_valid),
  .a_ready(a_ready),
  .b_valid(b_valid),
  .b_ready(b_ready),
  .write_a(write_a),
  .write_b(write_b),
  .mac_valid(mac_valid),
  .mac_accumulate_internal(mac_accumulate_internal),
  .mac_accumulate_with_0(mac_accumulate_with_0),

  .ky_out(ky_out),
  .kx_out(kx_out),
  .outch_out(outch_out),
  .inch_out(inch_out),
  .y_out(y_out),
  .x_out(x_out),

  .output_valid(output_valid),
  .output_x(output_x),
  .output_y(output_y),
  .output_ch(output_ch)

  );

  logic signed [ACCUMULATION_WIDTH-1:0] mac_partial_sum;
  assign mac_partial_sum = mac_accumulate_with_0 ? 0 : ext_mem_qout;

  logic signed [ACCUMULATION_WIDTH-1:0] mac_out;
  assign ext_mem_dout = mac_out;

  `REG(IO_DATA_WIDTH, a);
  `REG(IO_DATA_WIDTH, b);
  //assign a_next = input_mem_out;
  assign a_next = (~x_aux[7] && x_aux[6:0] < FEATURE_MAP_WIDTH
                    && ~y_aux[7] && y_aux[6:0] < FEATURE_MAP_HEIGHT) ? input_mem_out : 0;
  assign b_next = kernel_mem_out;
  assign a_we = write_a;
  assign b_we = write_b;

  mac #(
    .A_WIDTH(IO_DATA_WIDTH),
    .B_WIDTH(IO_DATA_WIDTH),
    .ACCUMULATOR_WIDTH(ACCUMULATION_WIDTH),
    .OUTPUT_WIDTH(ACCUMULATION_WIDTH),
    .OUTPUT_SCALE(0)
  )
  mac_unit
  (.clk(clk),
   .arst_n_in(arst_n_in),

   .input_valid(mac_valid),
   .a(a),
   .b(b),
   .out(mac_out));

  assign out = mac_out;
  assign ext_mem_din = mac_out;

endmodule
