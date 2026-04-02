# ============================================================================
# LCD Pin Assignments for DE2 Board
# 16x2 Character LCD Display (HD44780 compatible)
#
# Usage: Run this script in Quartus to assign LCD pins
#   Tools > Tcl Scripts > Run Script... > Select this file
#
# Or from Quartus Tcl console:
#   source lcd_pins.tcl
# ============================================================================

# Pin Assignments - LCD 16x2 Character Display (DE2 LCD Header)
# 4-bit interface: Uses DB4-DB7 (LCD_DATA[4:7])
set_location_assignment PIN_K1 -to lcd_rs         ;# LCD Command/Data Select
set_location_assignment PIN_K4 -to lcd_rw         ;# LCD Read/Write Select
set_location_assignment PIN_K3 -to lcd_e          ;# LCD Enable
set_location_assignment PIN_J4 -to lcd_data[0]    ;# LCD_DATA[4] = DB4
set_location_assignment PIN_J3 -to lcd_data[1]    ;# LCD_DATA[5] = DB5
set_location_assignment PIN_H4 -to lcd_data[2]    ;# LCD_DATA[6] = DB6
set_location_assignment PIN_H3 -to lcd_data[3]    ;# LCD_DATA[7] = DB7
set_location_assignment PIN_L4 -to lcd_on         ;# LCD Power ON/OFF
set_location_assignment PIN_K2 -to lcd_blon       ;# LCD Backlight ON/OFF

# I/O Standards for LCD pins (3.3V LVTTL)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_rs
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_rw
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_e
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_data[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_on
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to lcd_blon

puts "LCD pin assignments completed successfully!"
puts "Pins assigned according to DE2 LCD header specification"
