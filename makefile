##########################
######## variables #######
######## commands  #######
##########################

#list your verilog files in srcPath/sourcefile_order
#the order of the files in that file is important.

srcPath := ./src
#script to add vcs to path variables, so that it can be run:
sourceQuesta = source /users/micas/kgoetsch/software/path/add_questa_to_path
topmodule := tbench_top

##########################
######### targets ########
##########################


###########
# general #
###########
no_target:
	echo "give a usefull target"

#removes output to start over clean
clean:
	rm -rf csrc/* linter/* log/* out/* WORK/* vc_hdrs.h transcript covhtmlreport/ cov_report vish_stacktrace.vstf vsim.wlf

clean_linter:
	rm -rf linter/out/* linter/log/* vc_hdrs.h linter/csrc/*

cl: clean_linter

#just a shorthand
all: compile run
ag: compile_gui run_gui

#opens a graphical file explorer on the source folder
browsesource:
	nautilus src &>/dev/null &
editsource:
	/users/micas/kgoetsch/software/atom/atom >/dev/null &


###########
# compile #
###########
#Compiles the source into an executable simulator (out/simv)
compile:
	$(sourceQuesta);\
	vlog -sv17compat -override_timescale=1ns/1ps  -vopt -work WORK -64 -O4 -mfcu -f src/sourcefile_order


#######
# run #
#######
#runs the compiled simulator
run:
	$(sourceQuesta);\
	vsim -c WORK.tbench_top -do "run -all" 


###########
### GUI ###
###########
compile_gui:
	$(makedirs)
	$(sourceQuesta);\
	vlog -sv17compat -vopt -override_timescale=1ns/1ps  -work WORK -64 -O4 -mfcu  +cover +acc=npr -assertdebug -bitscalars -floatparameters -cover bcest -f src/sourcefile_order

cg: compile_gui

run_gui:
	$(sourceQuesta);\
	vsim WORK.tbench_top -do 'add log -r /*'
rg: run_gui
gui: compile_gui run_gui 


################
### coverage ###
################
run_coverage:
	$(sourceQuesta);\
	vsim -coverage -vopt WORK.tbench_top -c -do "coverage save -onexit -directive -codeAll cov_report; run -all" && vcover report -html cov_report
