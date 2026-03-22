# DE1-SoC Migration Guide

## Why Switch to DE1-SoC?

**Memory Capacity:**
- DE2: 0.4 Mbits on-chip RAM → **Too small for ZolotyhNet!**
- DE1-SoC: 5.6 Mbits on-chip RAM → **14× more, weights FIT!**

**Lab Manual Alignment:**
- Your lab manual specifically mentions DE1-SoC!
- Matches the SoPC architecture requirement

---

## DE1-SoC Board Specifications

**FPGA:** Cyclone V SE 5CSEMA5F31C6
- 85K Logic Elements (vs. DE2's 33K)
- 5.6 Mbits M10K RAM (vs. DE2's 0.4 Mbits)
- 1 GB DDR3
- ARM Cortex-A9 dual-core @ 925 MHz

**Peripherals:**
- 10 Red LEDs (LEDR[9:0])
- 8 Green User LEDs (LED[7:0]) - note: different from LEDG!
- 4 Buttons (KEY[3:0])
- 10 Switches (SW[9:0])
- VGA output (same as DE2)
- UART-to-USB bridge (easier than DE2!)

---

## Migration Steps

### Step 1: Create New Quartus Project

1. **Open Quartus Prime**
2. **File → New Project Wizard**

**Project Settings:**
- **Directory:** `C:\Users\bakkhedr\Desktop\marly capstone\quartus_de1soc`
- **Project name:** `ecg_de1soc`
- **Top-level:** `ecg_system_top`

**Device Selection:**
- **Family:** Cyclone V
- **Device:** 5CSEMA5F31C6
- Click Finish

---

### Step 2: Add All VHDL Files

**Add these files (same as DE2!):**

**Core system:**
- `../src/ecg_system_top.vhd`
- `../src/uart_receiver.vhd`
- `../src/clk_divider.vhd`
- `../src/vga_timing_generator.vhd`
- `../src/ecg_vga_renderer.vhd`
- `../src/user_interface_controller.vhd`
- `../src/cnn_interface.vhd`

**CNN modules:**
- `../src/cnn/zolotyhnet_top.vhd` (use the 9-engine version!)
- `../src/cnn/buffer_128.vhd`
- `../src/cnn/layer_buffer.vhd`
- `../src/cnn/weight_rom.vhd`
- `../src/cnn/conv1d_engine.vhd`
- `../src/cnn/linear_engine.vhd`
- `../src/cnn/maxpool1d.vhd`
- `../src/cnn/relu.vhd`

**Weight files:**
- All 18 `.mif` files from `../quartus_de2/weights/`

**NO VHDL changes needed!** All files are portable!

---

### Step 3: Pin Assignments (DE1-SoC)

**Create file: `quartus_de1soc/de1soc_pins.tcl`**

```tcl
# ============================================================================
# DE1-SoC Pin Assignments
# ============================================================================

# Clock (50 MHz)
set_location_assignment PIN_AF14 -to clk_50mhz

# Reset (KEY[0])
set_location_assignment PIN_AA14 -to reset_n

# UART (USB-UART bridge)
set_location_assignment PIN_AE26 -to uart_rx  # UART_RXD

# Push Buttons
set_location_assignment PIN_AA15 -to btn[0]  # KEY[1]

# Red LEDs LEDR[3:0]
set_location_assignment PIN_V16 -to led[0]   # LEDR[0]
set_location_assignment PIN_W16 -to led[1]   # LEDR[1]
set_location_assignment PIN_V17 -to led[2]   # LEDR[2]
set_location_assignment PIN_V18 -to led[3]   # LEDR[3]

# Green User LEDs LED[7:0] (for classification)
set_location_assignment PIN_W20 -to ledg[0]  # LED[0]
set_location_assignment PIN_Y19 -to ledg[1]  # LED[1]
set_location_assignment PIN_W19 -to ledg[2]  # LED[2]
set_location_assignment PIN_W17 -to ledg[3]  # LED[3]
set_location_assignment PIN_V19 -to ledg[4]  # LED[4]
set_location_assignment PIN_V20 -to ledg[5]  # LED[5]
set_location_assignment PIN_V21 -to ledg[6]  # LED[6]
set_location_assignment PIN_W21 -to ledg[7]  # LED[7]

# VGA (same interface as DE2)
set_location_assignment PIN_B13 -to vga_hsync
set_location_assignment PIN_C13 -to vga_vsync

# VGA Red [9:0] (note: different from DE2!)
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

# VGA Green [9:0]
set_location_assignment PIN_H12 -to vga_g[0]
set_location_assignment PIN_H11 -to vga_g[1]
set_location_assignment PIN_H10 -to vga_g[2]
set_location_assignment PIN_H9  -to vga_g[3]
set_location_assignment PIN_F10 -to vga_g[4]
set_location_assignment PIN_G8  -to vga_g[5]
set_location_assignment PIN_G9  -to vga_g[6]
set_location_assignment PIN_A13 -to vga_g[7]
set_location_assignment PIN_B13 -to vga_g[8]
set_location_assignment PIN_C13 -to vga_g[9]

# VGA Blue [9:0]
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

# I/O Standards (3.3V for all)
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to *
```

**Run this in Quartus:** Tools → Tcl Scripts → Run Script → Select `de1soc_pins.tcl`

---

### Step 4: Clock Constraints (SDC file)

**Create file: `quartus_de1soc/ecg_de1soc.sdc`**

```sdc
# 50 MHz system clock
create_clock -name clk_50mhz -period 20.000 [get_ports {clk_50mhz}]

# 25 MHz VGA clock (derived)
create_generated_clock -name clk_25mhz \
    -source [get_ports {clk_50mhz}] \
    -divide_by 2 \
    [get_registers {clk_div_inst|clk_out_reg}]

derive_clock_uncertainty

# Asynchronous inputs
set_false_path -from [get_ports {reset_n}]
set_false_path -from [get_ports {uart_rx}]
set_false_path -from [get_ports {btn[*]}]

# Asynchronous outputs
set_false_path -to [get_ports {led[*]}]
set_false_path -to [get_ports {ledg[*]}]

# VGA outputs
set_output_delay -clock clk_25mhz -max 5.0 [get_ports {vga_*}]
set_output_delay -clock clk_25mhz -min 0.0 [get_ports {vga_*}]
```

---

## VHDL Changes Required

### ✅ NO CHANGES to these files:
- All `src/*.vhd` files (100% portable!)
- All `src/cnn/*.vhd` files (100% portable!)
- Python scripts (100% same!)

### ⚠️ Minor change to ONE file:

**File: `src/ecg_system_top.vhd`**

Change line mentioning "ledg" output if it doesn't exist:
- DE1-SoC uses `LED[7:0]` (not `LEDG[7:0]`)
- May need to rename signal in entity

**Check if `ledg` port exists in ecg_system_top entity.**
- If yes: No change needed
- If no: We already added it for DE2, so should be fine!

---

## Step-by-Step Creation

### 1. Create Quartus Project (15 min)

```
File → New Project Wizard
  Directory: C:\Users\bakkhedr\Desktop\marly capstone\quartus_de1soc
  Name: ecg_de1soc
  Top: ecg_system_top
  Family: Cyclone V
  Device: 5CSEMA5F31C6
```

### 2. Add Files (10 min)

`Project → Add/Remove Files`
- Add all 15 VHDL files listed above
- Add SDC file

### 3. Run Pin Assignment Script (5 min)

`Tools → Tcl Scripts → Run Script`
- Select `de1soc_pins.tcl`

### 4. Compile! (10-15 min)

`Processing → Start Compilation`

**Expected:**
- 0 errors
- ~8,000-10,000 LEs used (10% of 85K)
- ~235 Kbits RAM used (4% of 5.6 Mbits) ✅ **FITS!**

---

## Testing on DE1-SoC

**Connections:**
1. Power: 12V adapter
2. USB Blaster: Mini-USB (for programming)
3. UART: **Built-in USB-UART** (no adapter needed!)
4. VGA: Standard VGA cable

**Python Script:**
```bash
# Check Device Manager for COM port (will be different)
python python/ecg_streamer_live.py --port COM5 --file "ECG signals/100.dat" --signal 0
```

**Expected:**
- LEDR[0]: UART data flashing
- LEDR[3]: CNN processing indicator
- LED[7]: Normal classification (green)
- LED[6]: LBBB classification (green)
- LED[5]: PVC classification (green)

**And it should WORK with real classifications!** 🎉

---

## Summary: Migration Checklist

- [ ] Create new Quartus project (Cyclone V device)
- [ ] Add all 15 VHDL files
- [ ] Copy 18 weight .mif files to project
- [ ] Run pin assignment script
- [ ] Add SDC timing constraints
- [ ] Compile (should succeed!)
- [ ] Program DE1-SoC board
- [ ] Test with Python scripts
- [ ] **Celebrate working CNN!** 🎉

**Total time: 4-6 hours**

---

**Ready to start?** Create the new project and I'll help with any issues!
