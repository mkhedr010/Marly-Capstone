# ISE Project Setup Guide
## Creating Xilinx ISE Project for ECG Simulation System

**Target**: Spartan-3E FPGA  
**Tool**: Xilinx ISE Design Suite 14.7  
**Estimated Time**: 15 minutes

---

## Step-by-Step Instructions

### 1. Launch ISE (2 minutes)

- Open Xilinx ISE Design Suite
- Click **File → New Project**

---

### 2. Project Settings (3 minutes)

**Project New**:
- **Name**: `ecg_simulation_uart`
- **Location**: `C:\Users\bakkhedr\Desktop\marly capstone\src`
- **Top-level source type**: HDL
- Click **Next**

**Device Properties**:
- **Product Category**: All
- **Family**: Spartan3E
- **Device**: XC3S500E (or your specific part)
- **Package**: FG320 (or your package)
- **Speed**: -4 (or your speed grade)
- **Synthesis Tool**: XST (VHDL)
- **Simulator**: ISim (VHDL)
- **Preferred Language**: VHDL
- Click **Next**

**Project Summary**:
- Verify settings
- Click **Finish**

---

### 3. Add Source Files (5 minutes)

**Add VHDL Files**:
1. Right-click project → **Add Source**
2. Navigate to `src/` folder
3. Select ALL `.vhd` files:
   - ☑ ecg_system_top.vhd
   - ☑ uart_receiver.vhd
   - ☑ clk_divider.vhd
   - ☑ vga_timing_generator.vhd
   - ☑ ecg_vga_renderer.vhd
   - ☑ user_interface_controller.vhd
   - ☑ cnn_interface.vhd
4. Click **Open**
5. Click **OK** (associate with current project)

**Add UCF File**:
1. Right-click project → **Add Source**
2. Select `spartan3e.ucf`
3. Click **Open**

**Set Top Module**:
1. Right-click `ecg_system_top.vhd`
2. Select **Set as Top Module**
3. Icon should show hierarchy view

---

### 4. Verify Pin Constraints (5 minutes)

**Open UCF file** (`spartan3e.ucf`)

**CRITICAL**: Verify UART_RX pin location!

```
NET "uart_rx" LOC = "R7" | IOSTANDARD = LVCMOS33;
```

**Check your board manual** for correct UART RX pin. Common locations:
- **R7** - Nexys2, some Spartan-3E Starter Kits
- **T13** - Some Spartan-3E variants
- **U8** - Other variants

**Also verify**:
- Clock pin (usually C9)
- VGA pins (check RGB order)
- LED pins
- Button pins

**Save UCF** after any changes.

---

### 5. Check Syntax (2 minutes)

1. **Expand Hierarchy** in Design panel
2. **Right-click ecg_system_top**
3. **Check Syntax**
4. Wait for completion
5. **Verify** "Syntax check succeeded"

**If errors**:
- Double-click error to see line
- Common issues:
  - Missing semicolon
  - Signal name typo
  - Port mismatch
- Fix and re-check

---

### 6. Synthesize (Optional - for verification)

**Note**: This takes 5-10 minutes

1. Click **Synthesize** (green check icon)
2. Wait for completion
3. **Check report**:
   - Resource usage
   - Warnings (review, usually OK)
   - Errors (must fix!)

**Expected Resource Usage**:
```
Logic: ~1,500 / 10,476 (14%)
BRAM:  ~2 / 20 blocks (10%)
```

---

## Project File Structure

After setup, ISE creates these files:
```
src/
├── ecg_simulation_uart.xise  ← ISE project file
├── ecg_simulation_uart.gise  ← Project settings
├── *.vhd                     ← Your VHDL files
├── spartan3e.ucf             ← Constraints
└── iseconfig/                ← ISE configuration (auto-generated)
```

**Add to .gitignore**:
```
*.bgn
*.bit
*.bld
*.drc
*.ncd
*.ngc
*.ngd
*.ngr
*.pad
*.par
*.pcf
*.prj
*.ptwx
*.syr
*.twr
*.unroutes
_xmsgs/
xlnx_auto_0_xdb/
iseconfig/
```

---

## Opening Existing Project

**Next time you work**:
1. Open ISE
2. **File → Open Project**
3. Navigate to `src/ecg_simulation_uart.xise`
4. Click **Open**

---

## Workflow Overview

### Development Cycle

```
1. Edit VHDL → 2. Check Syntax → 3. Simulate (optional) → 
4. Synthesize → 5. Implement → 6. Generate Bitstream →
7. Program FPGA → 8. Test
```

### Quick Compile (No Simulation)

1. **Synthesize** - XST (green check)
2. **Implement Design** - Translate, Map, Place & Route
3. **Generate Programming File** - Creates .bit file
4. **Configure Target Device** - Program FPGA

**Total time**: ~10-15 minutes for full compilation

---

## Testing Workflow

### Week 1: UART Only

**Build**:
- Comment out VGA modules in top-level temporarily
- Connect uart_receiver output directly to LEDs
- Synthesize quickly (~2 min)

**Test**:
- Program FPGA
- Run Python test script
- LEDs should show data received

### Week 2: Add VGA

**Build**:
- Uncomment VGA modules
- Full synthesis (~10 min)

**Test**:
- Color bar test pattern first
- Then integrate with UART

---

## Common ISE Issues

### Issue: "Could not determine IP status"
**Solution**: Ignore - informational only

### Issue: "WARNING: PhysDesignRules"
**Solution**: Review warnings, usually safe to ignore for prototype

### Issue: "Timing constraint not met"
**Solution**: 
- Check timing report
- May need to adjust DCM or add constraints
- Usually OK for initial testing

### Issue: "Synthesis failed"
**Solution**:
- Read error message carefully
- Double-click to jump to problem line
- Common: signal name typos, missing library

---

## Simulation (Optional)

### Create Testbench

See `src/tb/` folder for examples (to be created Week 1)

### Run Simulation

1. Right-click testbench file
2. **Set as Top Module** (for simulation)
3. **Simulate Behavioral Model** (ISim)
4. View waveforms
5. Verify functionality

**Note**: Simulation is optional - can test on hardware directly

---

## Programming FPGA

### Via ISE iMPACT

1. Connect FPGA via USB/JTAG
2. Power on board
3. In ISE: **Tools → iMPACT**
4. **Boundary Scan → Initialize Chain**
5. Auto-detect devices
6. Assign `ecg_simulation_uart.bit` file
7. Right-click device → **Program**

### Via Command Line

```bash
impact -batch program.cmd
```

Where `program.cmd` contains:
```
setMode -bscan
setCable -p auto
addDevice -p 1 -file ecg_simulation_uart.bit
program -p 1
quit
```

---

## Tips for Success

### Start Simple
1. Week 1: Test UART in isolation
2. Week 2: Test VGA in isolation
3. Week 3: Integrate both

### Use Hierarchy View
- ISE shows module hierarchy
- Helps verify connections
- Right-click modules to view/edit

### Save Often
- ISE can crash
- Save project frequently
- Use Git commits

### Keep Build Times Short
- Comment out unused modules during development
- Test incrementally
- Full build only when ready

---

## Troubleshooting

### Synthesis Takes Forever
**Cause**: Large design or slow PC  
**Solution**: 
- Close other programs
- Disable optimizations temporarily
- Comment out unused modules

### Can't Find Device (iMPACT)
**Cause**: Driver issues or cable  
**Solution**:
- Install/update Xilinx USB drivers
- Try different USB port
- Check JTAG cable connection

### Bitstream Doesn't Work
**Cause**: Wrong device or pins  
**Solution**:
- Verify device part number in project settings
- Check UCF pins match board
- Review synthesis warnings

---

## Next Steps After Setup

1. ✅ Verify project compiles (syntax check)
2. ✅ Read Week 1 in `docs_uart/implementation_roadmap.md`
3. ✅ Start with UART receiver testing
4. ✅ Follow week-by-week plan

---

**Good luck!** 🚀

**Created**: January 21, 2026  
**For**: Xilinx ISE Design Suite 14.7  
**Target**: Spartan-3E FPGA
