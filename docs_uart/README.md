# ECG Simulation Component - UART Streaming Version
## Spartan-3E + PC System

**Student**: Marly  
**Course**: COE 70A/70B Capstone Project (GK02)  
**Component**: ECG Simulation & Visualization  
**Platform**: Xilinx Spartan-3E FPGA + PC  
**Version**: 3.0 (PC-UART Streaming)  
**Date**: January 21, 2026

---

## What Changed from Original Design?

### Original (docs/ folder)
- ECG waveforms stored in FPGA BRAM
- 3 pre-loaded waveforms only
- Complex BRAM initialization

### UART Version (docs_uart/ folder) - **Current**
- ECG waveforms stream from PC via UART
- Unlimited waveforms (any dataset!)
- Simpler FPGA, flexible testing

---

## System Overview

```
┌──────────────┐    USB/UART     ┌──────────────┐    Internal    ┌──────────┐
│   PC         │   115200 baud   │ Spartan-3E   │    Signals     │   CNN    │
│  (Python)    │  ────────────▶  │   (FPGA)     │  ──────────▶   │  Module  │
│              │                 │              │                │          │
│ • Load ECG   │                 │ • UART RX    │                │ • Classify│
│ • Stream     │                 │ • VGA Display│                │          │
│   @ 360 Hz   │                 │ • User UI    │  ◀──────────   │ • Result │
└──────────────┘                 └──────┬───────┘                └──────────┘
                                        │
                                        ▼
                                 VGA Monitor
                            (Scrolling ECG + Results)
```

---

## Core Functionality

### FPGA Side (Your Component)
1. **UART Receiver** - Receive 12-bit ECG samples from PC @ 360 Hz
2. **VGA Display** - Scrolling waveform on 640×480 monitor
3. **CNN Interface** - Feed samples to Ayoub's CNN module (internal signals)
4. **User Interface** - Button for pause, LEDs for status
5. **Classification Display** - Show CNN results on VGA/LEDs

### PC Side (Python Application)
1. **Data Loading** - Read MIT-BIH ECG datasets (CSV files)
2. **Conversion** - Normalize and convert to 12-bit signed integers
3. **Streaming** - Send via UART at 360 Hz
4. **Control** - Select waveform type, loop playback

---

## Key Specifications

### Hardware
- **FPGA**: Spartan-3E XC3S500E
  - 10,476 logic cells
  - 360 Kbits Block RAM
  - 50 MHz clock
- **Interface**: USB-UART (FT232 chip, 115200 baud)
- **Display**: VGA 640×480 @ 60 Hz

### Data Format
- **Sample Rate**: ~360 Hz (from PC)
- **Sample Width**: 12-bit signed integer
- **UART Format**: 2 bytes per sample
  - Byte 1: bits [7:0]
  - Byte 2: bits [11:8] + padding
- **Bandwidth**: 7,200 bps (well within 115,200 baud)

### Resource Usage
- **Logic**: ~14% (reduced from 19% in original)
- **BRAM**: ~7% (reduced from 22% - no ECG storage needed!)
- **I/O**: ~6%

---

## Module Architecture

### 8 VHDL Modules

```
ecg_system_top
├── clk_divider (50MHz → 25MHz)
├── uart_receiver ⭐ NEW (replaces ecg_memory)
├── vga_timing_generator
├── ecg_vga_renderer (updated for sample_valid)
├── user_interface_controller (simplified)
├── cnn_interface (internal to Ayoub's CNN)
└── (7 total + top-level = 8)
```

**Removed from Original**: ecg_memory.vhd (no longer needed!)  
**Added**: uart_receiver.vhd (simpler than BRAM!)

---

## Documentation Files

| File | Purpose |
|------|---------|
| **README.md** | This file - project overview |
| **system_architecture.md** | PC-UART-FPGA design, block diagrams, modules |
| **technical_reference.md** | UART protocol, VGA specs, detailed reference |
| **implementation_roadmap.md** | Week-by-week plan (8 weeks) |

---

## Advantages of UART Approach

### Vs. BRAM Storage

| Aspect | BRAM (Original) | UART (Current) |
|--------|----------------|----------------|
| **Waveforms** | 3 fixed | Unlimited |
| **FPGA Resources** | 4-5 BRAM blocks | 1-2 BRAM blocks |
| **Testing** | Reprogram FPGA | Just run Python |
| **Flexibility** | Low | High ✅ |
| **Data Update** | Synthesis time | Real-time ✅ |
| **Complexity** | Medium | Low ✅ |

### Educational Value

**Still Learn**:
- ✅ VGA display in HDL (main goal!)
- ✅ Clock domain crossing
- ✅ FPGA design and debugging
- ✅ System integration

**Bonus Skills**:
- + UART protocol (universal)
- + PC-FPGA communication
- + Python serial programming
- + Real-time data streaming

---

## Quick Start

### For Development

**1. FPGA Side** (Xilinx ISE):
```bash
cd src/
# Open ecg_simulation_uart.xise in ISE
# Synthesize and program FPGA
```

**2. PC Side** (Python):
```bash
cd python/
pip install -r requirements.txt
python ecg_streamer.py --port COM3 --file data/normal_ecg.csv
```

**3. Connect**:
- USB cable: PC → Spartan-3E
- VGA cable: Spartan-3E → Monitor
- Power on and run!

---

## Implementation Timeline

### COE 70B (8 Weeks)

| Week | Focus | Milestone |
|------|-------|-----------|
| 1 | UART Receiver | Can receive data from PC |
| 2 | VGA Timing | Color bars on monitor |
| 3 | VGA Renderer | ECG waveform displays |
| 4 | Python App | Real ECG streaming |
| 5 | User Interface | Pause, LEDs working |
| 6 | CNN Integration | Classification working |
| 7 | Optimization | Polished system |
| 8 | Documentation | Demo ready |

---

## File Structure

```
marly capstone/
├── docs_uart/                    ← Current documentation
│   ├── README.md                 ← This file
│   ├── system_architecture.md    ← Design specs
│   ├── technical_reference.md    ← UART, VGA details
│   └── implementation_roadmap.md ← Week-by-week plan
│
├── src/                          ← VHDL source code
│   ├── uart_receiver.vhd         ← UART RX module
│   ├── clk_divider.vhd           ← Clock management
│   ├── vga_timing_generator.vhd  ← VGA timing
│   ├── ecg_vga_renderer.vhd      ← Waveform display
│   ├── user_interface_controller.vhd  ← UI
│   ├── cnn_interface.vhd         ← CNN connection
│   ├── ecg_system_top.vhd        ← Top-level
│   ├── tb/                       ← Testbenches
│   └── spartan3e.ucf             ← Pin constraints
│
├── python/                       ← PC application
│   ├── ecg_streamer.py           ← Main app
│   ├── ecg_loader.py             ← Dataset loading
│   ├── uart_handler.py           ← UART communication
│   ├── requirements.txt          ← Python dependencies
│   ├── data/                     ← Sample ECG files
│   │   ├── normal_ecg.csv
│   │   ├── pvc_ecg.csv
│   │   └── afib_ecg.csv
│   └── README.md                 ← Python usage
│
└── docs/ (original), docs_de2115/ (audio version) - for reference
```

---

## Dependencies

### Hardware
- Spartan-3E FPGA board with USB-UART
- VGA monitor (640×480 capable)
- USB cable (PC to FPGA)
- VGA cable

### Software
- **FPGA**: Xilinx ISE Design Suite 14.7
- **Python**: Python 3.7+ with:
  - pyserial 3.5
  - numpy 1.21+
  - pandas 1.3+
- **Optional**: ISim/ModelSim for simulation

---

## Success Criteria

### Minimum Viable Demo
- ✓ UART receives data from PC
- ✓ VGA displays ECG waveform
- ✓ CNN receives samples
- ✓ System runs stably

### Full Feature Demo
- ✓ Smooth scrolling display
- ✓ User can pause/resume
- ✓ LED status indicators
- ✓ CNN classification displayed
- ✓ Multiple waveforms testable

---

## Comparison with Other Versions

### Version History

| Version | Platform | Connection | Storage | Status |
|---------|----------|------------|---------|--------|
| 1.0 | Spartan-3E | GPIO to CNN | BRAM | Reference (docs/) |
| 2.0 | DE2-115 | Audio jack | M9K | Reference (docs_de2115/) |
| **3.0** | **Spartan-3E** | **PC UART** | **PC streams** | **Current ✅** |

### Why Version 3.0?

**Vs. Version 1.0** (BRAM):
- ✅ More flexible (unlimited waveforms)
- ✅ Simpler (no BRAM init)
- ✅ Faster development (change data without reprogram)

**Vs. Version 2.0** (Two boards):
- ✅ Simpler (one board)
- ✅ Familiar platform (you know Spartan-3E)
- ✅ No audio complexity
- ✅ Single-board SoC (simulation + CNN together)

---

## Fallback Plan (Option B)

### If VGA Proves Difficult

**Switch to PC Display**:
1. Modify Python to add matplotlib display (~1 day)
2. Add UART TX to FPGA for CNN results (~1 day)
3. Display everything on PC screen

**Files to modify**:
- Python: Add matplotlib/tkinter GUI
- FPGA: Add uart_transmitter.vhd
- Top-level: Wire UART TX

**Time to switch**: 2-3 days

**Keep as contingency!**

---

## Next Steps

### Immediate (Today/Tomorrow)
1. Read system_architecture.md (design overview)
2. Read technical_reference.md (UART & VGA specs)
3. Review implementation_roadmap.md (week-by-week plan)

### Week 1 (Start of COE 70B)
1. Create ISE project (ecg_simulation_uart)
2. Implement uart_receiver.vhd
3. Test UART with Python
4. Verify reception with LEDs

### Week 2-8
Follow implementation_roadmap.md week-by-week

---

## Team Integration

### With Ayoub (CNN Module)
- **Week 5**: Define CNN interface signals
- **Week 6**: Integrate CNN module into ISE project
- **Week 6**: Test classification
- **Internal FPGA signals** - no external wiring needed!

### With Malcolm/Pierre (SoC Team)
- May share lab resources
- Coordinate testing time

---

## Resources

### Tools Required
- Xilinx ISE Design Suite 14.7
- Python 3.7+
- Text editor / IDE
- Git (version control)

### Hardware Required
- Spartan-3E board with USB-UART
- VGA monitor
- USB cable
- PC (Windows/Linux/Mac)

### Documentation
- This folder (docs_uart/)
- Original design (docs/ - for VGA reference)
- Xilinx ISE tutorials
- UART protocol specs

---

## Contact

**Team Members**:
- **Marly**: Simulation Component (UART + VGA)
- **Ayoub**: CNN Classifier (on same FPGA)
- **Malcolm/Pierre**: SoC team

**Integration Points**:
- Week 5: CNN interface specification
- Week 6: Physical integration testing

---

**Version**: 3.0 (PC-UART Streaming)  
**Status**: Ready to Implement  
**Next**: Start Week 1 - Build UART Receiver  
**Platform**: Spartan-3E + PC (Option A)
