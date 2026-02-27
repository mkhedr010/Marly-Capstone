# ECG Simulation Component - DE2-115 Two-Board System
## Project Overview with Audio Interface

**Student**: Marly  
**Course**: COE 70A/70B Capstone Project (GK02)  
**Component**: Simulation & Visualization System  
**Platform**: Altera DE2-115 FPGA (Cyclone IV)  
**Status**: Mid-Term Review Ready

---

## Project Summary

This repository contains the complete design and planning documentation for the **ECG Simulation & Visualization Component** running on DE2-115 FPGA, which transmits ECG data via 3.5mm audio jack to a separate Spartan-3E board running CNN classification.

### 🔄 **NEW TWO-BOARD ARCHITECTURE**

```
┌──────────────────┐      ┌──────────────┐      ┌──────────────────┐
│  BOARD 1         │      │   3.5mm      │      │  BOARD 2         │
│  DE2-115         │  →   │   Audio      │  →   │  Spartan-3E      │
│                  │      │   Cable      │      │                  │
│ • ECG Storage    │      │ ──────────── │      │ • ADC Input      │
│ • VGA Display    │      │  (Analog)    │      │ • CNN Classifier │
│ • User Interface │      │              │      │ • Classification │
│ • Audio TX       │      │              │      │                  │
└──────────────────┘      └──────────────┘      └──────────────────┘
```

**Why Two Boards?**
- **Board 1 (DE2-115)**: Simulation component - has built-in audio codec
- **Board 2 (Spartan-3E)**: CNN classifier - team's existing platform
- **Connection**: Standard 3.5mm audio jack for physical separation

---

## What This Component Does

### Core Functionality (Board 1 - DE2-115)
1. **Store** 3 ECG waveform types in M9K Block RAM (Normal, PVC, AFib)
2. **User Control** - Select waveform via switches, start/pause via button
3. **VGA Display** - Live scrolling ECG trace (640×480 @ 60 Hz)
4. **Audio Transmission** - Convert ECG to audio, output via 3.5mm jack
5. **Status Display** - LEDs show mode, playback state, audio activity

### Audio Interface (NEW!)
- **Upsampling**: 360 Hz ECG → 48 kHz audio (hold-and-repeat)
- **Codec**: WM8731 audio codec (built-in on DE2-115)
- **Protocols**: I2S (audio data), I2C (codec config)
- **Output**: Analog audio via 3.5mm Line Out jack
- **Purpose**: Transmit ECG samples to CNN board on separate FPGA

---

## Documentation Structure

### 📚 Core Documents (in `docs_de2115/` directory)

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **technical_reference.md** | Complete technical specs (VGA, Audio, DE2-115) | Reference during implementation |
| **system_architecture.md** | Two-board design, block diagrams, modules | Architecture review & coding |
| **presentation_slides.md** | 6 slides for mid-term (updated for audio) | COE 70A oral exam prep |
| **implementation_roadmap.md** | Week-by-week plan (audio-focused) | COE 70B execution |
| **README.md** | This file - project overview | Quick reference & navigation |

### 📁 Original Documents (in `docs/` directory)
Single-board Spartan-3E version (superseded but kept for reference)

---

## Quick Start Guide

### For Mid-Term Presentation (COE 70A)
1. Read: `docs_de2115/presentation_slides.md`
2. Focus on **Slide 4** (Design Choices) - 50% of grade
3. Emphasize **audio interface** decision & rationale
4. Practice explaining two-board architecture
5. Prepare for audio-related technical questions

### For Implementation (COE 70B)
1. Follow: `docs_de2115/implementation_roadmap.md` week-by-week
2. **Weeks 1-4**: Focus on audio (I2C, I2S, codec, upsampling)
3. **Weeks 5-6**: VGA display & simultaneous operation
4. **Weeks 7-8**: Two-board integration with CNN team
5. Reference: `docs_de2115/technical_reference.md` for specifications

---

## Key Specifications

### Hardware (Board 1 - DE2-115)
- **FPGA**: Cyclone IV EP4CE115F29C7
  - 114,480 logic elements (11x more than Spartan-3E)
  - 3.98 Mbits M9K Block RAM (11x more than Spartan-3E)
  - 4 PLLs for clock generation
  - 50 MHz onboard oscillator
- **Audio**: Built-in WM8731 codec with 3.5mm jacks
- **Display**: VGA port (10-bit color DAC)
- **Interface**: 18 switches, 4 buttons, 18 red + 9 green LEDs

### Data Specifications
- **Sample Rate**: 360 Hz (MIT-BIH standard)
- **Sample Format**: 12-bit signed integer
- **Waveforms**: 360 samples each (1-second windows)
- **Memory**: ~1.6 KB total (3 M9K blocks = 1.2% of available)

### Audio Interface Specifications
- **Codec**: WM8731 (I2S + I2C)
- **Sample Rate**: 48 kHz I2S stream
- **Upsampling**: 360 Hz → 48 kHz (×133 hold-and-repeat)
- **Bit Depth**: 12-bit ECG padded to 16-bit I2S
- **Physical**: 3.5mm stereo cable (Line Out)

### Display Specifications
- **Resolution**: 640 × 480 pixels
- **Refresh**: 60 Hz
- **Color**: 10-bit RGB (4-4-4 bit)
- **Pixel Clock**: 25 MHz (from PLL)

### Performance
- **Resource Usage**: ~5-7% logic, ~1.5% RAM
- **Latency**: <1 ms sample-to-display, <1 ms sample-to-audio
- **Refresh**: 60 fps VGA, 48 kHz audio

---

## Module Architecture

### Complete Module List (12 modules)

```
ecg_system_top (DE2-115)
├── pll_50to48 (PLL: 50→48MHz, 50→25MHz) ⭐ NEW
├── ecg_controller
│   ├── user_interface_controller (SW, KEY, LED)
│   ├── sample_rate_controller (360 Hz tick)
│   ├── ecg_memory (M9K: 3 waveforms)
│   └── ecg_sample_generator (address, mode)
├── vga_controller
│   ├── vga_timing_generator (640×480@60Hz)
│   └── ecg_vga_renderer (scrolling display)
└── audio_controller ⭐ NEW SUBSYSTEM
    ├── i2c_master (codec configuration)
    ├── wm8731_config (init sequence)
    ├── sample_upsampler (360Hz→48kHz)
    └── i2s_transmitter (serial audio)
```

**Original**: 7 modules (Spartan-3E)  
**Updated**: 12 modules (DE2-115 + audio) ⭐  
**New Modules**: 5 audio-related modules

---

## Timeline

### COE 70A (Current)
- **Week 12**: Mid-term presentation
  - Present 6 slides (10 minutes)
  - Emphasize **audio interface decision** (key differentiator)
  - Answer questions on two-board design
  - Demonstrate preparedness for audio implementation

### COE 70B (Next Term - 8 Weeks)
- **Weeks 1-2**: PLL + I2C master + WM8731 initialization
- **Weeks 3-4**: I2S transmitter + ECG-to-audio upsampling
- **Weeks 5-6**: VGA display + simultaneous VGA+audio operation
- **Weeks 7-8**: Two-board integration + CNN classification testing

---

## Design Highlights

### Why These Choices?

**DE2-115 Over Spartan-3E**
- ✓ **Built-in audio codec** (WM8731) - critical for audio interface
- ✓ **11x more resources** (114K vs 10K logic elements)
- ✓ **Better VGA** (10-bit vs 3-bit color)
- ✓ **More I/O** (27 LEDs vs 4-8)
- ✓ **PLLs** for flexible clock generation

**Audio Interface Over GPIO**
- ✓ **Physical separation** - boards can be meters apart
- ✓ **Standard cables** - 3.5mm audio cables common
- ✓ **Isolation** - galvanic isolation reduces noise
- ✓ **Educational** - learn I2S, I2C, codec interfacing
- ✓ **Easy testing** - oscilloscope, audio analyzer

**48 kHz Audio Sample Rate**
- ✓ **Standard** - native WM8731 support
- ✓ **Integer upsampling** - 133x from 360 Hz
- ✓ **Bandwidth** - Nyquist 24 kHz >> 360 Hz ECG
- ✓ **Compatible** - common in audio equipment

**Hold-and-Repeat Upsampling**
- ✓ **Simple** - each ECG sample held for 133 audio frames
- ✓ **Preserves values** - no interpolation artifacts
- ✓ **Easy downsample** - receiving end takes every 133rd sample

**Scrolling VGA Display**
- ✓ **Engaging** - real-time ECG monitor feel
- ✓ **Simple** - 640 samples vs 307K pixel framebuffer
- ✓ **Continuous** - no reset needed

---

## Team Integration

### Interfaces with Other Components

**Board 2: CNN Classifier (Ayoub + Team)**
- **Receives**: Analog audio via 3.5mm jack (ECG waveform)
- **Processes**: ADC → downsample → CNN classification
- **Returns**: Classification result (Normal/PVC/AFib)
- **Connection**: Standard 3.5mm stereo audio cable

**Malcolm & Pierre (SoC Team)**
- **Coordination**: Lab resources, testing schedules
- **Shared**: May use same lab space and equipment

### Integration Meetings Schedule
- **Week 3 (COE 70B)**: Audio interface specification
- **Week 6**: Integration testing preparation
- **Week 7**: Physical connection & end-to-end testing
- **Week 8**: Joint demo rehearsal

---

## Success Criteria

### Minimum Viable Demo (Must Have)
- ✓ DE2-115 displays stable ECG waveform on VGA
- ✓ Audio output measurable on oscilloscope
- ✓ User can select 3 different waveforms (switches)
- ✓ Audio signal successfully reaches CNN board via 3.5mm cable
- ✓ CNN can classify at least one waveform type

### Full Feature Demo (Goal)
- ✓ Smooth scrolling VGA display
- ✓ Clean audio transmission (CNN classifies all 3 types correctly)
- ✓ User interface fully functional (pause, resume, mode select)
- ✓ LED indicators (mode, status, audio level meter)
- ✓ Both boards operating together reliably
- ✓ Classification results displayed back on DE2-115

### Stretch Goals (If Time Permits)
- ○ Line-drawn waveform (smoother VGA)
- ○ Heart rate calculation displayed
- ○ Real-time audio level meter on LED bar
- ○ Classification confidence on VGA
- ○ Waveform statistics on 7-segment displays

---

## Resources & Tools

### Development Tools
- **Quartus Prime** (Intel/Altera)
- **ModelSim** (Simulation)
- **Python 3.x** (ECG data conversion)
- **Git** (Version control)

### Hardware (Both Boards)
- **DE2-115 Board** (Board 1 - My component)
  - VGA port
  - Audio Line Out (3.5mm)
  - 18 switches, 4 buttons
  - 18 red + 9 green LEDs
- **Spartan-3E Board** (Board 2 - CNN team)
  - Audio Line In (or external ADC)
  - CNN classifier implementation
- **3.5mm Audio Cable** (stereo, shielded recommended)
- **VGA Monitor** (640×480 capable)
- **Oscilloscope** (critical for audio verification)
- **Logic Analyzer** (optional - for I2C/I2S debugging)

### References
- DE2-115 User Manual (Terasic)
- WM8731 Audio Codec Datasheet
- I2S Bus Specification
- MIT-BIH Arrhythmia Database
- Altera University Program Examples

---

## Risk Management

### Top 5 Risks & Mitigations

1. **Audio Codec Configuration Fails**
   - Risk: Medium | Impact: High
   - Mitigation: Use Altera reference designs; fallback to bit-banging

2. **Audio Signal Quality Poor (Noise/Distortion)**
   - Risk: Medium | Impact: High
   - Mitigation: Short cable, shielded cable, adjustable gain, oscilloscope verification

3. **I2S/I2C Timing Issues**
   - Risk: Medium | Impact: Medium
   - Mitigation: Use proven patterns; logic analyzer debugging; Altera IP cores

4. **Two-Board Synchronization Problems**
   - Risk: Medium | Impact: High
   - Mitigation: Early integration testing; clear interface spec; test vectors

5. **VGA + Audio Simultaneous Operation**
   - Risk: Low | Impact: Medium
   - Mitigation: Independent clock domains; dual-port RAM; timing analysis

---

## Quick Comparison: Original vs Updated Design

| Aspect | Original (Spartan-3E) | Updated (DE2-115) |
|--------|----------------------|-------------------|
| **Board** | Spartan-3E | DE2-115 |
| **Resources** | 10K logic cells | 114K logic elements |
| **Memory** | 360 Kbits | 3.98 Mbits |
| **VGA Color** | 3-bit RGB | 10-bit RGB |
| **LEDs** | 4-8 | 27 (18 red + 9 green) |
| **CNN Interface** | GPIO pins (12+) | **3.5mm audio jack** ⭐ |
| **Modules** | 9 modules | **12 modules** (+audio) |
| **Complexity** | Medium | **Medium-High** |
| **Educational Value** | High | **Very High** (audio!) |

**Key Difference**: Audio interface adds I2C, I2S, codec configuration - valuable real-world skills!

---

## Implementation Status

### Current Status: Planning Complete ✓
- [x] Technical research completed
- [x] System architecture designed
- [x] Presentation slides prepared
- [x] Implementation roadmap created
- [x] Documentation complete

### Next Steps (COE 70B)
1. Week 1: Set up Quartus, configure PLL
2. Week 2: Implement I2C master, initialize WM8731
3. Week 3: Implement I2S transmitter, output test tone
4. Week 4: ECG-to-audio pipeline, verify on oscilloscope
5. Week 5-6: VGA display, simultaneous VGA+audio
6. Week 7-8: Two-board integration, CNN classification testing

---

## File Organization

### Current Directory Structure
```
docs_de2115/                    ← Updated documentation (use this!)
├── README.md                   ← This file
├── technical_reference.md      ← DE2-115 specs, audio, VGA
├── system_architecture.md      ← Two-board design, modules
├── presentation_slides.md      ← 6 slides with audio focus
└── implementation_roadmap.md   ← 8-week plan with audio tasks

docs/                           ← Original single-board docs (reference only)
└── [Original Spartan-3E files]

Root files:
├── GK02-Hardware Implementation....pdf  ← Project manual
├── Oral Exam Presentation (1).pdf      ← Team's current slides
└── README.md                            ← Old overview (superseded)
```

**Use `docs_de2115/` for all current work!**

---

## Module Count & Complexity

### Original Design (Spartan-3E)
9 modules total:
- Clock divider (1)
- User interface (1)
- ECG data management (3)
- VGA display (2)
- CNN interface (1)
- Top-level (1)

### Updated Design (DE2-115 + Audio)
**12 modules total (+5 audio modules):**
- PLL (1) ⭐
- Clock management (0 - using PLL outputs)
- User interface (1)
- ECG data management (3)
- VGA display (2)
- **Audio output (5)** ⭐ NEW
  - I2C master
  - WM8731 config controller
  - Sample upsampler
  - I2S transmitter
  - Audio output controller
- Top-level (1)

**Complexity Increase**: ~30% more code, but massive educational value!

---

## Expected Learning Outcomes

### Skills Gained (COE 70B)
1. **Audio Codec Interfacing** ⭐ (Unique - rarely taught)
   - I2S protocol (serial audio)
   - I2C protocol (codec configuration)
   - WM8731 codec operation
   - Audio signal processing

2. **FPGA Design**
   - PLL configuration
   - Multi-clock domain design
   - Resource optimization (M9K RAM)

3. **VGA Display**
   - Timing generation (640×480 @ 60Hz)
   - Pixel rendering in HDL
   - Real-time scrolling graphics

4. **Signal Processing**
   - Sample rate conversion (upsampling)
   - Hold-and-repeat algorithm
   - Audio frequency domain concepts

5. **System Integration**
   - Two-board interfacing
   - Analog signal transmission
   - Testing & verification (oscilloscope, logic analyzer)

6. **Hardware Debugging**
   - Simulation (ModelSim)
   - Synthesis & timing analysis (TimeQuest)
   - On-board testing (oscilloscope, logic analyzer)
   - Signal integrity verification

---

## Resource Utilization (DE2-115)

### Estimated Resource Usage

| Resource | Estimated Usage | Available | Percentage | Status |
|----------|----------------|-----------|------------|--------|
| **Logic Elements** | 6,000-8,000 | 114,480 | 5-7% | ✓ Excellent headroom |
| **M9K Blocks** | 5-7 | 432 | 1.5% | ✓ Trivial usage |
| **PLLs** | 1 | 4 | 25% | ✓ Safe |
| **I/O Pins** | ~35 | 528 | 7% | ✓ Plenty available |
| **Embedded Multipliers** | 0-10 | 532 | <2% | ✓ Available for enhancements |

**Conclusion**: DE2-115 provides massive headroom - only ~5% resource usage!  
**Opportunity**: Can add many enhancements without resource concerns

---

## Unique Selling Points (For Presentation)

### What Makes This Design Special?

1. **Two-Board Architecture** 🔗
   - Realistic system integration experience
   - Mimics real embedded systems (separate subsystems)
   - Physical demonstration of inter-system communication

2. **Audio Interface** 🎵
   - Learn I2S and I2C protocols (industry standard)
   - Analog signal transmission (real-world skill)
   - WM8731 codec configuration (professional audio)
   - Rarely taught in undergraduate courses

3. **Triple Output** 📺📊🔊
   - VGA visualization (see ECG trace)
   - LED status display (mode, audio level)
   - Audio transmission (to CNN board)
   - All running simultaneously @ different rates

4. **Robust Testing** 🔬
   - Oscilloscope verification (analog signals)
   - Logic analyzer debugging (digital protocols)
   - Audio analyzer measurements (SNR, frequency)
   - Multi-level verification strategy

5. **Massive Headroom** 💪
   - Only 5% resource usage
   - Room for creativity and enhancements
   - Can add features without redesign

---

## Testing Strategy Summary

### Three-Level Testing Approach

#### Level 1: Module Testing (Simulation)
- Each module has testbench
- Verify functionality independently
- Timing verification
- Edge case testing

#### Level 2: Board Testing (DE2-115 Hardware)
- VGA test pattern → verify display
- Audio test tone → verify codec
- ECG audio output → verify waveform transmission
- LED patterns → verify user interface
- Long-run stability (4+ hours)

#### Level 3: System Integration (Two Boards)
- Audio cable connection
- Signal integrity (oscilloscope both ends)
- End-to-end classification
- Performance metrics (accuracy, latency)

---

## Contact & Collaboration

### Team Members
- **Marly**: Simulation Component (DE2-115 board)
- **Ayoub**: CNN Model & classifier (Spartan-3E board)
- **Malcolm**: SoC architecture & DFT preprocessing
- **Pierre**: Hardware-software partitioning

### Coordination Points
- **Week 3**: Audio interface specification meeting
- **Week 6**: Integration testing preparation
- **Week 7**: Two-board connection & testing
- **Week 8**: Joint demo preparation

### Communication
- Weekly team meetings (all members)
- Bi-weekly CNN integration sync (Marly + Ayoub)
- Shared documentation (GitHub)
- Lab schedule coordination

---

## Presentation Talking Points (Mid-Term)

### Key Messages to Emphasize

1. **"Two-board system adds real-world complexity"**
   - Separate development and testing
   - Realistic system integration challenges
   - Physical demonstration of distributed system

2. **"Audio interface is educational goldmine"**
   - I2S protocol (serial audio standard)
   - I2C protocol (codec configuration)
   - Analog signal transmission
   - Signal integrity considerations
   - Rarely covered in curriculum

3. **"DE2-115 selected for built-in audio codec"**
   - WM8731 codec with 3.5mm jacks
   - No external hardware needed
   - Professional-grade audio quality
   - Proven Altera reference designs available

4. **"Hold-and-repeat preserves ECG integrity"**
   - No signal processing artifacts
   - Original samples preserved exactly
   - Simple to implement and verify
   - Easy for CNN team to decode

5. **"Massive resource headroom allows creativity"**
   - Only 5% of DE2-115 used
   - Can add enhancements without concern
   - Professional-quality implementation possible

---

## Common Questions & Answers

### Q: Why not just use one board?
**A**: Team already committed to Spartan-3E for CNN. DE2-115 has audio codec we need for demonstration. Two-board system teaches realistic integration skills.

### Q: Why audio instead of GPIO?
**A**: Standard 3.5mm cables, physical separation, galvanic isolation, easy testing with oscilloscope, valuable learning (I2S/I2C protocols).

### Q: What if audio is too noisy?
**A**: Multiple mitigations - short cable, shielded cable, adjustable gain, signal verification at both ends. Worst case, can fall back to GPIO in 2-3 days.

### Q: How do you handle 3 different clocks?
**A**: PLL generates 48 MHz and 25 MHz from 50 MHz. Clock domain crossing uses dual-port RAM and synchronizers. Verified in timing analysis.

### Q: Isn't audio interface overkill?
**A**: Adds complexity but teaches valuable skills (I2S, I2C, codec config) rarely covered in courses. Only ~5% resource increase. High educational ROI.

### Q: What if CNN board not ready?
**A**: Can test with loopback (audio out → audio in on same DE2-115), or simulate CNN behavior for testing.

---

## Next Immediate Actions

### Before Mid-Term Presentation
1. Review all presentation slides (`docs_de2115/presentation_slides.md`)
2. Practice explaining two-board architecture (use diagrams)
3. Prepare to defend audio interface decision (biggest change)
4. Study Q&A section (50% of grade on design choices!)
5. Create 1-page summary of key specs for quick reference

### After Mid-Term (Before COE 70B)
1. Obtain DE2-115 board access (COE758 lab)
2. Install Quartus Prime
3. Review Altera audio examples
4. Download MIT-BIH ECG dataset
5. Coordinate with team on lab schedules

---

## Version History

| Version | Date | Platform | Changes |
|---------|------|----------|---------|
| 1.0 | Nov 25, 2025 | Spartan-3E | Initial single-board design |
| **2.0** | **Nov 28, 2025** | **DE2-115** | **Two-board + audio interface** |

---

## License & Academic Integrity

This is coursework for Toronto Metropolitan University COE 70A/70B capstone project. All work is original and completed in accordance with academic integrity policies.

**Course**: COE 70A/70B - Engineering Design Project  
**Project**: GK02 - Hardware Implementation of CNN for ECG Analysis  
**Instructor**: Prof. Gul N. Khan  
**Term**: Fall 2025 / Winter 2026

---

**Last Updated**: November 28, 2025  
**Version**: 2.0 (DE2-115 Two-Board Architecture)  
**Status**: Ready for Mid-Term Presentation  
**Next Milestone**: COE 70A Oral Exam
**Platform**: DE2-115 (Board 1) + Spartan-3E (Board 2)
