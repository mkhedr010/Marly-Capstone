# ============================================================================
# Timing Constraints for DE1-SoC ECG CNN System
# ============================================================================

# 50 MHz system clock
create_clock -name clk_50mhz -period 20.000 [get_ports {clk_50mhz}]

# 25 MHz VGA pixel clock (derived from 50 MHz)
create_generated_clock -name clk_25mhz \
    -source [get_ports {clk_50mhz}] \
    -divide_by 2 \
    [get_registers {clk_div_inst|clk_out_reg}]

# Auto-derive clock uncertainty
derive_clock_uncertainty

# Asynchronous inputs (no timing constraints)
set_false_path -from [get_ports {reset_n}]
set_false_path -from [get_ports {uart_rx}]
set_false_path -from [get_ports {btn[*]}]

# Asynchronous outputs
set_false_path -to [get_ports {led[*]}]
set_false_path -to [get_ports {ledg[*]}]

# VGA outputs (relaxed timing - monitors are tolerant)
set_output_delay -clock clk_25mhz -max 5.0 [get_ports {vga_*}]
set_output_delay -clock clk_25mhz -min 0.0 [get_ports {vga_*}]
