onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tbench_top/dut/top_chip_i/controller/clk
add wave -noupdate /tbench_top/dut/top_chip_i/controller/arst_n_in
add wave -noupdate /tbench_top/dut/top_chip_i/controller/last_overall
add wave -noupdate /tbench_top/dut/top_chip_i/output_valid
add wave -noupdate /tbench_top/dut/top_chip_i/controller/current_state
add wave -noupdate -radix hexadecimal /tbench_top/dut/top_chip_i/input_mem/read_addr
add wave -noupdate /tbench_top/dut/top_chip_i/input_mem/qout
add wave -noupdate /tbench_top/dut/top_chip_i/kernel_mem/qout
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/a
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/b
add wave -noupdate /tbench_top/dut/top_chip_i/mac_unit/product
add wave -noupdate /tbench_top/dut/top_chip_i/out
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {66125000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 330
configure wave -valuecolwidth 92
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
WaveRestoreZoom {66114776 ps} {66143854 ps}
