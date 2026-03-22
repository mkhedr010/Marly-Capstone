# SDRAM Pin Assignments for DE2 Board
# SDRAM Chip: IC42S16400 (8MB)
# Reference: DE2 User Manual

# SDRAM Address [11:0]
set_location_assignment PIN_Y11 -to sdram_addr[0]
set_location_assignment PIN_AA26 -to sdram_addr[1]
set_location_assignment PIN_AA13 -to sdram_addr[2]
set_location_assignment PIN_AA11 -to sdram_addr[3]
set_location_assignment PIN_W11 -to sdram_addr[4]
set_location_assignment PIN_Y13 -to sdram_addr[5]
set_location_assignment PIN_AA12 -to sdram_addr[6]
set_location_assignment PIN_AB13 -to sdram_addr[7]
set_location_assignment PIN_AB12 -to sdram_addr[8]
set_location_assignment PIN_AC12 -to sdram_addr[9]
set_location_assignment PIN_AD12 -to sdram_addr[10]
set_location_assignment PIN_AB11 -to sdram_addr[11]

# Bank Address [1:0]
set_location_assignment PIN_AC11 -to sdram_ba[0]
set_location_assignment PIN_AB10 -to sdram_ba[1]

# Control Signals
set_location_assignment PIN_Y12 -to sdram_clk
set_location_assignment PIN_AE13 -to sdram_cke
set_location_assignment PIN_AF13 -to sdram_cs_n
set_location_assignment PIN_AD11 -to sdram_ras_n
set_location_assignment PIN_AE11 -to sdram_cas_n
set_location_assignment PIN_AA10 -to sdram_we_n

# Data [15:0]
set_location_assignment PIN_W10 -to sdram_dq[0]
set_location_assignment PIN_W9 -to sdram_dq[1]
set_location_assignment PIN_Y10 -to sdram_dq[2]
set_location_assignment PIN_AB9 -to sdram_dq[3]
set_location_assignment PIN_AC10 -to sdram_dq[4]
set_location_assignment PIN_AD10 -to sdram_dq[5]
set_location_assignment PIN_AA9 -to sdram_dq[6]
set_location_assignment PIN_AB8 -to sdram_dq[7]
set_location_assignment PIN_AE10 -to sdram_dq[8]
set_location_assignment PIN_AD8 -to sdram_dq[9]
set_location_assignment PIN_AC8 -to sdram_dq[10]
set_location_assignment PIN_AA8 -to sdram_dq[11]
set_location_assignment PIN_AB7 -to sdram_dq[12]
set_location_assignment PIN_AA7 -to sdram_dq[13]
set_location_assignment PIN_AC7 -to sdram_dq[14]
set_location_assignment PIN_AD7 -to sdram_dq[15]

# Data Mask [1:0]
set_location_assignment PIN_AE12 -to sdram_dqm[0]
set_location_assignment PIN_AF12 -to sdram_dqm[1]

# I/O Standard
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sdram_*

puts "SDRAM pins assigned for DE2!"
