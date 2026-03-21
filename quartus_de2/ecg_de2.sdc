# ============================================================================
# ECG DE2 System - Timing Constraints
# Synopsys Design Constraints (SDC) for Quartus Prime
# ============================================================================

# ============================================================================
# Clock Constraints
# ============================================================================

# 50 MHz system clock (50 MHz = 20 ns period)
create_clock -name clk_50mhz -period 20.000 [get_ports {clk_50mhz}]

# 25 MHz VGA pixel clock (derived from 50 MHz via clk_divider module)
# This is a generated clock with divide-by-2
create_generated_clock -name clk_25mhz \
    -source [get_ports {clk_50mhz}] \
    -divide_by 2 \
    [get_registers {clk_div_inst|clk_out_reg}]

# ============================================================================
# Clock Uncertainty
# ============================================================================

# Automatically calculate clock uncertainty based on PLL characteristics
derive_clock_uncertainty

# ============================================================================
# Input Constraints - Asynchronous Inputs
# ============================================================================

# Reset is asynchronous (no timing requirements)
set_false_path -from [get_ports {reset_n}]

# UART RX is asynchronous (separate clock domain from PC)
set_false_path -from [get_ports {uart_rx}]

# Button inputs are asynchronous (user-controlled)
set_false_path -from [get_ports {btn[*]}]

# ============================================================================
# Output Constraints - Asynchronous Outputs
# ============================================================================

# LED outputs are slow and asynchronous (no timing requirements)
set_false_path -to [get_ports {led[*]}]

# ============================================================================
# VGA Output Timing
# ============================================================================

# VGA outputs are relatively relaxed - monitors are tolerant
# Set output delay constraints relative to 25 MHz pixel clock
set_output_delay -clock clk_25mhz -max 5.0 [get_ports {vga_*}]
set_output_delay -clock clk_25mhz -min 0.0 [get_ports {vga_*}]

# ============================================================================
# End of Timing Constraints
# ============================================================================
