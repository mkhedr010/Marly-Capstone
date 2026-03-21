# ECG System for Terasic DE2 Board

## Overview

This is the Quartus Prime project for the ECG classification system targeting the **Terasic DE2 board** (Altera Cyclone II EP2C35F672C6).

**Migration Status:** Migrated from Xilinx Spartan-3E to Altera DE2 (March 2026)

## Board Specifications

- **Board:** Terasic DE2 University Program Board
- **FPGA:** Cyclone II EP2C35F672C6
- **Clock:** 50 MHz oscillator
- **Tools:** Quartus Prime (Lite Edition or Standard)

## System Architecture

```
PC (Python)  →  RS-232 UART (115200 baud)  →  FPGA  →  VGA Display (640×480@60Hz)
                                               ↓
                                            CNN Module
                                          (Phase 5 later)
```

### Data Flow

1. Python script reads ECG signals (MIT-BIH .dat or CSV files)
2. Normalizes to 12-bit signed values (-2048 to +2047)
3. Encodes as 2-byte packets (lower 8 bits + upper 4 bits)
4. Transmits via UART at 115200 baud, 360 Hz sample rate
5. FPGA receives and displays scrolling waveform on VGA monitor
6. LED indicators show system status

## Hardware Connections

### Required Connections

1. **Power:** Connect 9V DC power adapter to DE2 board
2. **USB Blaster:** Connect USB cable for programming (mini-USB port)
3. **RS-232:** Connect RS-232 cable from PC COM port to DE2 DB9 connector
4. **VGA:** Connect VGA cable from DE2 VGA port to monitor
5. **Reset:** KEY[3] button (PIN_G26) - active low

### Pin Assignments

All pin assignments are configured in `ecg_de2.qsf`.

#### Critical Pins

| Signal | Pin | Description |
|--------|-----|-------------|
| clk_50mhz | PIN_N2 | 50 MHz system clock |
| reset_n | PIN_G26 | KEY[3] - active low reset |
| uart_rx | PIN_C25 | RS-232 RXD (from PC) |
| vga_hsync | PIN_A7 | VGA horizontal sync |
| vga_vsync | PIN_D8 | VGA vertical sync |
| led[0] | PIN_AE23 | LEDR[0] - UART data indicator |
| led[1] | PIN_AF23 | LEDR[1] - VGA/system active |
| led[2] | PIN_AB21 | LEDR[2] - Pause state |
| led[3] | PIN_AC22 | LEDR[3] - CNN result (Phase 5) |
| btn[0] | PIN_N23 | KEY[0] - Pause button |

See `ecg_de2.qsf` for complete VGA RGB pin assignments (30 pins total for 10-bit RGB).

## Project Structure

```
quartus_de2/
├── ecg_de2.qpf          # Quartus project file
├── ecg_de2.qsf          # Settings file (pin assignments, device config)
├── ecg_de2.sdc          # Timing constraints
└── README_DE2.md        # This file
```

**VHDL Source Files** (in `../src/`):
- `ecg_system_top.vhd` - Top-level entity (MODIFIED for DE2)
- `ecg_vga_renderer.vhd` - VGA renderer (MODIFIED for DE2)
- `uart_receiver.vhd` - UART RX (vendor-neutral)
- `vga_timing_generator.vhd` - VGA timing (vendor-neutral)
- `clk_divider.vhd` - Clock divider (vendor-neutral)
- `user_interface_controller.vhd` - UI controller (vendor-neutral)
- `cnn_interface.vhd` - CNN interface (vendor-neutral)
- `led_indicator.vhd` - LED control (vendor-neutral)

## Compilation Instructions

### Prerequisites

1. Install **Quartus Prime Lite Edition** (free) or Standard Edition
2. Ensure USB Blaster drivers are installed

### Compilation Steps

1. **Open Project:**
   ```
   File > Open Project > Select ecg_de2.qpf
   ```

2. **Verify Settings:**
   - Device: EP2C35F672C6
   - Top-level entity: ecg_system_top
   - All VHDL files added

3. **Compile Design:**
   ```
   Processing > Start Compilation
   ```
   Or press Ctrl+L

4. **Wait for Compilation:** (~5-10 minutes on typical PC)

5. **Check Results:**
   - Compilation Report should show **0 errors**
   - Review warnings (minor warnings OK, ignore "no CNN connection" warnings for Phase 3-4)
   - TimeQuest Timing Analyzer: **No timing violations**

### Expected Resource Utilization

- **Logic Elements:** ~2,000 / 33,216 (~6%)
- **Memory Bits:** ~50,000 / 483,840 (~10%)
- **PLLs:** 0 / 4 (using simple divider)
- **Pins:** 48 / 475 (~10%)

## Programming the FPGA

### Download Bitstream

1. **Connect USB Blaster:** Ensure USB cable connected to DE2

2. **Open Programmer:**
   ```
   Tools > Programmer
   ```

3. **Setup Programming:**
   - Hardware Setup: USB-Blaster [USB-0]
   - Mode: JTAG
   - Add File: `output_files/ecg_de2.sof`
   - Check: Program/Configure box

4. **Program:**
   - Click **Start** button
   - Wait for "100% Successful" message

5. **Verify:**
   - LED[3] should blink at ~1 Hz (heartbeat)

## Testing & Verification

### Stage 1: LED Heartbeat Test

**Goal:** Verify basic FPGA operation

**Test:**
1. Program bitstream to DE2
2. Observe LED[3] (LEDR[3])

**Expected:** LED[3] blinks at 1 Hz (heartbeat indicator)

**If fails:** Check power, clock pin (PIN_N2), reset (PIN_G26)

---

### Stage 2: UART Test

**Goal:** Verify UART communication

**Setup:**
1. Connect RS-232 cable (PC ↔ DE2)
2. Identify COM port in Windows Device Manager
3. Run Python test script:
   ```bash
   python python/test_uart_only.py --port COM4
   ```

**Expected LED Behavior:**
- LED[0]: Rapid blinking (~360 Hz toggle) - data reception
- LED[1]: ON (steady) - UART active
- LED[2]: OFF - no errors
- LED[3]: 1 Hz heartbeat

**If fails:**
- Check RS-232 cable connection
- Verify COM port number
- Use Quartus SignalTap II to probe `uart_rx` signal

---

### Stage 3: VGA Test

**Goal:** Verify VGA display

**Setup:**
1. Connect VGA cable (DE2 ↔ Monitor)
2. Monitor should auto-detect 640×480@60Hz

**Expected:** Black screen with scrolling ECG waveform (when UART data received)

**For static test pattern:**
Temporarily modify [ecg_vga_renderer.vhd:131-133](../src/ecg_vga_renderer.vhd#L131-L133) to display color bars:
```vhdl
if pixel_x_int < 213 then
    rgb_out <= "11100000";  -- Red bar
elsif pixel_x_int < 426 then
    rgb_out <= "00011100";  -- Green bar
else
    rgb_out <= "00000011";  -- Blue bar
end if;
```

**Expected:** Three vertical color bars (red, green, blue)

**If fails:**
- Check VGA cable and monitor input
- Verify HSYNC (PIN_A7), VSYNC (PIN_D8) connections
- Check RGB pin assignments in QSF file

---

### Stage 4: Full System Test

**Goal:** End-to-end ECG streaming and visualization

**Setup:**
1. Ensure UART and VGA connected
2. Run Python streaming script:
   ```bash
   python python/ecg_streamer_live.py --port COM4 --file "ECG signals/15814" --signal 0 --rate 360
   ```

**Expected:**
- **VGA Monitor:** Scrolling green ECG waveform on black background
- **Python Window:** Real-time matplotlib plot (same signal)
- **LED[0]:** Rapid blinking (UART data)
- **LED[1]:** ON (VGA active)
- **LED[2]:** OFF (not paused)
- **Python Console:** "Streaming at ~360 Hz"

**Success Criteria:**
- ✅ Waveforms match (VGA and Python)
- ✅ Sample rate: 356-364 Hz (±1%)
- ✅ No dropped samples or errors

---

### Stage 5: Button Test

**Goal:** Verify pause functionality

**Test:**
1. While Stage 4 running, press KEY[0] button
2. Observe waveform freezes, LED[2] turns ON
3. Press KEY[0] again
4. Observe waveform resumes, LED[2] turns OFF

## LED Indicator Guide

| LED | Function | Expected Behavior |
|-----|----------|-------------------|
| LED[0] (LEDR[0]) | UART Data | Rapid blinking when receiving data (~360 Hz toggle) |
| LED[1] (LEDR[1]) | VGA/System Active | ON steady when system running |
| LED[2] (LEDR[2]) | Pause State | ON when paused, OFF when running |
| LED[3] (LEDR[3]) | Heartbeat / CNN | 1 Hz blink (heartbeat), or CNN result (Phase 5) |

## Python Script Usage

### Check COM Port

**Windows Device Manager:**
1. Open Device Manager
2. Expand "Ports (COM & LPT)"
3. Find "USB Serial Port (COMx)" or similar
4. Note the COM port number (e.g., COM4)

### Run Streaming Script

```bash
cd "C:\Users\bakkhedr\Desktop\marly capstone"
python python/ecg_streamer_live.py --port COM4 --file "ECG signals/15814" --signal 0 --rate 360
```

**Arguments:**
- `--port COM4`: Specify COM port (check Device Manager)
- `--file "ECG signals/15814"`: Path to ECG data file
- `--signal 0`: Signal number (for multi-signal files)
- `--rate 360`: Sample rate in Hz

**Alternative datasets:**
```bash
# Normal sinus rhythm
python python/ecg_streamer_live.py --port COM4 --file "ECG signals/16265"

# CSV file
python python/ecg_streamer_live.py --port COM4 --file python/data/normal_ecg.csv
```

## Troubleshooting

### Compilation Issues

**Error: "Top-level entity not found"**
- **Fix:** In QSF file, verify `set_global_assignment -name TOP_LEVEL_ENTITY ecg_system_top`

**Error: "File not found: ../src/xxx.vhd"**
- **Fix:** Ensure all VHDL source files in `../src/` directory
- **Fix:** Check relative paths in QSF file

**Warning: "No clock assigned to..."**
- **Fix:** Verify SDC file loaded: `set_global_assignment -name SDC_FILE ecg_de2.sdc`

**Timing violations**
- **Review:** TimeQuest Timing Analyzer report
- **Fix:** Check clock constraints (50 MHz, 25 MHz) in SDC file

### Programming Issues

**"Unable to scan device chain"**
- **Fix:** Check USB Blaster connection
- **Fix:** Install/update USB Blaster drivers
- **Fix:** Power cycle DE2 board

**"Error during programming"**
- **Fix:** Ensure .sof file path correct
- **Fix:** Select JTAG mode (not Active Serial)
- **Fix:** Check FPGA device matches: EP2C35F672C6

### UART Issues

**No data received (LED[0] not blinking)**
- **Fix:** Check RS-232 cable connection (PC ↔ DE2)
- **Fix:** Verify COM port in Python script matches Device Manager
- **Fix:** Test with different COM port (COM3, COM4, COM5)
- **Fix:** Check UART_RX pin (PIN_C25) in QSF file

**UART errors (LED[2] blinking)**
- **Fix:** Verify baud rate (115200) in both VHDL and Python
- **Fix:** Check RS-232 cable quality
- **Fix:** Use SignalTap to probe `uart_rx` waveform

### VGA Issues

**No display on monitor**
- **Fix:** Check VGA cable connection
- **Fix:** Try different VGA monitor
- **Fix:** Verify monitor supports 640×480@60Hz
- **Fix:** Check HSYNC (PIN_A7), VSYNC (PIN_D8) in QSF

**Wrong colors**
- **Fix:** Verify RGB bit expansion in [ecg_vga_renderer.vhd:146-149](../src/ecg_vga_renderer.vhd#L146-L149)
- **Fix:** Check RGB pin assignments (30 pins total) in QSF
- **Fix:** Test with color bar pattern (see Stage 3)

**Flickering display**
- **Fix:** Try different VGA cable
- **Fix:** Check 25 MHz clock quality
- **Future:** Upgrade to ALTPLL (Phase 5)

**Waveform not scrolling**
- **Fix:** Ensure UART data received (check LED[0])
- **Fix:** Verify Python script running and transmitting
- **Fix:** Check sample rate (~360 Hz)

## Known Issues & Limitations

### Current Limitations (Phase 3-4)

1. **Simple Clock Divider:** Using toggle-based divider for 25 MHz VGA clock
   - May cause minor VGA timing jitter
   - Acceptable for Phase 3-4 testing
   - Will upgrade to ALTPLL in Phase 5

2. **CNN Interface:** Placeholder only
   - CNN module not implemented yet (Phase 5)
   - LED[3] shows heartbeat instead of classification

3. **No TX UART:** UART transmit not implemented
   - DE2 cannot send data back to PC
   - Phase 5 may add if needed for debugging

### Future Enhancements (Phase 5)

- Implement CNN classification (ZolotyhNet or MyModule)
- Upgrade to ALTPLL for better clock quality
- Add UART TX for sending classification results to PC
- Optimize resource utilization for CNN integration

## Performance Specifications

### Timing

| Parameter | Specification |
|-----------|---------------|
| System Clock | 50 MHz (±50 ppm) |
| VGA Clock | 25 MHz (derived, divide-by-2) |
| UART Baud Rate | 115200 bps |
| Sample Rate | 360 Hz (±1%) |
| VGA Refresh | 60 Hz (640×480) |

### Data Format

| Parameter | Format |
|-----------|--------|
| ECG Sample | 12-bit signed (-2048 to +2047) |
| UART Frame | 2 bytes per sample (8N1) |
| VGA RGB | 10-bit per channel (30-bit total) |

### Resource Usage

| Resource | Used | Total | Utilization |
|----------|------|-------|-------------|
| Logic Elements | ~2,000 | 33,216 | ~6% |
| Memory Bits | ~50,000 | 483,840 | ~10% |
| PLLs | 0 | 4 | 0% |
| I/O Pins | 48 | 475 | ~10% |

## Version History

- **v1.0 (March 2026):** Initial DE2 migration from Xilinx Spartan-3E
  - Created Quartus project (QSF, QPF, SDC)
  - Modified VHDL for 10-bit VGA RGB
  - Verified UART + VGA functionality (Phase 3-4)

## Contact & Support

For issues or questions:
- **Project:** ECG Classification Capstone
- **Board:** Terasic DE2 (Cyclone II EP2C35F672C6)
- **Tools:** Quartus Prime, Python 3.x
- **Documentation:** See `../docs/` folder (legacy, may be outdated)

## Next Steps

✅ **Phase 3-4 Complete** - Infrastructure working

🎯 **Phase 5 Next:**
1. Choose CNN model (ZolotyhNet recommended)
2. Implement CNN in VHDL/HLS
3. Integrate with `cnn_interface.vhd`
4. Test real-time classification at 360 Hz
5. Display results on LED[3] and VGA

---

**Last Updated:** March 2026
**Target Board:** Terasic DE2 (Cyclone II EP2C35F672C6)
**Status:** Phase 3-4 Implementation Complete
