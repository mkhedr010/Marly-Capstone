# ECG Simulation Component - Project Overview

**Student**: Marly  
**Course**: COE 70A/70B Capstone Project (GK02)  
**Component**: Simulation & Visualization System  
**Platform**: Xilinx Spartan-3E FPGA  
**Status**: Mid-Term Review Ready

---

## Project Summary

This repository contains the complete design and planning documentation for the **ECG Simulation & Visualization Component** of a CNN-based ECG classification SoC system.

### What This Component Does

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Store ECG    │ →  │ User Control │ →  │ VGA Display  │
│ Waveforms    │    │ (Select/Play)│    │ + CNN Feed   │
└──────────────┘    └──────────────┘    └──────────────┘
```

**Core Functionality**:
1. Store 3 ECG waveform types in FPGA memory (Normal, PVC, AFib)
2. User selects waveform via switches
3. Display live scrolling ECG trace on VGA monitor
4. Stream digital samples to CNN classifier @ 360 Hz
5. Show classification results via LEDs/display

---

## Documentation Structure

### 📚 Core Documents (in `docs/` directory)

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **technical_reference.md** | Complete technical knowledge base | Reference during implementation |
| **system_architecture.md** | Detailed design specs & diagrams | Architecture review & coding |
| **presentation_slides.md** | 6 slides for mid-term review | COE 70A oral exam prep |
| **implementation_roadmap.md** | Week-by-week implementation plan | COE 70B execution |

---

## Quick Start Guide

### For Mid-Term Presentation (COE 70A)
1. Read: `docs/presentation_slides.md`
2. Study Q&A preparation section
3. Practice 10-minute presentation
4. Review design decisions (50% of grade)

### For Implementation (COE 70B)
1. Follow: `docs/implementation_roadmap.md`
2. Reference: `docs/technical_reference.md` for specs
3. Use: `docs/system_architecture.md` for module details
4. Track: Weekly checkpoints in roadmap

---

## Key Specifications

### Hardware
- **FPGA**: Spartan-3E XC3S500E (10K logic cells, 360 Kbits BRAM)
- **Clock**: 50 MHz onboard oscillator
- **Display**: VGA 640×480 @ 60 Hz
- **Interface**: Switches, buttons, LEDs, GPIO to CNN

### Data
- **Sample Rate**: 360 Hz (MIT-BIH standard)
- **Sample Format**: 12-bit signed integer
- **Waveforms**: 360 samples each (1-second windows)
- **Memory**: ~1.6 KB total (fits in 2-3 BRAM blocks)

### Performance
- **Resource Usage**: <20% logic cells, ~22% BRAM
- **Latency**: <1 ms sample-to-display
- **Refresh**: 60 fps scrolling display

---

## Module Architecture

```
ecg_system_top
├── clk_divider (50MHz → 25MHz)
├── user_interface_controller
│   ├── button_debouncer
│   └── led_controller
├── ecg_controller
│   ├── sample_rate_controller (360 Hz)
│   ├── ecg_memory (BRAM)
│   └── ecg_sample_generator
├── vga_controller
│   ├── vga_timing_generator
│   └── ecg_vga_renderer
└── cnn_interface
```

**9 VHDL Modules Total**

---

## Timeline

### COE 70A (Current)
- **Week 12**: Mid-term presentation
  - Present 6 slides (10 minutes)
  - Answer questions on design choices
  - Demonstrate preparedness for COE 70B

### COE 70B (Next Term - 8 Weeks)
- **Weeks 1-2**: Clock management & VGA timing
- **Weeks 3-4**: ECG data & waveform rendering
- **Weeks 5-6**: User interface & CNN integration
- **Weeks 7-8**: Testing, optimization & demo

---

## Design Highlights

### Why These Choices?

**Block RAM Storage**
- ✓ Efficient (dedicated resource, doesn't use logic cells)
- ✓ Fast (synchronous reads in 1 cycle)
- ✓ Easy to initialize with ECG data

**Scrolling Display**
- ✓ Engaging "ECG monitor" feel
- ✓ Simple rendering (640 samples vs 307K pixels)
- ✓ Continuous demo (no reset needed)

**Simple Streaming Interface**
- ✓ CNN faster than 360 Hz (no backpressure)
- ✓ Matches real ECG acquisition
- ✓ Easy to debug and verify

**360 Hz Sample Rate**
- ✓ MIT-BIH dataset standard
- ✓ Sufficient bandwidth (Nyquist: 180 Hz)
- ✓ Precise generation from 50 MHz

---

## Team Integration

### Interfaces with Other Components

**Ayoub (CNN Module)**
- Receives: `ecg_sample[11:0]`, `sample_tick`, `sample_valid`
- Returns: `cnn_result[1:0]`, `cnn_valid`
- Connection: GPIO header pins

**Malcolm & Pierre (SoC Team)**
- Coordination: Pin assignments, lab resources
- Integration: May share FPGA board or test equipment

---

## Success Criteria

### Minimum Viable Demo (Must Have)
- ✓ VGA displays stable ECG waveform
- ✓ User can select 3 different waveforms
- ✓ Samples stream to CNN at 360 Hz
- ✓ System runs reliably

### Full Feature Demo (Goal)
- ✓ Smooth scrolling display
- ✓ Pause/resume control working
- ✓ LED status indicators accurate
- ✓ CNN classification integrated
- ✓ Continuous operation without errors

---

## Resources & Tools

### Development Tools
- **ISE Design Suite 14.7** (Xilinx)
- **ModelSim/ISim** (Simulation)
- **Python 3.x** (Data conversion)
- **Git** (Version control)

### Hardware
- **Spartan-3E Starter Kit** (COE758 Lab)
- **VGA Monitor** (640×480 capable)
- **Oscilloscope** (Signal verification)
- **GPIO Cables** (CNN connection)

### References
- MIT-BIH Arrhythmia Database (PhysioNet)
- Kaggle ECG Heartbeat Dataset
- VESA VGA Standard (640×480 @ 60Hz)
- Xilinx Spartan-3E Data Sheet

---

## Risk Management

### Top 5 Risks & Mitigations

1. **VGA Timing Issues**
   - Risk: Medium | Impact: High
   - Mitigation: Use proven reference design, test early

2. **Clock Domain Crossing**
   - Risk: Medium | Impact: Medium
   - Mitigation: Dual-port RAM, thorough simulation

3. **CNN Interface Mismatch**
   - Risk: Medium | Impact: High
   - Mitigation: Early coordination, documented interface

4. **BRAM Synthesis Problems**
   - Risk: Low | Impact: Medium
   - Mitigation: Test both inferred & instantiated

5. **Sample Rate Drift**
   - Risk: Low | Impact: Low
   - Mitigation: Precise divider, configurable generic

---

## Next Steps

### Immediate (This Week)
1. Review presentation slides
2. Practice 10-minute presentation
3. Prepare for Q&A (design choices worth 50%)
4. Get feedback from team

### After Mid-Term Review
1. Set up development environment
2. Create project directory structure
3. Initialize Git repository
4. Begin Week 1 tasks from roadmap

---

## Contact & Collaboration

### Team Members
- **Marly**: Simulation Component (this)
- **Ayoub**: CNN Model & Python implementation
- **Malcolm**: SoC architecture & DFT preprocessing
- **Pierre**: Hardware-software partitioning

### Weekly Meetings
- Full team sync: TBD
- CNN integration (Marly + Ayoub): Weekly from Week 3

---

## Document Versions

| Document | Version | Last Updated |
|----------|---------|--------------|
| technical_reference.md | 1.0 | Nov 25, 2025 |
| system_architecture.md | 1.0 | Nov 25, 2025 |
| presentation_slides.md | 1.0 | Nov 25, 2025 |
| implementation_roadmap.md | 1.0 | Nov 25, 2025 |
| README.md | 1.0 | Nov 25, 2025 |

---

## License & Academic Integrity

This is coursework for Toronto Metropolitan University COE 70A/70B capstone project. All work is original and completed in accordance with academic integrity policies.

**Course**: COE 70A/70B - Engineering Design Project  
**Project**: GK02 - Hardware Implementation of CNN for ECG Analysis  
**Instructor**: Prof. Gul N. Khan  
**Term**: Fall 2025 / Winter 2026

---

**Last Updated**: November 25, 2025  
**Status**: Ready for Mid-Term Presentation  
**Next Milestone**: COE 70A Oral Exam
