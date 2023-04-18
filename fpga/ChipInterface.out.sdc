## Generated SDC file "ChipInterface.out.sdc"

## Copyright (C) 2022  Intel Corporation. All rights reserved.
## Your use of Intel Corporation's design tools, logic functions 
## and other software and tools, and any partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Intel Program License 
## Subscription Agreement, the Intel Quartus Prime License Agreement,
## the Intel FPGA IP License Agreement, or other applicable license
## agreement, including, without limitation, that your use is for
## the sole purpose of programming logic devices manufactured by
## Intel and sold by Intel or its authorized distributors.  Please
## refer to the applicable agreement for further details, at
## https://fpgasoftware.intel.com/eula.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 22.1std.0 Build 915 10/25/2022 SC Lite Edition"

## DATE    "Tue Apr 18 12:09:04 2023"

##
## DEVICE  "5CEBA4F23C7"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLOCK_50} -period 20.000 -waveform { 0.000 10.000 } [get_ports { CLOCK_50 }]
create_clock -name {CLOCK_FTDI} -period 16.667 -waveform { 0.000 8.333 } 


#**************************************************************
# Create Generated Clock
#**************************************************************

create_generated_clock -name {CLOCK_UART} -source [get_ports {CLOCK_50}] -divide_by 8 -master_clock {CLOCK_50} [get_registers {LaserDrop:main|ClockDivider:clock_uart|clk_divided}] 


#**************************************************************
# Set Clock Latency
#**************************************************************



#**************************************************************
# Set Clock Uncertainty
#**************************************************************

set_clock_uncertainty -rise_from [get_clocks {CLOCK_UART}] -rise_to [get_clocks {CLOCK_UART}] -setup 0.390  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_UART}] -rise_to [get_clocks {CLOCK_UART}] -hold 0.380  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_UART}] -fall_to [get_clocks {CLOCK_UART}] -setup 0.390  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_UART}] -fall_to [get_clocks {CLOCK_UART}] -hold 0.380  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_UART}] -rise_to [get_clocks {CLOCK_50}] -setup 0.330  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_UART}] -rise_to [get_clocks {CLOCK_50}] -hold 0.320  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_UART}] -fall_to [get_clocks {CLOCK_50}] -setup 0.330  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_UART}] -fall_to [get_clocks {CLOCK_50}] -hold 0.320  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_UART}] -rise_to [get_clocks {CLOCK_UART}] -setup 0.390  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_UART}] -rise_to [get_clocks {CLOCK_UART}] -hold 0.380  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_UART}] -fall_to [get_clocks {CLOCK_UART}] -setup 0.390  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_UART}] -fall_to [get_clocks {CLOCK_UART}] -hold 0.380  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_UART}] -rise_to [get_clocks {CLOCK_50}] -setup 0.330  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_UART}] -rise_to [get_clocks {CLOCK_50}] -hold 0.320  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_UART}] -fall_to [get_clocks {CLOCK_50}] -setup 0.330  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_UART}] -fall_to [get_clocks {CLOCK_50}] -hold 0.320  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_FTDI}] -rise_to [get_clocks {CLOCK_50}]  0.140  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_FTDI}] -fall_to [get_clocks {CLOCK_50}]  0.140  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_FTDI}] -rise_to [get_clocks {CLOCK_50}]  0.140  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_FTDI}] -fall_to [get_clocks {CLOCK_50}]  0.140  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_UART}] -setup 0.330  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_UART}] -hold 0.320  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_UART}] -setup 0.330  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_UART}] -hold 0.320  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] -setup 0.280  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] -hold 0.270  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] -setup 0.280  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] -hold 0.270  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_UART}] -setup 0.330  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_UART}] -hold 0.320  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_UART}] -setup 0.330  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_UART}] -hold 0.320  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] -setup 0.280  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -rise_to [get_clocks {CLOCK_50}] -hold 0.270  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] -setup 0.280  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_50}] -fall_to [get_clocks {CLOCK_50}] -hold 0.270  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_FTDI}] -rise_to [get_clocks {CLOCK_UART}] -setup 0.190  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_FTDI}] -rise_to [get_clocks {CLOCK_UART}] -hold 0.200  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_FTDI}] -fall_to [get_clocks {CLOCK_UART}] -setup 0.190  
set_clock_uncertainty -rise_from [get_clocks {CLOCK_FTDI}] -fall_to [get_clocks {CLOCK_UART}] -hold 0.200  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_FTDI}] -rise_to [get_clocks {CLOCK_UART}] -setup 0.190  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_FTDI}] -rise_to [get_clocks {CLOCK_UART}] -hold 0.200  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_FTDI}] -fall_to [get_clocks {CLOCK_UART}] -setup 0.190  
set_clock_uncertainty -fall_from [get_clocks {CLOCK_FTDI}] -fall_to [get_clocks {CLOCK_UART}] -hold 0.200  


#**************************************************************
# Set Input Delay
#**************************************************************

# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[0]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[2]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[4]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[6]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[8]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[10]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[12]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[14]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[17]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[19]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0.2 [get_ports {GPIO_0[26]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0 [get_ports {KEY[0]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0 [get_ports {SW[0]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0 [get_ports {SW[2]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0 [get_ports {SW[6]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0 [get_ports {SW[7]}]
# set_input_delay -add_delay  -clock [get_clocks {CLOCK_FTDI}]  0 [get_ports {SW[9]}]


#**************************************************************
# Set Output Delay
#**************************************************************

# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0.2 [get_ports {GPIO_0[13]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0.2 [get_ports {GPIO_0[15]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0.2 [get_ports {GPIO_0[20]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0.2 [get_ports {GPIO_0[22]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0.2 [get_ports {GPIO_0[24]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0.2 [get_ports {GPIO_0[30]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX0[0]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX0[1]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX0[2]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX0[3]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX0[4]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX0[5]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX0[6]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX1[0]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX1[1]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX1[2]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX1[3]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX1[4]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX1[5]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX1[6]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX2[0]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX2[1]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX2[2]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX2[3]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX2[4]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX2[5]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX2[6]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX3[0]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX3[1]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX3[2]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX3[3]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX3[4]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX3[5]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX3[6]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX4[0]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX4[1]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX4[2]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX4[3]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX4[4]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX4[5]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX4[6]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX5[0]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX5[1]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX5[2]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX5[3]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX5[4]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX5[5]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {HEX5[6]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[0]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[1]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[2]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[3]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[4]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[5]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[6]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[7]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[8]}]
# set_output_delay -add_delay  -clock [get_clocks {CLOCK_UART}]  0 [get_ports {LEDR[9]}]



#**************************************************************
# Set Clock Groups
#**************************************************************



#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

