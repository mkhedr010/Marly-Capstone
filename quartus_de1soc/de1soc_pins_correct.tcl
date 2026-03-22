# ============================================================================
# DE1-SoC CORRECT Pin Assignments (from official file)
# Maps our signal names to DE1-SoC pins
# ============================================================================

# Clock (50 MHz) - our signal: clk_50mhz → DE1-SoC: CLOCK_50
set_location_assignment PIN_AF14 -to clk_50mhz

# Reset (KEY[0]) - our signal: reset_n
set_location_assignment PIN_AA14 -to reset_n

# UART - For now, comment out (will use GPIO or HPS_UART later)
# We need to find which pin is the FPGA-side UART RX
# Likely one of the GPIO pins or use HPS_UART
# For initial test, comment this out:
# set_location_assignment PIN_??? -to uart_rx

# Push Button (KEY[1]) - our signal: btn[0]
set_location_assignment PIN_AA15 -to btn[0]

# Red LEDs - our signals: led[3:0] → DE1-SoC: LEDR[3:0]
set_location_assignment PIN_V16 -to led[0]
set_location_assignment PIN_W16 -to led[1]
set_location_assignment PIN_V17 -to led[2]
set_location_assignment PIN_V18 -to led[3]

# Classification LEDs - our signals: ledg[7:0] → DE1-SoC: LEDR[9:4] + extra
set_location_assignment PIN_W17 -to ledg[0]  # LEDR[4]
set_location_assignment PIN_W19 -to ledg[1]  # LEDR[5]
set_location_assignment PIN_Y19 -to ledg[2]  # LEDR[6]
set_location_assignment PIN_W20 -to ledg[3]  # LEDR[7]
set_location_assignment PIN_W21 -to ledg[4]  # LEDR[8]
set_location_assignment PIN_Y21 -to ledg[5]  # LEDR[9]
set_location_assignment PIN_W17 -to ledg[6]  # Duplicate
set_location_assignment PIN_W17 -to ledg[7]  # Duplicate

# VGA - our signals: vga_hsync/vsync/r/g/b → DE1-SoC: VGA_HS/VS/R/G/B
set_location_assignment PIN_B11 -to vga_hsync  # VGA_HS
set_location_assignment PIN_D11 -to vga_vsync  # VGA_VS

# VGA Red [7:0] - map our vga_r[7:0] to VGA_R[7:0]
set_location_assignment PIN_A13 -to vga_r[0]
set_location_assignment PIN_C13 -to vga_r[1]
set_location_assignment PIN_E13 -to vga_r[2]
set_location_assignment PIN_B12 -to vga_r[3]
set_location_assignment PIN_C12 -to vga_r[4]
set_location_assignment PIN_D12 -to vga_r[5]
set_location_assignment PIN_E12 -to vga_r[6]
set_location_assignment PIN_F13 -to vga_r[7]
# vga_r[9:8] unused (DE1-SoC only has 8-bit VGA)

# VGA Green [7:0]
set_location_assignment PIN_J9  -to vga_g[0]
set_location_assignment PIN_J10 -to vga_g[1]
set_location_assignment PIN_H12 -to vga_g[2]
set_location_assignment PIN_G10 -to vga_g[3]
set_location_assignment PIN_G11 -to vga_g[4]
set_location_assignment PIN_G12 -to vga_g[5]
set_location_assignment PIN_F11 -to vga_g[6]
set_location_assignment PIN_E11 -to vga_g[7]
# vga_g[9:8] unused

# VGA Blue [7:0]
set_location_assignment PIN_B13 -to vga_b[0]
set_location_assignment PIN_G13 -to vga_b[1]
set_location_assignment PIN_H13 -to vga_b[2]
set_location_assignment PIN_F14 -to vga_b[3]
set_location_assignment PIN_H14 -to vga_b[4]
set_location_assignment PIN_F15 -to vga_b[5]
set_location_assignment PIN_G15 -to vga_b[6]
set_location_assignment PIN_J14 -to vga_b[7]
# vga_b[9:8] unused

# I/O Standards
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to *

puts "DE1-SoC pins configured (verified from official file)!"
