onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tbench_top/dut/top_chip_i/controller/clk
add wave -noupdate /tbench_top/dut/top_chip_i/controller/mac_valid
add wave -noupdate /tbench_top/dut/top_chip_i/controller/output_x
add wave -noupdate /tbench_top/dut/top_chip_i/controller/output_y
add wave -noupdate /tbench_top/dut/top_chip_i/controller/output_ch
add wave -noupdate /tbench_top/dut/top_chip_i/controller/output_valid_reg_next
add wave -noupdate /tbench_top/dut/top_chip_i/controller/output_valid_reg
add wave -noupdate /tbench_top/dut/top_chip_i/controller/current_state
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/accumulator_value
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/adder_b
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/input_valid
add wave -noupdate /tbench_top/dut/top_chip_i/controller/mac_accumulate_internal
add wave -noupdate /tbench_top/dut/top_chip_i/controller/mac_accumulate_with_0
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/a
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/b
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/pp_a
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/pp_b
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/product
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/sum
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/out
add wave -noupdate /tbench_top/dut/top_chip_i/controller/output_valid
add wave -noupdate /tbench_top/dut/out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {317000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 487
configure wave -valuecolwidth 133
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {288632 ps} {340246 ps}
