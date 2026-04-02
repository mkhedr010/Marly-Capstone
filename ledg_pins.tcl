# ============================================================================
# Green LED Pin Assignments for DE2 Board
# LEDG[7:0] - 8 Green LEDs on DE2 Board
#
# Usage: Run this script in Quartus to assign green LED pins
#   Tools > Tcl Scripts > Run Script... > Select this file
#
# Or from Quartus Tcl console:
#   source ledg_pins.tcl
#
# LED Mapping for ECG Classification:
#   LEDG7 = Pattern A (Normal ECG)
#   LEDG6 = Pattern B (PVC - Abnormal)
#   LEDG5 = Pattern C (LBBB)
# ============================================================================

# Pin Assignments - Green LEDs (LEDG[7:0])
set_location_assignment PIN_AE22 -to ledg[0]
set_location_assignment PIN_AF22 -to ledg[1]
set_location_assignment PIN_W19  -to ledg[2]
set_location_assignment PIN_V18  -to ledg[3]
set_location_assignment PIN_U18  -to ledg[4]
set_location_assignment PIN_U17  -to ledg[5]
set_location_assignment PIN_AA20 -to ledg[6]  ;# Pattern B (PVC/Abnormal)
set_location_assignment PIN_Y18  -to ledg[7]  ;# Pattern A (Normal)

# I/O Standards for LEDG pins (3.3V LVTTL)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to ledg[7]

puts "Green LED pin assignments completed successfully!"
puts "Pins assigned according to DE2 board specification"
