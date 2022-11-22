onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tbench_top/dut/top_chip_i/controller/clk
add wave -noupdate /tbench_top/dut/top_chip_i/controller/arst_n_in
add wave -noupdate /tbench_top/dut/top_chip_i/controller/current_state
add wave -noupdate /tbench_top/dut/top_chip_i/kernel_mem/write_en
add wave -noupdate /tbench_top/dut/top_chip_i/input_mem/write_en
add wave -noupdate /tbench_top/intf_i/data_ready
add wave -noupdate /tbench_top/dut/top_chip_i/controller/int_mem_re
add wave -noupdate /tbench_top/intf_i/int_mem_we
add wave -noupdate /tbench_top/dut/top_chip_i/output_valid
add wave -noupdate /tbench_top/dut/top_chip_i/controller/last_overall
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {66125925 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 330
configure wave -valuecolwidth 149
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
WaveRestoreZoom {0 ps} {69756750 ps}
