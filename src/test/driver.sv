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

    //kernel matrices instantiation
    bit [15:0] kernel_nz [$];
    bit kernel_zeroes [$][$][$][$];
    bit [7:0] nz_index;

  task run();
    bit first = 1;

    // Get a transaction with kernel from the Generator
    // Kernel remains same throughput the verification
    Transaction_Kernel #(cfg) tract_kernel;
    gen2drv_kernel.get(tract_kernel);

    $display("[DRV] -----  Start execution -----");
    
    nz_index = 0;
    
    //generate kernel matrices
    for(int inch=0;inch<cfg.INPUT_NB_CHANNELS; inch++) begin
        for(int outch=0;outch<cfg.OUTPUT_NB_CHANNELS; outch++) begin
          for(int ky=0;ky<cfg.KERNEL_SIZE; ky++) begin
            for(int kx=0;kx<cfg.KERNEL_SIZE; kx++) begin
              //$display("ky = %h, kx = %h, inch = %h, outch = %h, value = %h", ky, kx, inch, outch, tract_kernel.kernel[ky][kx][inch][outch]);
              if (tract_kernel.kernel[ky][kx][inch][outch] > 0) begin
                kernel_nz[nz_index] = tract_kernel.kernel[ky][kx][inch][outch];
                //$display("index = %h, value = %h", nz_index, kernel_nz[nz_index]);
                kernel_zeroes[ky][kx][inch][outch] = 1;
                nz_index++;
              end
              else begin
                kernel_zeroes[ky][kx][inch][outch] = 0;
              end
              //$display("ky = %h, kx = %h, inch = %h, outch = %h, value = %h", ky, kx, inch, outch, kernel_zeroes[ky][kx][inch][outch]);
            end
          end
        end
      end
      
    nz_index = 0;

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



      $display("[DRV] ----- Driving a new input feature map -----");
      for(int x=0;x<cfg.FEATURE_MAP_WIDTH; x++) begin
        $display("[DRV] %.2f %% of the input is transferred", ((x)*100.0)/cfg.FEATURE_MAP_WIDTH);
        for(int y=0;y<cfg.FEATURE_MAP_HEIGHT; y++) begin
          for(int inch=0;inch<cfg.INPUT_NB_CHANNELS; inch++) begin
            for(int outch=0;outch<cfg.OUTPUT_NB_CHANNELS; outch++) begin
              for(int ky=0;ky<cfg.KERNEL_SIZE; ky++) begin
                for(int kx=0;kx<cfg.KERNEL_SIZE; kx++) begin

                  //drive a (one word from feature)
                  intf_i.cb.a_valid <= 1;
                  if( x+kx-cfg.KERNEL_SIZE/2 >= 0 && x+kx-cfg.KERNEL_SIZE/2 < cfg.FEATURE_MAP_WIDTH
                    &&y+ky-cfg.KERNEL_SIZE/2 >= 0 && y+ky-cfg.KERNEL_SIZE/2 < cfg.FEATURE_MAP_HEIGHT) begin
                    assert (!$isunknown(tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x+kx-cfg.KERNEL_SIZE/2][inch]));

                    if( tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x+kx-cfg.KERNEL_SIZE/2][inch] == 0) begin
                      intf_i.cb.a_zero_flag <= 1;
                    end
                    else begin
                      intf_i.cb.a_input <= tract_feature.inputs[y+ky-cfg.KERNEL_SIZE/2 ][x+kx-cfg.KERNEL_SIZE/2][inch];
                    end

                  end else begin
                    intf_i.cb.a_zero_flag <= 1; // zero padding for boundary cases
                  end

                  //drive b (one word from kernel)
                  intf_i.cb.b_valid <= 1;
                  assert (!$isunknown(tract_kernel.kernel[ky][kx][inch][outch]));
                  if(tract_kernel.kernel[ky][kx][inch][outch] == 0) begin
                    intf_i.cb.b_zero_flag <= 1;
                  end
                  else begin
                    intf_i.cb.b_input <= tract_kernel.kernel[ky][kx][inch][outch];
                  end
                  @(intf_i.cb iff intf_i.cb.b_ready && intf_i.cb.a_ready);
                    intf_i.cb.a_zero_flag <= 0;
                    intf_i.cb.b_zero_flag <= 0;
                    intf_i.cb.a_valid <= 0;
                    intf_i.cb.b_valid <= 0;
                end
              end
            end
          end
        end
      end


      $display("\n\n------------------\nLATENCY: input processed in %t\n------------------\n", $time() - starttime);

      $display("------------------\nENERGY:  %0d\n------------------\n", tbench_top.energy);

      $display("------------------\nENERGYxLATENCY PRODUCT (/1e9):  %0d\n------------------\n", (longint'(tbench_top.energy) * ($time() - starttime))/1e9);

      tbench_top.energy=0;

      $display("\n------------------\nAREA (breakdown see start): %0d\n------------------\n", tbench_top.area);

    end
  endtask : run
endclass : Driver
