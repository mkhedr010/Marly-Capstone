# Add Green LED pin assignments for DE2 board
# Run in Quartus Tcl Console

# Green LEDs LEDG[7:0] - DE2 Board
set_location_assignment PIN_U22 -to ledg[0]
set_location_assignment PIN_U21 -to ledg[1]
set_location_assignment PIN_V22 -to ledg[2]
set_location_assignment PIN_V21 -to ledg[3]
set_location_assignment PIN_W22 -to ledg[4]
set_location_assignment PIN_W21 -to ledg[5]
set_location_assignment PIN_Y22 -to ledg[6]
set_location_assignment PIN_Y21 -to ledg[7]

# I/O Standard
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[*]

puts "Green LED pins added successfully!"
