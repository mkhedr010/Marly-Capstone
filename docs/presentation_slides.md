# ECG Simulation Component - Mid-Term Presentation
## Marly's 6 Slides for COE 70A Oral Exam

**Presentation Duration**: 10 minutes  
**Assessment Focus**: Problem Definition (20%), Design Choices (50%), COE 70B Preparedness (15%)

---

## SLIDE 1: Problem Definition & Component Role

### **ECG Simulation & Visualization Component**

#### **The Challenge**
- CNN-based ECG classifier needs **real ECG data input** for testing and demonstration
- Without visualization, demo is just "FPGA sitting on table" - **not captivating**
- Need interactive way to **feed test data** and **display results visually**

#### **My Solution: FPGA-Based Simulation System**
```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   Store 3   │  →   │    User     │  →   │   Display   │
│ ECG Signals │      │  Selects    │      │   on VGA    │
│  in Memory  │      │  Waveform   │      │   + Feed    │
│             │      │ (Switches)  │      │     CNN     │
└─────────────┘      └─────────────┘      └─────────────┘
```

#### **Why FPGA Implementation?**
✓ Learn VGA output in HDL (valuable skill)  
✓ Learn digital signal processing in hardware  
✓ Integrated with team's SoC design  
✓ Real-time performance demonstration  
✓ Standalone testing capability  

#### **Key Deliverables**
1. Store Normal, PVC, AFib ECG waveforms
2. User interface (switches/buttons/LEDs)
3. VGA display showing live ECG trace
4. Digital stream feeding CNN module
5. Classification result display

---

## SLIDE 2: Requirements & System Specifications

### **Technical Requirements**

#### **Hardware Platform**
- **FPGA**: Xilinx Spartan-3E XC3S500E
  - 10,476 logic cells
  - 360 Kbits Block RAM
  - 50 MHz onboard clock
- **Available**: COE758 Lab (Engineering Building)

#### **ECG Data Specifications**
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Sample Rate | 360 Hz | MIT-BIH dataset standard |
| Samples/Beat | 360 samples | 1-second window |
| Bit Depth | 12-bit signed | ADC precision + CNN compatibility |
| Waveforms | 3 types | Normal, PVC, AFib |
| Total Memory | ~1.6 KB | Fits in 2-3 BRAM blocks |

#### **Display Specifications**
| Parameter | Value |
|-----------|-------|
| Resolution | 640 × 480 pixels |
| Refresh Rate | 60 Hz |
| Color Mode | RGB (3-3-2 bit) |
| Pixel Clock | 25 MHz (from 50 MHz ÷2) |

#### **User Interface**
- **Inputs**: 2 switches (waveform select), 1 button (start/pause)
- **Outputs**: 4 LEDs (mode + status), VGA display, 12-bit digital stream

#### **CNN Interface** (Integration with Ayoub's Module)
- **Output**: 12-bit ECG sample @ 360 Hz
- **Signals**: `ecg_sample[11:0]`, `sample_tick`, `sample_valid`
- **Protocol**: Simple streaming (no backpressure)

---

## SLIDE 3: System Architecture

### **High-Level Block Diagram**

```
┌─────────────────────────────────────────────────────────┐
│           ECG SIMULATION COMPONENT (Spartan-3E)         │
│                                                         │
│  ┌───────────────────┐         ┌──────────────────┐    │
│  │  USER INTERFACE   │         │   CLOCK MANAGER  │    │
│  │  • SW[1:0]        │         │   50 MHz → 25MHz │    │
│  │  • BTN[0]         │         └──────────────────┘    │
│  │  • LED[3:0]       │                                  │
│  └────────┬──────────┘                                  │
│           │                                             │
│           ▼                                             │
│  ┌────────────────────────────────────┐                │
│  │     ECG DATA MANAGEMENT            │                │
│  │  ┌──────────────────────────────┐  │                │
│  │  │  ECG MEMORY (Block RAM)      │  │                │
│  │  │  • Normal:  360×12-bit       │  │                │
│  │  │  • PVC:     360×12-bit       │  │                │
│  │  │  • AFib:    360×12-bit       │  │                │
│  │  └──────────┬───────────────────┘  │                │
│  │             │                      │                │
│  │  ┌──────────▼───────────────────┐  │                │
│  │  │  Sample Generator @ 360 Hz   │  │                │
│  │  │  • Clock Divider: ÷138,889   │  │                │
│  │  │  • Address Counter (0-359)   │  │                │
│  │  └──────────┬───────────────────┘  │                │
│  └─────────────┼──────────────────────┘                │
│                │                                        │
│                ├─────────────┬──────────────────┐       │
│                │             │                  │       │
│         ┌──────▼──────┐  ┌──▼──────────┐  ┌────▼────┐  │
│         │    VGA      │  │  Waveform   │  │   CNN   │  │
│         │   Timing    │  │   Buffer    │  │Interface│  │
│         │  Generator  │  │ (640 samp.) │  │         │  │
│         └──────┬──────┘  └──────┬──────┘  └────┬────┘  │
│                │                │               │       │
│                ▼                ▼               │       │
│         ┌─────────────────────────┐             │       │
│         │   ECG VGA Renderer      │             │       │
│         │   • Y-Mapping           │             │       │
│         │   • Scrolling Display   │             │       │
│         └──────┬──────────────────┘             │       │
│                │                                │       │
└────────────────┼────────────────────────────────┼───────┘
                 │                                │
                 ▼                                ▼
          VGA Monitor                        CNN Module
       (640×480 @ 60Hz)                    (Classification)
```

### **Data Flow: User → Memory → Display + CNN**

1. User selects waveform (switches) → Mode controller
2. Sample generator reads from BRAM @ 360 Hz
3. Sample streams to **both** VGA renderer and CNN interface
4. VGA displays scrolling waveform in real-time (60 fps)
5. CNN receives samples and returns classification result
6. LEDs show: selected mode + playback status + CNN result

---

## SLIDE 4: Design Choices, Analysis & Decisions

### **Critical Design Decisions**

#### **1. Memory Architecture: Block RAM vs. Distributed RAM**

| Choice | Block RAM (Inferred) |
|--------|---------------------|
| **Capacity** | 3 × 360 samples × 12-bit = 12,960 bits |
| **Resource Used** | 2-3 BRAM blocks (out of 20 available) |
| **Advantages** | ✓ Synchronous read (predictable timing)<br>✓ Dedicated resource (doesn't use logic cells)<br>✓ Easy to initialize with ECG data |
| **Implementation** | VHDL array with initialization |

**Analysis**: Block RAM is optimal - plenty available, fast access, simple initialization

---

#### **2. Sample Rate Generation: 360 Hz from 50 MHz**

**Clock Divider Calculation**:
```
Divider = 50,000,000 Hz / 360 Hz = 138,889
Actual Rate = 50,000,000 / 138,889 = 359.998 Hz ✓
Error: 0.0006% (negligible)
```

**Design Pattern**: Counter-based divider
- Counts 0 to 138,888
- Generates 1-cycle pulse when counter = 0
- Enable control for start/pause functionality

**Why 360 Hz?**
- Matches MIT-BIH dataset native sampling rate
- Sufficient for ECG (Nyquist: need 180 Hz for 90 Hz max ECG frequency)
- Easy to generate precisely from 50 MHz

---

#### **3. VGA Display Strategy: Scrolling vs. Static**

| Choice | **Scrolling Display** |
|--------|---------------------|
| **Buffer Size** | 640 samples (1 per pixel) |
| **Update Rate** | 1 new sample every 2.78 ms |
| **Display Rate** | 60 fps (16.68 ms/frame) |

**Advantages**:
✓ Real-time "ECG monitor" feel - more engaging  
✓ Simpler rendering (no full-screen framebuffer needed)  
✓ Only 640 samples in buffer vs. 307,200 pixels  
✓ Continuous demonstration without reset  

**Y-Coordinate Mapping**:
```vhdl
y_position = 240 - (ecg_sample / 10)
```
- Centers waveform at Y=240 (middle of 480 pixels)
- Scale factor of 10 fits full 12-bit range in ±200 pixels
- Signed arithmetic handles negative ECG deflections

---

#### **4. CNN Integration Interface: Streaming vs. Handshake**

| Approach | Simple Streaming (Chosen) |
|----------|-------------------------|
| **Signals** | • `ecg_sample[11:0]`<br>• `sample_tick` (360 Hz pulse)<br>• `sample_valid` |
| **Protocol** | Fixed-rate stream, no backpressure |

**Rationale**:
- CNN processes faster than 360 Hz input (no stalling risk)
- Simple synchronous design
- Matches real ECG data acquisition behavior
- Easy to debug and verify
- Compatible with team's CNN module design

**Alternative Considered**: Ready/Valid handshake → Rejected (unnecessary complexity)

---

#### **5. User Interface: Minimal but Functional**

**Inputs**:
- `SW[1:0]`: Waveform select (00=Normal, 01=PVC, 10=AFib)
- `BTN[0]`: Start/Pause toggle (with 50ms debouncing)

**Outputs**:
- `LED[1:0]`: Current mode (mirrors switches)
- `LED[2]`: Playback status (1=running, 0=paused)
- `LED[3]`: CNN classification result (optional)

**Design Choice**: Direct mapping + debouncing
- No complex menu system needed
- Instant visual feedback
- Supports hands-on demonstration

---

### **Resource Utilization Analysis**

| Resource | Estimated | Available | % Used | Status |
|----------|-----------|-----------|--------|--------|
| Logic Cells | ~2,000 | 10,476 | 19% | ✓ Safe |
| BRAM (18Kb) | 4-5 | 20 | 22% | ✓ Safe |
| I/O Pins | ~25 | 232 | 11% | ✓ Safe |

**Conclusion**: Design fits comfortably within Spartan-3E resources

---

## SLIDE 5: Technical Challenges & Solutions

### **Challenge 1: Multiple Clock Domains**

**Problem**: 
- System Clock: 50 MHz (sample generation, BRAM)
- Pixel Clock: 25 MHz (VGA display)
- Need to safely transfer ECG samples between domains

**Solution**: Waveform Buffer with Dual-Port RAM
```
Clock Domain A (50 MHz):     Clock Domain B (25 MHz):
┌─────────────────┐          ┌─────────────────┐
│ Write ECG       │          │ Read for VGA    │
│ samples @ 360Hz │  →  RAM  →  │ display @ 25MHz │
└─────────────────┘          └─────────────────┘
```
- Write port: System clock (sample updates)
- Read port: Pixel clock (VGA rendering)
- No handshaking needed (buffer size >> update rate)

---

### **Challenge 2: VGA Timing Precision**

**Problem**: VGA requires strict timing adherence
- Hsync/Vsync must be exact
- Pixel clock must be stable
- Any jitter causes display artifacts

**Solution**: Proven VGA Timing Generator
```vhdl
-- Hardcoded constants (640×480 @ 60Hz)
H_TOTAL = 800, V_TOTAL = 525
H_SYNC: 96 cycles, V_SYNC: 2 lines
Sync polarity: Negative
```
- Counter-based implementation (no complex logic)
- Verified timing values from VESA standard
- Test with color bars before ECG rendering

**Fallback**: If timing issues persist, use DCM for exact 25.175 MHz

---

### **Challenge 3: ECG Data Initialization**

**Problem**: Need real ECG waveform data in BRAM at startup
- Must convert from MIT-BIH dataset (floating point)
- Must match 12-bit signed integer format
- Must initialize BRAM correctly for synthesis

**Solution**: Python conversion script + VHDL array
```python
# Convert normalized ECG to 12-bit signed
def convert_to_12bit(value):
    int_val = int(value * 2047)  # Scale to ±2047
    int_val = max(-2048, min(2047, int_val))  # Clip
    return int_val & 0xFFF  # 12-bit mask
```

VHDL initialization:
```vhdl
constant NORMAL_ECG : ecg_rom_type := (
    x"000", x"012", x"025", ..., x"FFF"
);
```

**Verification**: Compare BRAM readback with expected values in testbench

---

### **Challenge 4: Real-Time Scrolling Without Flicker**

**Problem**: 
- New sample arrives every 2.78 ms
- VGA refreshes every 16.68 ms (60 Hz)
- Need smooth scrolling without tearing

**Solution**: Circular Buffer with Synchronized Updates
```
Buffer Index:    0   1   2   3   ... 638  639
                 ↑                          ↑
            Write Ptr                  (wraps to 0)

VGA reads entire buffer 60 times/sec
Write updates 1 position every 2.78 ms
```
- Write and read happen at different rates (no conflict)
- VGA always draws from stable buffer
- Natural scrolling as write pointer advances

**Alternative Considered**: Double buffering → Rejected (waste of BRAM)

---

### **Challenge 5: Integration with CNN Module**

**Problem**: 
- CNN module developed by different team member (Ayoub)
- Must agree on interface early
- Changes late in project are expensive

**Solution**: Early Interface Specification Document
- Defined signal names, widths, timing
- Documented sample_tick behavior (1-cycle pulse)
- Specified bit format (12-bit signed, two's complement)
- Created test vectors for cross-verification
- Reserved GPIO pins for connection

**Mitigation**: Keep interface layer modular (can adapt if CNN changes)

---

## SLIDE 6: Preparedness for COE 70B - Implementation Plan

### **Development Timeline (8-Week Implementation Phase)**

#### **Weeks 1-2: Foundation & Core Modules**
**Goals**: Basic building blocks working in simulation
- [ ] VHDL module skeletons (all 9 modules)
- [ ] ISE project setup with proper directory structure
- [ ] Clock divider (50→25 MHz) - **TEST**: Verify 25 MHz output
- [ ] Sample rate controller - **TEST**: Verify 360 Hz tick
- [ ] VGA timing generator - **TEST**: Verify hsync/vsync periods
- [ ] Create testbenches for each module

**Milestone**: All core timing modules simulated successfully

---

#### **Weeks 3-4: Data Path Implementation**
**Goals**: ECG data flowing through system
- [ ] ECG memory (BRAM) with sample data initialization
  - Convert 3 waveforms from MIT-BIH dataset
  - Create Python script for float→12bit conversion
- [ ] Sample generator module - **TEST**: Verify address sequencing
- [ ] CNN interface module - **TEST**: Check signal timing
- [ ] Integration testbench for data path

**Milestone**: ECG samples generated and verified in simulation

---

#### **Weeks 5-6: VGA Display & Rendering**
**Goals**: Visual output working on monitor
- [ ] Waveform buffer implementation (640×12-bit RAM)
- [ ] ECG VGA renderer (Y-mapping logic)
- [ ] **HARDWARE TEST 1**: Display color bar test pattern
- [ ] **HARDWARE TEST 2**: Display static waveform
- [ ] **HARDWARE TEST 3**: Display scrolling waveform

**Milestone**: ECG waveform visible on VGA monitor

---

#### **Weeks 7-8: Integration & Testing**
**Goals**: Complete system operational
- [ ] User interface controller (buttons, switches, LEDs)
- [ ] Button debouncing verification
- [ ] Top-level integration (connect all modules)
- [ ] Synthesis & place-and-route (verify resource usage)
- [ ] **HARDWARE TEST 4**: Full system on Spartan-3E
- [ ] **INTEGRATION TEST**: Connect to CNN module (Ayoub)
- [ ] Performance verification (sample rate, display quality)
- [ ] Documentation finalization

**Milestone**: Working demo ready for final presentation

---

### **Risk Management**

| Risk | Probability | Mitigation Strategy |
|------|-------------|-------------------|
| VGA timing issues | Medium | Use proven reference design; test early |
| BRAM synthesis problems | Low | Test both inferred & instantiated; fallback to distributed RAM |
| Clock domain crossing bugs | Medium | Dual-port RAM; thorough simulation; use ChipScope if needed |
| CNN interface mismatch | Medium | Early coordination with Ayoub; documented interface |
| Pin constraint errors | Low | Verify board pinout early; use lab resources |

---

### **Success Criteria**

**Minimum Viable Demo** (must-have):
✓ VGA displays stable 640×480 image  
✓ ECG waveform visible and recognizable  
✓ User can select different waveforms  
✓ Samples feed to CNN module correctly  

**Full Feature Demo** (goal):
✓ Smooth scrolling display  
✓ Playback start/pause control  
✓ LED status indicators working  
✓ CNN classification result displayed  
✓ System runs continuously without errors  

---

### **Resource Allocation**

**Lab Access**: COE758 Lab (Engineering Building)
- Spartan-3E board with VGA port
- Oscilloscope (for signal verification)
- VGA monitor

**Tools**: 
- ISE Design Suite (Xilinx)
- ModelSim/ISim (simulation)
- Python (data conversion)

**Team Coordination**:
- Weekly sync with Ayoub (CNN interface)
- Bi-weekly full team meeting
- Shared GitHub repository for integration

---

### **Learning Outcomes Expected**

By end of COE 70B, I will have hands-on experience with:
1. **FPGA Design**: Clock management, resource optimization
2. **VGA Display**: Timing generation, pixel rendering in HDL
3. **Memory Systems**: Block RAM usage, initialization, access patterns
4. **Digital Design**: Multi-clock domains, synchronization
5. **System Integration**: Module interfaces, testing strategies
6. **Hardware Debugging**: Simulation, synthesis, on-board testing

---

## PRESENTATION NOTES

### **Opening (30 seconds)**
"I'm responsible for the Simulation Component - the system that makes our CNN classifier demo interactive and visually engaging. Instead of just an FPGA sitting on a table, we'll have live ECG waveforms on screen that users can select and see classified in real-time."

### **Time Allocation**
- Slide 1 (Problem): 1.5 min
- Slide 2 (Requirements): 1.5 min  
- Slide 3 (Architecture): 2 min
- Slide 4 (Design Choices): 2.5 min  
- Slide 5 (Challenges): 1.5 min
- Slide 6 (Implementation Plan): 1 min

**Total**: ~10 minutes

### **Q&A Preparation**

**Expected Questions**:

**Q1 - Problem Definition (20 points)**
- *Why FPGA instead of software?* → Learning HDL skills, integrated with team's SoC
- *Why these specific waveforms?* → Normal vs abnormal heartbeats (clinical relevance)
- *How does this support overall project?* → Provides test data + demonstration capability

**Q2 - Design Choices (50 points)**
- *Why 360 Hz sample rate?* → MIT-BIH standard, sufficient for ECG spectrum
- *Why scrolling display?* → Real-time feel, simpler than full framebuffer
- *How did you size the buffer?* → 640 samples = 1 per pixel, ~1.8 sec of data
- *Why simple streaming interface?* → CNN faster than input, no stalling needed
- *BRAM vs distributed RAM?* → BRAM more efficient, dedicated resource

**Q4 - COE 70B Preparedness (15 points)**
- *What if VGA doesn't work?* → Test pattern first, proven reference design
- *What if timing issues?* → Extensive simulation, ChipScope debugging
- *How will you coordinate with team?* → Weekly meetings, documented interfaces
- *What's your biggest risk?* → Clock domain crossing - mitigated with dual-port RAM

---

**Document Version**: 1.0  
**Created**: November 25, 2025  
**Presentation Date**: COE 70A Mid-Term Review  
**Presenter**: Marly - Simulation Component Team
