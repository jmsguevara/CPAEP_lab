onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tbench_top/intf_i/clk
add wave -noupdate /tbench_top/intf_i/int_mem_we
add wave -noupdate /tbench_top/intf_i/a_valid
add wave -noupdate /tbench_top/intf_i/b_valid
add wave -noupdate /tbench_top/intf_i/a_input
add wave -noupdate /tbench_top/intf_i/b_input
add wave -noupdate /tbench_top/dut/top_chip_i/data_mem/write_en
add wave -noupdate /tbench_top/dut/top_chip_i/data_mem/write_addr
add wave -noupdate /tbench_top/dut/top_chip_i/data_mem/din
add wave -noupdate /tbench_top/dut/top_chip_i/data_mem/data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {1493000 ps} 0}
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
WaveRestoreZoom {1451257 ps} {1494979 ps}
