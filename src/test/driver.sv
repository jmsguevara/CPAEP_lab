class Driver #(config_t cfg);

  virtual intf #(cfg) intf_i;

  mailbox #(Transaction_Feature #(cfg)) gen2drv_feature;
  mailbox #(Transaction_Kernel #(cfg)) gen2drv_kernel;

  function new(
    virtual intf #(cfg) i,
    mailbox #(Transaction_Feature #(cfg)) g2d_feature,
    mailbox #(Transaction_Kernel #(cfg)) g2d_kernel
  );
    intf_i = i;
    gen2drv_feature = g2d_feature;
    gen2drv_kernel = g2d_kernel;
  endfunction : new

  task reset;
    $display("[DRV] ----- Reset Started -----");
     //asynchronous start of reset
    intf_i.cb.start   <= 0;
    intf_i.cb.int_mem_we <= 0;
    intf_i.cb.overlap_cache_we <= 0;
    intf_i.cb.b_zero <= 0;
    intf_i.cb.data_ready <= 0;
    intf_i.cb.a_valid <= 0;
    intf_i.cb.a_zero_flag <= 0;
    intf_i.cb.b_zero_flag <= 0;
    intf_i.cb.b_valid <= 0;
    intf_i.cb.arst_n  <= 0;
    repeat (2) @(intf_i.cb);
    intf_i.cb.arst_n  <= 1; //synchronous release of reset
    repeat (2) @(intf_i.cb);
    $display("[DRV] -----  Reset Ended  -----");
  endtask
  
  //  sparsity exploit:

  //1. reshape feature matrix and generate zero indices (driver)
  //2. reshape kernel matrix and generate zero indices (driver) DONE
  //3. modify driver for loop (order of sending data)
  //4. modify controller fsm (match driver order)
  //5. create on-chip memory for both matrices and zero indices
  //6. create on-chip decoder

  //fetch input to memory -> fetch kernel to memory -> transfer from memory to mac (old fetch) -> mac

  logic [15:0] addr;
  int x;

  task run();
    bit first = 1;

    // Get a transaction with kernel from the Generator
    // Kernel remains same throughput the verification
    Transaction_Kernel #(cfg) tract_kernel;
    gen2drv_kernel.get(tract_kernel);

    $display("[DRV] -----  Start execution -----");
    
    forever begin
      time starttime;
      // Get a transaction with feature from the Generator
      Transaction_Feature #(cfg) tract_feature;
      gen2drv_feature.get(tract_feature);

      $display("[DRV] Giving start signal");
      intf_i.cb.start <= 1;
      starttime = $time();
      @(intf_i.cb);
      intf_i.cb.start <= 0;

      $display("[DRV] Sending kernel...");
      for(int ky=0;ky<cfg.KERNEL_SIZE; ky++) begin
        for(int kx=0;kx<cfg.KERNEL_SIZE; kx++) begin
          for(int inch=0;inch<cfg.INPUT_NB_CHANNELS; inch++) begin
            for(int outch=0;outch<cfg.OUTPUT_NB_CHANNELS; outch++) begin
              
              intf_i.cb.a_valid <= 1;
              intf_i.cb.b_valid <= 1;
              if (tract_kernel.kernel[ky][kx][inch][outch] != 0) begin
                intf_i.cb.int_mem_we <= 1;
                addr = {1'b1, 6'b0, inch[0], ky[1:0], kx[1:0], outch[3:0]};
                intf_i.cb.a_input <= addr;
                intf_i.cb.b_input <= tract_kernel.kernel[ky][kx][inch][outch];
              end
              else begin
                intf_i.cb.int_mem_we <= 0;
              end

              @(intf_i.cb iff intf_i.cb.b_ready && intf_i.cb.a_ready);
              intf_i.cb.a_valid <= 0;
              intf_i.cb.b_valid <= 0;

            end
          end
        end
      end

      $display("[DRV] Sending left half of feature map...");
      for(int x = 0; x < cfg.FEATURE_MAP_WIDTH / 2; x++) begin
        // $display("x = %d", x);
        for(int y = 0; y < cfg.FEATURE_MAP_HEIGHT; y++) begin
          for(int inch = 0; inch<cfg.INPUT_NB_CHANNELS; inch++) begin
              
              intf_i.cb.a_valid <= 1;
              intf_i.cb.b_valid <= 1;
              if(tract_feature.inputs[y][x][inch] != 0) begin
                intf_i.cb.int_mem_we <= 1;
                addr = {2'b0, inch[0], y[6:0], x[5:0]};
                intf_i.cb.a_input <= addr;
                intf_i.cb.b_input <= tract_feature.inputs[y][x][inch];
              end
              else begin
                intf_i.cb.int_mem_we <= 0;
              end
              @(intf_i.cb iff intf_i.cb.b_ready && intf_i.cb.a_ready);
              intf_i.cb.a_valid <= 0;
              intf_i.cb.b_valid <= 0;

          end
        end
      end

      intf_i.cb.int_mem_we <= 0;


      // overlap col: 64
      x = 64;
      for(int y = 0; y < cfg.FEATURE_MAP_HEIGHT; y++) begin
          for(int inch = 0; inch<cfg.INPUT_NB_CHANNELS; inch++) begin
              
              intf_i.cb.a_valid <= 1;
              intf_i.cb.b_valid <= 1;
              if(tract_feature.inputs[y][x][inch] != 0) begin
                intf_i.cb.overlap_cache_we <= 1;
                addr = {inch[0], y[6:0]};
                intf_i.cb.a_input <= addr;
                intf_i.cb.b_input <= tract_feature.inputs[y][x][inch];
              end
              else begin
                intf_i.cb.overlap_cache_we <= 0;
              end
              @(intf_i.cb iff intf_i.cb.b_ready && intf_i.cb.a_ready);
              intf_i.cb.a_valid <= 0;
              intf_i.cb.b_valid <= 0;

          end
      end

      intf_i.cb.overlap_cache_we <= 0;

      $display("[DRV] Giving data ready signal");
      intf_i.cb.data_ready <= 1;
      @(intf_i.cb);
      intf_i.cb.data_ready <= 0;

      // block until calculation is done
      @(intf_i.cb iff intf_i.cb.fsm_done);

      $display("[DRV] Sending right half of feature map...");
      // overlap col: 63
      x = 63;
      for(int y = 0; y < cfg.FEATURE_MAP_HEIGHT; y++) begin
          for(int inch = 0; inch<cfg.INPUT_NB_CHANNELS; inch++) begin
              
              intf_i.cb.a_valid <= 1;
              intf_i.cb.b_valid <= 1;

              intf_i.cb.overlap_cache_we <= 1;
              addr = {inch[0], y[6:0]};
              intf_i.cb.a_input <= addr;

              if(tract_feature.inputs[y][x][inch] != 0) begin
                intf_i.cb.b_input <= tract_feature.inputs[y][x][inch];
                intf_i.cb.b_zero <= 0;
              end
              else begin
                intf_i.cb.b_zero <= 1;
              end
              @(intf_i.cb iff intf_i.cb.b_ready && intf_i.cb.a_ready);
              intf_i.cb.a_valid <= 0;
              intf_i.cb.b_valid <= 0;

          end
      end

      intf_i.cb.overlap_cache_we <= 0;

      // right half
      for(int x = cfg.FEATURE_MAP_WIDTH / 2; x < cfg.FEATURE_MAP_WIDTH; x++) begin
        // $display("x = %d", x);
        for(int y = 0; y < cfg.FEATURE_MAP_HEIGHT; y++) begin
          for(int inch = 0; inch<cfg.INPUT_NB_CHANNELS; inch++) begin
              
              intf_i.cb.a_valid <= 1;
              intf_i.cb.b_valid <= 1;
              
              intf_i.cb.int_mem_we <= 1;
              addr = {2'b0, inch[0], y[6:0], x[5:0]};
              intf_i.cb.a_input <= addr;
              if(tract_feature.inputs[y][x][inch] != 0) begin
                intf_i.cb.b_input <= tract_feature.inputs[y][x][inch];
                intf_i.cb.b_zero <= 0;
              end
              else begin
                intf_i.cb.b_zero <= 1;
              end

              @(intf_i.cb iff intf_i.cb.b_ready && intf_i.cb.a_ready);
              intf_i.cb.a_valid <= 0;
              intf_i.cb.b_valid <= 0;

          end
        end
      end

      intf_i.cb.int_mem_we <= 0;

      $display("[DRV] Giving data ready signal");
      intf_i.cb.data_ready <= 1;
      @(intf_i.cb);
      intf_i.cb.data_ready <= 0;

      @(intf_i.cb iff intf_i.cb.fsm_done);

      $display("\n\n------------------\nLATENCY: input processed in %t\n------------------\n", $time() - starttime);

      $display("------------------\nENERGY:  %0d\n------------------\n", tbench_top.energy);

      $display("------------------\nENERGYxLATENCY PRODUCT (/1e9):  %0d\n------------------\n", (longint'(tbench_top.energy) * ($time() - starttime))/1e9);

      tbench_top.energy=0;

      $display("\n------------------\nAREA (breakdown see start): %0d\n------------------\n", tbench_top.area);

    end
  endtask : run
endclass : Driver
