# ECG Simulation Component - Mid-Term Presentation
## Marly's 6 Slides for COE 70A Oral Exam (DE2-115 + Audio Interface)

**Presentation Duration**: 10 minutes  
**Assessment Focus**: Problem Definition (20%), Design Choices (50%), COE 70B Preparedness (15%)

---

## SLIDE 1: Problem Definition & Component Role

### **ECG Simulation & Visualization Component**

#### **The Challenge**
- CNN-based ECG classifier needs **real ECG data input** for testing and demonstration
- Without visualization, demo is just "FPGA sitting on table" - **not captivating**
- Need interactive way to **feed test data** and **display results visually**
- **NEW**: Two separate FPGA boards require reliable data transmission

#### **My Solution: Two-Board FPGA System with Audio Link**
```
┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│  BOARD 1 (DE2)   │      │  3.5mm Audio     │      │ BOARD 2 (S3E)    │
│                  │      │  Cable           │      │                  │
│ • Store 3 ECG    │  →   │ ──────────────── │  →   │ • ADC Input      │
│   Waveforms      │      │  (Analog Audio)  │      │ • CNN Classifier │
│ • VGA Display    │      │                  │      │ • Classification │
│ • User Interface │      │                  │      │                  │
└──────────────────┘      └──────────────────┘      └──────────────────┘
```

#### **Why TWO Boards + Audio Interface?**
✓ **Physical separation** - Independent development & testing  
✓ **Standard connection** - 3.5mm cables readily available  
✓ **Galvanic isolation** - Reduces electrical noise/interference  
✓ **Learn audio I/O in HDL** - Valuable skill (I2S, I2C protocols)  
✓ **Easy debugging** - Monitor signal with oscilloscope/audio analyzer  

#### **Key Deliverables (Board 1 - DE2-115)**
1. Store Normal, PVC, AFib ECG waveforms in memory
2. User interface (switches/buttons/LEDs)
3. VGA display showing live scrolling ECG trace
4. **Audio output via 3.5mm jack (WM8731 codec)**
5. Classification result display (from Board 2 feedback)

---

## SLIDE 2: Requirements & System Specifications

### **Technical Requirements**

#### **Hardware Platform - BOARD 1 (My Component)**
- **FPGA**: Altera DE2-115 (Cyclone IV EP4CE115)
  - 114,480 logic elements (**11x more than Spartan-3E!**)
  - 3.98 Mbits M9K Block RAM
  - 4 PLLs for flexible clock generation
  - 50 MHz onboard clock
  - **Built-in WM8731 audio codec with 3.5mm jacks**
- **Available**: COE758 Lab (Engineering Building)

#### **Hardware Platform - BOARD 2 (Team's CNN)**
- **FPGA**: Xilinx Spartan-3E
- **Function**: Receive audio, digitize, run CNN classifier
- **Interface**: 3.5mm audio input → ADC → CNN

#### **ECG Data Specifications**
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Sample Rate | 360 Hz | MIT-BIH dataset standard |
| Samples/Beat | 360 samples | 1-second window |
| Bit Depth | 12-bit signed | ADC precision + CNN compatibility |
| Waveforms | 3 types | Normal, PVC, AFib |
| Total Memory | ~1.6 KB | Fits in 3 M9K blocks (<1% of available) |

#### **Display Specifications**
| Parameter | Value |
|-----------|-------|
| Resolution | 640 × 480 pixels |
| Refresh Rate | 60 Hz |
| Color Mode | RGB (4-4-4 bit = 10-bit total) |
| Pixel Clock | 25 MHz (from PLL) |

#### **Audio Interface Specifications** ⭐ **NEW!**
| Parameter | Value | Purpose |
|-----------|-------|---------|
| Codec | WM8731 (on DE2-115) | Digital-to-Analog conversion |
| Protocol | I2S (Inter-IC Sound) | Serial audio data |
| Sample Rate | 48 kHz | Standard audio rate |
| Bit Depth | 16-bit (from 12-bit ECG) | I2S standard |
| Interface | I2C | Codec configuration |
| Physical | 3.5mm stereo cable | Board-to-board connection |

**ECG Transmission**: 360 Hz ECG → Upsample 133x → 48 kHz audio → Analog output

#### **User Interface (DE2-115 has many I/O!)**
- **Inputs**: SW[1:0] (waveform select), KEY[0] (start/pause)
- **Outputs**: 
  - 18 red LEDs (LEDR) - mode, status, audio level meter
  - 9 green LEDs (LEDG) - sample counter, heart rate
  - VGA display
  - 3.5mm audio output

---

## SLIDE 3: System Architecture (Two-Board Design)

### **High-Level Two-Board System**

```
╔═══════════════════════════════════════════════════════════════════╗
║                    BOARD 1: DE2-115 (Simulation)                  ║
╠═══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  USER INTERFACE          ECG DATA                VGA DISPLAY     ║
║  ┌───────────┐           ┌──────────┐           ┌──────────┐    ║
║  │ SW[1:0]   │──────────▶│ M9K RAM  │──────────▶│  Render  │    ║
║  │ KEY[0]    │           │ 3×360×12 │           │ 640×480  │    ║
║  │ LEDR[17:0]│◀──────┐   │ Samples  │           └────┬─────┘    ║
║  └───────────┘       │   └────┬─────┘                │          ║
║                      │        │                       │          ║
║                      │        │ ECG Sample            ▼          ║
║                      │        │ (12-bit @360Hz)   VGA Monitor   ║
║                      │        │                                  ║
║                      │        │                                  ║
║                      │        ▼                                  ║
║  CLOCK MANAGEMENT    │   ┌─────────────────────┐                ║
║  ┌──────────────┐    │   │  AUDIO OUTPUT       │                ║
║  │ 50 MHz       │    │   │  ┌───────────────┐  │                ║
║  │    ↓         │    │   │  │ Upsampler     │  │                ║
║  │ PLL          │    │   │  │ 360Hz→48kHz   │  │                ║
║  │    ↓         │    │   │  └───────┬───────┘  │                ║
║  │ 48 MHz ──────┼────┘   │          │          │                ║
║  │ 25 MHz       │        │  ┌───────▼───────┐  │                ║
║  └──────────────┘        │  │ I2S Transmit  │  │                ║
║                          │  │ (WM8731)      │  │                ║
║                          │  └───────┬───────┘  │                ║
║                          │          │          │                ║
║                          │  ┌───────▼───────┐  │                ║
║                          │  │ I2C Config    │  │                ║
║                          │  │ (Codec Init)  │  │                ║
║                          │  └───────┬───────┘  │                ║
║                          └──────────┼──────────┘                ║
║                                     │                           ║
║                                     ▼                           ║
║                              [ 3.5mm Jack ]                     ║
╚══════════════════════════════════║═════════════════════════════════╝
                                   ║ Audio Cable
                                   ║ (Analog ECG)
╔══════════════════════════════════║═════════════════════════════════╗
║                                  ▼                                  ║
║                           [ 3.5mm Jack ]                            ║
║                                  │                                  ║
║                           ┌──────▼──────┐                           ║
║                           │    ADC      │                           ║
║                           │  Line In    │                           ║
║                           └──────┬──────┘                           ║
║                                  │                                  ║
║                                  ▼                                  ║
║                     ┌────────────────────────┐                      ║
║                     │ Signal Conditioning    │                      ║
║                     │ • Downsample 48k→360Hz │                      ║
║                     │ • Extract 12-bit       │                      ║
║                     └──────────┬─────────────┘                      ║
║                                │                                    ║
║                                ▼                                    ║
║                     ┌──────────────────────┐                        ║
║                     │   CNN Classifier     │                        ║
║                     │ • Feature Extract    │                        ║
║                     │ • Neural Network     │                        ║
║                     │ • Classification     │                        ║
║                     └──────────────────────┘                        ║
║                                                                     ║
║              BOARD 2: Spartan-3E (CNN - Team)                      ║
╚═════════════════════════════════════════════════════════════════════╝
```

### **Board 1 (DE2-115) Detailed Block Diagram**

```
┌──────────────────────────────────────────────────────┐
│  50MHz Clock → PLL → 48MHz (Audio) + 25MHz (VGA)    │
└──────────────────────────────────────────────────────┘
                    │           │
        ┌───────────┘           └──────────┐
        │                                  │
        ▼                                  ▼
┌───────────────┐                 ┌───────────────┐
│ Audio Path    │                 │  VGA Path     │
│ (48 MHz)      │                 │  (25 MHz)     │
└───────────────┘                 └───────────────┘

ECG Memory (M9K) ←──── User Input (SW, KEY)
     │                         │
     ▼ (360 Hz sample tick)    ▼
┌─────────────┐          ┌─────────────┐
│ Upsampler   │          │ VGA Render  │
│ 360→48kHz   │          │ Scrolling   │
│ (×133)      │          │ Display     │
└──────┬──────┘          └──────┬──────┘
       │                        │
       ▼                        ▼
┌─────────────┐          ┌─────────────┐
│ I2S TX      │          │ VGA Output  │
│ WM8731      │          │ HSYNC/VSYNC │
└──────┬──────┘          │ RGB[3:0]    │
       │                 └─────────────┘
       ▼
  3.5mm Jack ────────────────────▶ To CNN Board
```

### **Data Flow Summary**

1. User selects waveform (switches) → Mode controller
2. Sample generator reads from M9K RAM @ 360 Hz
3. Sample streams to **both**:
   - VGA renderer (local display)
   - Audio upsampler (transmission to CNN board)
4. VGA displays scrolling waveform in real-time
5. Audio upsampler holds each sample for 133 audio frames
6. I2S transmitter sends to WM8731 codec
7. Analog audio exits via 3.5mm jack
8. **CNN board receives audio, digitizes, classifies, returns result**

---

## SLIDE 4: Design Choices, Analysis & Decisions

### **Critical Design Decisions**

#### **1. Board Selection: DE2-115 vs Spartan-3E**

| Feature | DE2-115 (Chosen) | Spartan-3E |
|---------|------------------|------------|
| **Logic Elements** | 114,480 | 10,476 |
| **Memory** | 3.98 Mbits | 360 Kbits |
| **Audio Codec** | ✓ Built-in WM8731 | ✗ None |
| **VGA Quality** | 10-bit (4-4-4) | 3-bit (1-1-1) |
| **LEDs** | 18 red + 9 green | 4-8 typical |
| **PLLs** | 4 PLLs | 4 DCMs |

**Analysis**: DE2-115 is optimal choice
- **Built-in audio codec** - Key requirement for audio transmission
- **11x more resources** - Massive headroom for features
- **Better VGA quality** - Clearer ECG visualization
- **More I/O** - Better user feedback with many LEDs

**Team Strategy**: Use larger DE2-115 for simulation (my component), reserve Spartan-3E for CNN (team's component)

---

#### **2. Inter-Board Communication: Audio vs. GPIO/UART**

| Method | Complexity | Cable | Isolation | Testability | Education Value |
|--------|------------|-------|-----------|-------------|-----------------|
| **GPIO** | Low | Ribbon cable (12+ wires) | None | Difficult | Low |
| **UART** | Medium | 2-3 wires | Partial | Medium | Medium |
| **Audio** ✓ | Medium-High | Standard 3.5mm | Excellent | Easy | **High** |

**Choice**: 3.5mm Audio Jack (Analog Transmission)

**Rationale**:
- ✓ **Standard hardware** - Any 3.5mm stereo cable works
- ✓ **Physical flexibility** - Boards can be meters apart
- ✓ **Galvanic isolation** - Audio transformers prevent ground loops
- ✓ **Easy testing** - Oscilloscope, audio analyzer readily available
- ✓ **Educational value** - Learn I2S, I2C, audio codec interfacing
- ✓ **Robust** - Analog transmission less sensitive to digital noise

**Challenges Introduced**:
- Need audio codec on both boards (DE2-115 has WM8731, Spartan-3E needs ADC)
- Requires upsampling (360 Hz → 48 kHz) and downsampling
- Analog signal may have noise (mitigated by differential signaling in audio)

---

#### **3. Audio Sample Rate: 48 kHz Standard**

**Transmission Chain**:
```
ECG: 360 Hz → Upsample ×133 → 48 kHz → I2S → WM8731 → Analog → Cable
              (Hold each sample            → 3.5mm Jack
               for 133 periods)
```

**Clock Divider Calculations**:
```
Primary: 50 MHz / 360 Hz = 138,889 → Sample Tick
Audio: 48 kHz (generated by PLL from 50 MHz)
Upsample Ratio: 48,000 / 360 = 133.33 ≈ 133
```

**Why 48 kHz?**
- ✓ **Standard audio rate** - Native WM8731 support
- ✓ **Integer upsampling** - 133x clean multiplication
- ✓ **Sufficient bandwidth** - Nyquist 24 kHz >> 360 Hz ECG spectrum
- ✓ **Common** - Audio equipment compatibility

**Upsampling Method**: Hold-and-Repeat
```vhdl
-- Each 360 Hz ECG sample held for 133 audio frames
for i in 0 to 132 loop
    audio_output <= ecg_sample;  -- Same value repeated
end loop;
```
- Simple implementation
- Preserves original ECG values exactly
- Easy to downsample on receiving end

---

#### **4. VGA Display Strategy: Scrolling Display (Unchanged)**

| Choice | **Scrolling Display** |
|--------|---------------------|
| **Buffer Size** | 640 samples (1 per pixel) |
| **Update Rate** | 1 new sample every 2.78 ms |
| **Display Rate** | 60 fps (16.68 ms/frame) |

**Advantages**:
✓ Real-time "ECG monitor" feel - engaging demo  
✓ Simpler rendering logic  
✓ Only 640 samples in buffer vs. 307,200 pixels  
✓ Continuous demonstration  

**Y-Coordinate Mapping** (Better precision on DE2-115):
```vhdl
y_position = 240 - (ecg_sample / 10)
```
- Centers at Y=240
- 10-bit VGA color allows smoother gradients (vs 3-bit on Spartan)

---

#### **5. Memory Architecture: M9K Block RAM**

| Resource | DE2-115 Usage |
|----------|---------------|
| **ECG Storage** | 3 M9K blocks (3 waveforms × 360 samples) |
| **VGA Buffer** | 2 M9K blocks (640 × 12-bit) |
| **Total Used** | 5 / 432 blocks = **1.2%** ✓ |

**Analysis**: Trivial resource usage - plenty of headroom for enhancements

---

#### **6. User Interface: Enhanced with More LEDs**

**DE2-115 Advantages**:
- 18 red LEDs + 9 green LEDs (vs 4-8 on Spartan-3E)

**LED Allocation**:
- `LEDR[1:0]`: Waveform mode (00=Normal, 01=PVC, 10=AFib)
- `LEDR[2]`: Playback status (1=playing, 0=paused)
- `LEDR[3]`: Audio output active
- `LEDR[17:4]`: **Audio level meter** (visualize ECG amplitude in real-time)
- `LEDG[8:0]`: Sample counter or heart rate (optional)

**Visual Feedback**: User can see both waveform on VGA AND audio activity on LEDs

---

### **Resource Utilization Analysis**

| Resource | Estimated | Available | % Used | Status |
|----------|-----------|-----------|--------|--------|
| Logic Elements | ~6,000 | 114,480 | 5% | ✓ Excellent |
| M9K RAM | 5-7 | 432 | 1.5% | ✓ Excellent |
| PLLs | 1 | 4 | 25% | ✓ Safe |
| I/O Pins | ~35 | 528 | 7% | ✓ Excellent |

**Conclusion**: DE2-115 provides massive headroom - can add many enhancements!

---

## SLIDE 5: Technical Challenges & Solutions

### **Challenge 1: Multiple Clock Domains (3 clocks now!)**

**Problem**: 
- System Clock: 50 MHz (sample generation, M9K)
- Audio Clock: 48 MHz (I2S transmission) **NEW!**
- VGA Pixel Clock: 25 MHz (display)

**Solution**: PLL + Dual-Port RAM + Clock Domain Crossing (CDC)
```
                    ┌─────────────┐
50 MHz Oscillator ─▶│     PLL     │─┬─▶ 48 MHz (audio)
                    │  (Altera)   │ │
                    └─────────────┘ └─▶ 25 MHz (VGA)

ECG Sample (50 MHz domain)
    │
    ├──▶ VGA Buffer (dual-port RAM)──▶ Read @ 25 MHz
    │
    └──▶ Audio Upsampler (with synchronizer)──▶ 48 MHz domain
```

**CDC Technique**: 
- Use 2-stage synchronizer for control signals crossing domains
- Dual-port RAM for data (write @ 50 MHz, read @ 25/48 MHz)
- Handshake not needed (consumers slower than producer)

---

### **Challenge 2: Audio Codec Initialization**

**Problem**: WM8731 codec must be configured before use
- Requires I2C protocol (slow serial bus)
- Must set sample rate, format, volume, power-on sequence
- Configuration errors prevent audio output

**Solution**: I2C Master State Machine
```vhdl
State Machine:
IDLE → START → ADDR → ACK → REG → ACK → DATA → ACK → STOP → NEXT
```

**Configuration Sequence** (10 I2C transactions):
1. Reset codec
2. Set Line In levels
3. Set Headphone Out levels  
4. Power on DAC
5. Set I2S format
6. Set sample rate to 48kHz
7. Activate codec

**Verification**: 
- Monitor I2C_SCLK and I2C_SDAT with logic analyzer
- Check for ACK pulses
- Use LED to indicate "codec_ready"

**Fallback**: Manual bit-banging if I2C master has issues

---

### **Challenge 3: ECG-to-Audio Upsampling**

**Problem**: 
- ECG data rate: 360 Hz (one sample every 2.78 ms)
- Audio I2S rate: 48 kHz (one sample every 20.8 μs)
- Need to convert smoothly without artifacts

**Solution**: Hold-and-Repeat (Zero-Order Hold)
```
ECG Sample N: ████████████████████████...█████████
              |<--- 133 audio frames --->|

Audio Output: ┌─┬─┬─┬─┬─┬─...─┬─┬─┐
              └─┴─┴─┴─┴─┴─...─┴─┴─┘
              All 133 frames = same value
```

**Implementation**:
```vhdl
process(clk_48khz)
    if sample_tick_sync = '1' then
        held_sample <= ecg_sample;  -- Latch new
        hold_count <= 0;
    elsif hold_count < 132 then
        hold_count <= hold_count + 1;
        -- held_sample unchanged
    end if;
    
    audio_out <= held_sample & "0000";  -- Pad 12→16 bit
end process;
```

**Receiving End**: CNN board downsamples by taking every 133rd sample

---

### **Challenge 4: Real-Time VGA + Audio Simultaneously**

**Problem**: 
- VGA refresh: 60 Hz (high priority for smooth display)
- Audio I2S: 48 kHz (cannot underrun, must be continuous)
- Both share same ECG data source
- Risk of resource contention or timing violations

**Solution**: Parallel Processing with Independent Clock Domains
```
                    ECG Sample Generator
                           │
                           ▼
              ┌────────────┴────────────┐
              │                         │
       ┌──────▼──────┐           ┌──────▼──────┐
       │  VGA Buffer │           │   Audio     │
       │  Write      │           │  Upsampler  │
       │  @ 50 MHz   │           │  @ 50 MHz   │
       └──────┬──────┘           └──────┬──────┘
              │                         │
       ┌──────▼──────┐           ┌──────▼──────┐
       │  VGA Buffer │           │   I2S TX    │
       │  Read       │           │  @ 48 MHz   │
       │  @ 25 MHz   │           └─────────────┘
       └─────────────┘
```

**Key Design**:
- VGA and audio are completely independent
- Both read from same source but different rates
- No blocking or contention (one writes, others read)
- DE2-115 resources easily handle both simultaneously

**Verification**:
- Timing analysis ensures no critical paths
- Simulation verifies both outputs concurrent
- Hardware test confirms smooth VGA + audio

---

### **Challenge 5: Audio Signal Integrity Over Cable**

**Problem**: 
- 3.5mm analog audio susceptible to noise
- Cable quality varies
- Long cables may attenuate signal
- Ground loops possible

**Solution**: Multi-Level Mitigation
1. **Differential signaling** (inherent in audio)
2. **Test with short cable first** (1 meter)
3. **Shielded cable** for longer runs
4. **Signal verification points**:
   - Oscilloscope at DE2-115 output (verify clean waveform)
   - Oscilloscope at Spartan-3E input (verify received signal)
5. **Adjustable gain** - Can configure WM8731 volume

**Acceptance Criteria**: 
- SNR > 40 dB (measured with audio analyzer)
- ECG waveform recognizable on oscilloscope
- CNN can extract samples with <1% error rate

---

## SLIDE 6: Preparedness for COE 70B - Implementation Plan

### **Development Timeline (8-Week Implementation Phase)**

#### **Weeks 1-2: Foundation & Audio Bring-Up** 🎵
**Goals**: Audio codec working, can output test tone
- [ ] Quartus project setup for DE2-115
- [ ] PLL configuration (50→48 MHz + 50→25 MHz)
- [ ] I2C master implementation (WM8731 config)
  - **TEST**: Verify I2C ACK signals with logic analyzer
  - **TEST**: LED indicates codec_ready
- [ ] I2S transmitter basic implementation
  - **TEST**: Output 1 kHz test tone
  - **TEST**: Measure with oscilloscope (sine wave visible)
- [ ] VGA timing generator (reuse proven design)
  - **TEST**: Color bar pattern on monitor

**Milestone**: Audio codec outputs test tone, VGA shows test pattern

---

#### **Weeks 3-4: ECG Data & Audio Transmission** 📊
**Goals**: ECG waveforms transmitted via audio
- [ ] ECG memory (M9K) with sample data
  - Convert 3 waveforms from MIT-BIH dataset (Python script)
  - Initialize M9K with .mif files
- [ ] Sample upsampler (360 Hz → 48 kHz)
  - **TEST**: Verify hold-and-repeat logic in simulation
- [ ] Connect ECG → Audio pipeline
  - **HARDWARE TEST**: Output Normal ECG waveform via 3.5mm
  - **TEST**: Verify ECG pattern on oscilloscope (audio output)
  - **TEST**: All 3 waveforms (Normal, PVC, AFib) distinguishable

**Milestone**: Can see ECG waveform in audio signal (oscilloscope)

---

#### **Weeks 5-6: VGA Display & User Interface** 🖥️
**Goals**: Complete local visualization and control
- [ ] ECG VGA renderer (scrolling display)
  - **TEST**: Static waveform first
  - **TEST**: Scrolling waveform
- [ ] User interface controller (switches, buttons, LEDs)
  - Debouncing for KEY[0]
  - Mode selection SW[1:0]
  - LED status display (mode + audio level meter)
- [ ] Full integration on DE2-115
  - **TEST**: Switch waveforms, see change on both VGA and audio
  - **TEST**: Pause/resume via button
  - **TEST**: Long-run stability (4+ hours)

**Milestone**: Complete DE2-115 system working independently

---

#### **Weeks 7-8: Two-Board Integration & Demo** 🔗
**Goals**: End-to-end system operational
- [ ] **Team Integration Meeting**
  - Define Spartan-3E ADC requirements with Ayoub
  - Agree on audio signal levels, format, timing
  - Plan physical setup for demo
- [ ] **Audio Cable Connection**
  - DE2-115 Line Out → 3.5mm cable → Spartan-3E Line In
  - **TEST**: Signal integrity measurement
  - **TEST**: Verify CNN board receives clean ECG
- [ ] **Classification Integration**
  - Feed Normal ECG → Verify CNN outputs "Normal"
  - Feed PVC → Verify CNN outputs "PVC"
  - Feed AFib → Verify CNN outputs "AFib"
  - Display CNN result on DE2-115 LEDs
- [ ] **Final Demo Preparation**
  - Practice demo flow
  - Prepare backup (video recording)
  - Create demo presentation

**Milestone**: Working two-board demo with CNN classification

---

### **Risk Management**

| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|---------------------|
| Audio codec config fails | Medium | High | Use Altera examples; fallback to bit-banging |
| Audio signal too noisy | Medium | High | Test with short cable; use shielded cable; adjustable gain |
| PLL lock issues | Low | Medium | Use proven PLL settings; monitor lock status |
| Two-board sync issues | Medium | High | Early integration testing; clear interface spec |
| VGA + Audio simultaneous | Low | Medium | Independent clock domains; verified in timing analysis |

---

### **Success Criteria**

**Minimum Viable Demo** (must-have):
✓ DE2-115 displays ECG waveform on VGA  
✓ Audio output measurable on oscilloscope  
✓ User can select 3 different waveforms  
✓ Audio signal reaches CNN board  

**Full Feature Demo** (goal):
✓ Smooth VGA scrolling display  
✓ Clean audio transmission (CNN correctly classifies)  
✓ User interface fully functional (pause, resume, mode select)  
✓ LED indicators for mode, status, audio level  
✓ Both boards operating together reliably  
✓ Classification results displayed on DE2-115  

**Stretch Goals** (if time permits):
○ Line-drawn waveform (smoother VGA trace)  
○ Heart rate calculation displayed on 7-segment  
○ Audio level meter on red LEDs (real-time amplitude)  
○ Classification confidence score on VGA  

---

### **Resource Allocation**

**Lab Access**: COE758 Lab (Engineering Building)
- DE2-115 board with VGA port + audio jacks
- Spartan-3E board (for CNN - team's)
- VGA monitor (640×480 capable)
- Oscilloscope (for audio signal verification)
- Audio cables (3.5mm stereo)
- **Possible**: Audio ADC module if Spartan-3E lacks audio input

**Tools**: 
- Quartus Prime (Altera/Intel)
- ModelSim (simulation)
- Python 3.x (ECG data conversion)
- Git (version control)

**Team Coordination**:
- **Week 3**: Interface spec meeting with Ayoub (CNN team)
- **Week 6**: Integration testing session
- **Week 8**: Joint demo rehearsal
- **Continuous**: Shared GitHub for documentation

---

### **Learning Outcomes Expected**

By end of COE 70B, I will have hands-on experience with:
1. **FPGA Design**: Clock management (PLL), resource optimization
2. **VGA Display**: Timing generation, pixel rendering in HDL
3. **Audio Interfacing** ⭐: I2S protocol, I2C protocol, codec configuration
4. **Memory Systems**: M9K Block RAM, dual-port RAM, clock domain crossing
5. **Digital Design**: Multi-clock domains, synchronization, upsampling
6. **System Integration**: Two-board interfacing, analog signal transmission
7. **Hardware Debugging**: Logic analyzer, oscilloscope, audio analyzer
8. **Real-World Skills**: Standard interfaces (VGA, audio), signal integrity

**Unique Value**: Audio codec interfacing is rarely taught - valuable industry skill

---

## PRESENTATION NOTES

### **Opening (30 seconds)**
"I'm responsible for the Simulation Component - but now it's a **two-board system**. My DE2-115 board stores ECG waveforms, displays them on VGA, and transmits them via audio jack to our team's Spartan-3E CNN classifier. This audio interface teaches us real-world signal transmission while making our demo interactive and visually engaging."

### **Time Allocation**
- Slide 1 (Problem + Two-Board Concept): 2 min
- Slide 2 (Requirements): 1.5 min  
- Slide 3 (Architecture): 2 min
- Slide 4 (Design Choices - focus on audio!): 2.5 min  
- Slide 5 (Challenges): 1.5 min
- Slide 6 (Implementation Plan): 0.5 min

**Total**: ~10 minutes

### **Q&A Preparation**

**Q1 - Problem Definition (20 points)**
- *Why two boards instead of one?* → Team already using Spartan-3E for CNN; DE2-115 has audio codec
- *Why audio interface?* → Standard connection, isolation, educational value
- *Why these specific waveforms?* → Normal vs abnormal heartbeats (clinical relevance)
- *How does this support overall project?* → Provides test data + visual demo + realistic signal transmission

**Q2 - Design Choices (50 points)** ⭐ MOST IMPORTANT
- *Why DE2-115 over Spartan-3E for simulation?* → Built-in audio codec, 11x resources, better VGA
- *Why 48 kHz audio for 360 Hz ECG?* → Standard rate, integer upsampling (133x), sufficient bandwidth
- *How does upsampling work?* → Hold each ECG sample for 133 audio frames (zero-order hold)
- *Why not just use GPIO between boards?* → Physical separation, isolation, standard cables, educational
- *What if audio is too noisy?* → Short cable, shielded, adjustable gain, differential signaling
- *How do you handle 3 clock domains?* → PLL for generation, dual-port RAM, CDC synchronizers
- *Why scrolling VGA display?* → Real-time feel, simpler rendering, continuous demo
- *How did you size the buffer?* → 640 samples = 1 per pixel, ~1.8 sec of data
- *Resource usage?* → Only 5-7% of DE2-115 (massive headroom)

**Q4 - COE 70B Preparedness (15 points)**
- *What's your riskiest component?* → Audio codec initialization - mitigated with Altera examples
- *What if audio doesn't work?* → Test with tone generator first; use logic analyzer; fallback to GPIO
- *How will you test audio transmission?* → Oscilloscope on both ends, audio analyzer, SNR measurement
- *Timeline for two-board integration?* → Week 6 (audio ready), Week 7 (CNN ready), Week 8 (full system)
- *What if CNN team not ready?* → Test with loopback (audio out → audio in on same board)

---

### **Key Talking Points to Emphasize**

1. **Two-board architecture** adds complexity but brings realistic system integration experience
2. **Audio interface** is educational gold - learning I2S, I2C, codec configuration
3. **DE2-115** selected specifically for built-in audio codec (WM8731)
4. **Hold-and-repeat upsampling** preserves ECG signal integrity (no interpolation artifacts)
5. **Massive resource headroom** (5% usage) allows for creative enhancements
6. **Standard 3.5mm cable** means easy testing and robust connection

---

**Document Version**: 2.0 (DE2-115 Two-Board Audio Interface)  
**Created**: November 28, 2025  
**Presentation Date**: COE 70A Mid-Term Review  
**Presenter**: Marly - Simulation Component Team  
**Updated For**: DE2-115 + Audio Interface Architecture
