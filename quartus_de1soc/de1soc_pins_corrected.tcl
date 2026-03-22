# ============================================================================
# DE1-SoC CORRECTED Pin Assignments
# From DE1-SoC User Manual
# ============================================================================

# Clock (50 MHz oscillator)
set_location_assignment PIN_AF14 -to clk_50mhz

# Reset (KEY[0])
set_location_assignment PIN_AA14 -to reset_n

# UART RX (USB-UART chip)
set_location_assignment PIN_AE26 -to uart_rx

# Button (KEY[1])
set_location_assignment PIN_AA15 -to btn[0]

# Red LEDs LEDR[3:0]
set_location_assignment PIN_V16 -to led[0]
set_location_assignment PIN_W16 -to led[1]
set_location_assignment PIN_V17 -to led[2]
set_location_assignment PIN_V18 -to led[3]

# Classification LEDs (using LEDR[9:4])
set_location_assignment PIN_Y16 -to ledg[0]
set_location_assignment PIN_W15 -to ledg[1]
set_location_assignment PIN_AA24 -to ledg[2]
set_location_assignment PIN_V15 -to ledg[3]
set_location_assignment PIN_AA25 -to ledg[4]
set_location_assignment PIN_AA26 -to ledg[5]
set_location_assignment PIN_AB26 -to ledg[6]
set_location_assignment PIN_AB25 -to ledg[7]

# VGA Sync (same for all boards)
set_location_assignment PIN_B13 -to vga_hsync
set_location_assignment PIN_C13 -to vga_vsync

# VGA Red [7:0] - DE1-SoC VGA DAC
set_location_assignment PIN_A13 -to vga_r[0]
set_location_assignment PIN_C8  -to vga_r[1]
set_location_assignment PIN_A12 -to vga_r[2]
set_location_assignment PIN_B12 -to vga_r[3]
set_location_assignment PIN_C12 -to vga_r[4]
set_location_assignment PIN_D12 -to vga_r[5]
set_location_assignment PIN_E12 -to vga_r[6]
set_location_assignment PIN_F13 -to vga_r[7]
# Upper 2 bits unused (tie to ground in Quartus)

# VGA Green [7:0]
set_location_assignment PIN_C9  -to vga_g[0]
set_location_assignment PIN_E10 -to vga_g[1]
set_location_assignment PIN_D11 -to vga_g[2]
set_location_assignment PIN_C11 -to vga_g[3]
set_location_assignment PIN_B11 -to vga_g[4]
set_location_assignment PIN_A11 -to vga_g[5]
set_location_assignment PIN_D13 -to vga_g[6]
set_location_assignment PIN_E13 -to vga_g[7]
# Upper 2 bits unused

# VGA Blue [7:0]
set_location_assignment PIN_J9  -to vga_b[0]
set_location_assignment PIN_B10 -to vga_b[1]
set_location_assignment PIN_A10 -to vga_b[2]
set_location_assignment PIN_C10 -to vga_b[3]
set_location_assignment PIN_J10 -to vga_b[4]
set_location_assignment PIN_D9  -to vga_b[5]
set_location_assignment PIN_B9  -to vga_b[6]
set_location_assignment PIN_A9  -to vga_b[7]
# Upper 2 bits unused

# I/O Standards
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to *

puts "DE1-SoC pins configured!"
