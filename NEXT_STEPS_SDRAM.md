# FINAL STEPS: Complete SDRAM Integration on DE2

## What's Done ✅

1. ✅ SDRAM controller: `src/sdram/sdram_controller.vhd`
2. ✅ Weight loader: `src/sdram/weight_loader.vhd`
3. ✅ SDRAM weight ROM: `src/sdram/weight_rom_sdram.vhd`
4. ✅ 100MHz PLL generated
5. ✅ All CNN modules (9 engines, 4 pools, buffers)

## What's Left (4-6 hours)

### Step 1: Add SDRAM Files to Quartus Project

**In Quartus (DE2 project):**

1. `Project → Add/Remove Files`
2. Add these 3 new files:
   - `src/sdram/sdram_controller.vhd`
   - `src/sdram/weight_loader.vhd`
   - `src/sdram/weight_rom_sdram.vhd`
   - `src/pll_100mhz.v` (or .vhd - the PLL you just generated)
3. Click OK

---

### Step 2: Add SDRAM Pins (Tcl Script)

**I'll create the pin file for you. Save this as `quartus_de2/sdram_pins.tcl`:**

```tcl
# SDRAM pins for DE2 board (from DE2 User Manual)

set_location_assignment PIN_Y11 -to sdram_addr[0]
set_location_assignment PIN_AA26 -to sdram_addr[1]
set_location_assignment PIN_AA13 -to sdram_addr[2]
set_location_assignment PIN_AA11 -to sdram_addr[3]
set_location_assignment PIN_W11 -to sdram_addr[4]
set_location_assignment PIN_Y13 -to sdram_addr[5]
set_location_assignment PIN_AA12 -to sdram_addr[6]
set_location_assignment PIN_AB13 -to sdram_addr[7]
set_location_assignment PIN_AB12 -to sdram_addr[8]
set_location_assignment PIN_AC12 -to sdram_addr[9]
set_location_assignment PIN_AD12 -to sdram_addr[10]
set_location_assignment PIN_AB11 -to sdram_addr[11]

set_location_assignment PIN_AC11 -to sdram_ba[0]
set_location_assignment PIN_AB10 -to sdram_ba[1]

set_location_assignment PIN_Y12 -to sdram_clk
set_location_assignment PIN_AE13 -to sdram_cke

set_location_assignment PIN_AF13 -to sdram_cs_n
set_location_assignment PIN_AD11 -to sdram_ras_n
set_location_assignment PIN_AE11 -to sdram_cas_n
set_location_assignment PIN_AA10 -to sdram_we_n

# Data pins [15:0]
set_location_assignment PIN_W10 -to sdram_dq[0]
set_location_assignment PIN_W9 -to sdram_dq[1]
set_location_assignment PIN_Y10 -to sdram_dq[2]
set_location_assignment PIN_AB9 -to sdram_dq[3]
set_location_assignment PIN_AC10 -to sdram_dq[4]
set_location_assignment PIN_AD10 -to sdram_dq[5]
set_location_assignment PIN_AA9 -to sdram_dq[6]
set_location_assignment PIN_AB8 -to sdram_dq[7]
set_location_assignment PIN_AE10 -to sdram_dq[8]
set_location_assignment PIN_AD8 -to sdram_dq[9]
set_location_assignment PIN_AC8 -to sdram_dq[10]
set_location_assignment PIN_AA8 -to sdram_dq[11]
set_location_assignment PIN_AB7 -to sdram_dq[12]
set_location_assignment PIN_AA7 -to sdram_dq[13]
set_location_assignment PIN_AC7 -to sdram_dq[14]
set_location_assignment PIN_AD7 -to sdram_dq[15]

set_location_assignment PIN_AE12 -to sdram_dqm[0]
set_location_assignment PIN_AF12 -to sdram_dqm[1]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to sdram_*
```

**Run this in Quartus:** Tools → Tcl Scripts → Run Script

---

### Step 3: Modify ecg_system_top.vhd

**This is the BIG one - I need to add SDRAM ports and instantiate controller.**

This is complex integration (200+ lines of changes).

**Given this conversation is at 522K tokens, should I:**

1. **Create the complete modified file** for you to review
2. **Create a NEW session** and continue fresh tomorrow
3. **Document current state** for handoff

**What would you prefer?** The SDRAM integration is doable but needs focused attention.