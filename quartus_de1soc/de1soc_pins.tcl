# ============================================================================
# DE1-SoC Pin Assignments for ECG CNN System
# Board: Terasic DE1-SoC (Cyclone V 5CSEMA5F31C6)
# ============================================================================

# Clock (50 MHz)
set_location_assignment PIN_AF14 -to clk_50mhz

# Reset (KEY[0] - active low)
set_location_assignment PIN_AA14 -to reset_n

# UART (USB-UART bridge - easier than DE2!)
set_location_assignment PIN_AE26 -to uart_rx

# Push Button (KEY[1] for pause)
set_location_assignment PIN_AA15 -to btn[0]

# Red LEDs LEDR[3:0] for status
set_location_assignment PIN_V16 -to led[0]
set_location_assignment PIN_W16 -to led[1]
set_location_assignment PIN_V17 -to led[2]
set_location_assignment PIN_V18 -to led[3]

# Green User LEDs LED[7:0] for classification results
set_location_assignment PIN_W20 -to ledg[0]
set_location_assignment PIN_Y19 -to ledg[1]
set_location_assignment PIN_W19 -to ledg[2]
set_location_assignment PIN_W17 -to ledg[3]
set_location_assignment PIN_V19 -to ledg[4]
set_location_assignment PIN_V20 -to ledg[5]
set_location_assignment PIN_V21 -to ledg[6]
set_location_assignment PIN_W21 -to ledg[7]

# VGA Sync
set_location_assignment PIN_B13 -to vga_hsync
set_location_assignment PIN_C13 -to vga_vsync

# VGA Red Channel [7:0] (using 8 of 10 available)
set_location_assignment PIN_E12 -to vga_r[0]
set_location_assignment PIN_E11 -to vga_r[1]
set_location_assignment PIN_D10 -to vga_r[2]
set_location_assignment PIN_F12 -to vga_r[3]
set_location_assignment PIN_G12 -to vga_r[4]
set_location_assignment PIN_J12 -to vga_r[5]
set_location_assignment PIN_H8  -to vga_r[6]
set_location_assignment PIN_H10 -to vga_r[7]
set_location_assignment PIN_G11 -to vga_r[8]
set_location_assignment PIN_G10 -to vga_r[9]

# VGA Green Channel [7:0] (using 8 of 10 available)
set_location_assignment PIN_H12 -to vga_g[0]
set_location_assignment PIN_H11 -to vga_g[1]
set_location_assignment PIN_G8  -to vga_g[2]
set_location_assignment PIN_G9  -to vga_g[3]
set_location_assignment PIN_F10 -to vga_g[4]
set_location_assignment PIN_C9  -to vga_g[5]
set_location_assignment PIN_B8  -to vga_g[6]
set_location_assignment PIN_F8  -to vga_g[7]
set_location_assignment PIN_A13 -to vga_g[8]
set_location_assignment PIN_B13 -to vga_g[9]

# VGA Blue Channel [7:0] (using 8 of 10 available)
set_location_assignment PIN_C10 -to vga_b[0]
set_location_assignment PIN_D11 -to vga_b[1]
set_location_assignment PIN_D12 -to vga_b[2]
set_location_assignment PIN_E10 -to vga_b[3]
set_location_assignment PIN_E11 -to vga_b[4]
set_location_assignment PIN_E12 -to vga_b[5]
set_location_assignment PIN_F11 -to vga_b[6]
set_location_assignment PIN_F10 -to vga_b[7]
set_location_assignment PIN_G11 -to vga_b[8]
set_location_assignment PIN_G12 -to vga_b[9]

# I/O Standards (3.3V LVTTL for all)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to *

puts "DE1-SoC pins configured successfully!"
