# Summary of Changes - Two-Board Architecture Update

## Document Purpose
Quick reference guide highlighting the key differences between the original single-board design (Spartan-3E) and the updated two-board design (DE2-115 + Spartan-3E with audio interface).

**Date**: November 28, 2025  
**Version**: 2.0 → DE2-115 Two-Board Architecture  
**Status**: Complete - Ready for Mid-Term Presentation

---

## 🎯 WHAT CHANGED IN ONE SENTENCE

**Original**: Single Spartan-3E FPGA with simulation component feeding CNN via GPIO  
**Updated**: DE2-115 FPGA (simulation) transmits ECG to Spartan-3E (CNN) via 3.5mm audio jack

---

## 📋 QUICK COMPARISON TABLE

| Aspect | Original Design | Updated Design | Impact |
|--------|----------------|----------------|--------|
| **Board 1** | Spartan-3E | **DE2-115** | ⭐ Platform change |
| **Board 2** | N/A | **Spartan-3E (CNN)** | ⭐ Two-board system |
| **Connection** | GPIO (12+ pins) | **3.5mm audio jack** | ⭐ Major change |
| **Transmission** | Digital parallel | **Analog audio** | ⭐ New protocol |
| **Resources** | 10K logic | **114K logic** | 11x increase |
| **Memory** | 360 Kbits | **3.98 Mbits** | 11x increase |
| **VGA Color** | 3-bit | **10-bit** | Better quality |
| **LEDs** | 4-8 | **27** | Much better feedback |
| **Modules** | 9 | **12 (+5 audio)** | 33% more code |
| **Protocols** | None | **I2S + I2C** | New learning |
| **Sample Format** | Direct 12-bit | **12-bit → 16-bit audio** | Conversion needed |
| **Clocks** | 2 (50MHz, 25MHz) | **3 (50MHz, 48MHz, 25MHz)** | One more domain |

---

## 🔑 KEY CHANGES BREAKDOWN

### 1. Hardware Platform: Spartan-3E → DE2-115

**Reason for Change**: DE2-115 has built-in WM8731 audio codec

**Advantages**:
- ✅ Audio codec included (no external hardware needed)
- ✅ 11x more FPGA resources (plenty of headroom)
- ✅ Better VGA quality (10-bit vs 3-bit color)
- ✅ More user I/O (27 LEDs vs 4-8)
- ✅ More flexible clocking (4 PLLs)

**Challenges**:
- ⚠️ Different toolchain (Quartus vs ISE)
- ⚠️ Different pin names and constraints
- ⚠️ Need to learn Altera-specific features

**Migration Effort**: Low - VHDL code largely portable

---

### 2. Inter-Board Connection: GPIO → Audio Jack

**Reason for Change**: Physical board separation + educational value

**New Hardware Requirements**:
- ✅ 3.5mm stereo audio cable (standard, cheap)
- ✅ WM8731 codec on DE2-115 (already built-in)
- ⚠️ ADC on Spartan-3E for CNN board (team's responsibility)

**New Protocols to Learn**:
- 📚 **I2S** (Inter-IC Sound): Serial audio data protocol
- 📚 **I2C** (Inter-Integrated Circuit): Codec configuration protocol

**New Modules Required** (5 total):
1. `i2c_master.vhd` - I2C protocol controller
2. `wm8731_config.vhd` - Codec initialization sequence
3. `sample_upsampler.vhd` - 360 Hz → 48 kHz conversion
4. `i2s_transmitter.vhd` - I2S serial transmission
5. `audio_output_controller.vhd` - Complete audio chain wrapper

---

### 3. Sample Rate Conversion: Direct → Upsampled

**Original**: ECG samples output directly at 360 Hz (12-bit digital)  
**Updated**: ECG samples upsampled to 48 kHz audio (16-bit I2S)

**Upsampling Algorithm**: Hold-and-Repeat (Zero-Order Hold)
```
ECG Sample Rate: 360 Hz (one sample every 2.78 ms)
Audio Sample Rate: 48 kHz (one sample every 20.8 μs)
Upsample Ratio: 48,000 / 360 = 133.33 ≈ 133

Implementation: Hold each ECG sample for 133 consecutive audio frames
```

**Code Example**:
```vhdl
-- Original (direct output)
ecg_out <= ecg_sample;  -- Updated at 360 Hz

-- Updated (with upsampling)
if sample_tick = '1' then
    held_sample <= ecg_sample;  -- Latch new ECG sample
    hold_counter <= 0;
elsif hold_counter < 132 then
    hold_counter <= hold_counter + 1;
end if;
audio_out <= held_sample & "0000";  -- Held for 133 audio frames @ 48kHz
```

**Receiving End** (CNN Board):
- Must downsample 48 kHz audio back to 360 Hz
- Take every 133rd sample to recover original ECG
- Team's responsibility to implement

---

### 4. Clock Management: 2 Clocks → 3 Clocks

**Original Clocks**:
- 50 MHz (system) - from oscillator
- 25 MHz (VGA) - from divider

**Updated Clocks**:
- 50 MHz (system) - from oscillator
- **48 MHz (audio)** ⭐ - from PLL
- 25 MHz (VGA) - from PLL (or divider)

**New Component**: Altera PLL (MegaWizard)
```vhdl
pll_50to48
    Input:  50 MHz
    Output c0: 48 MHz (audio)
    Output c1: 25 MHz (VGA)
    Output locked: PLL status
```

**Clock Domain Crossings**: Now 3 domains instead of 2
- Need proper synchronizers
- Dual-port RAM for data transfer
- Timing analysis more complex

---

### 5. Pin Assignments: UCF → QSF Format

**Original**: Xilinx UCF (User Constraint File)
```
NET "clk_50mhz" LOC = "C9" | IOSTANDARD = LVCMOS33;
```

**Updated**: Altera QSF (Quartus Settings File)
```tcl
set_location_assignment PIN_Y2 -to clk_50mhz
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk_50mhz
```

**New Pins Added** (for audio):
```tcl
set_location_assignment PIN_D2 -to aud_bclk      # I2S bit clock
set_location_assignment PIN_C2 -to aud_daclrck   # I2S L/R clock
set_location_assignment PIN_D1 -to aud_dacdat    # I2S data
set_location_assignment PIN_C3 -to i2c_sclk      # I2C clock
set_location_assignment PIN_D3 -to i2c_sdat      # I2C data
```

---

## 📊 RESOURCE IMPACT

### FPGA Resource Comparison

| Resource Type | Original (S3E) | Updated (DE2-115) | Change |
|---------------|----------------|-------------------|--------|
| **Logic** | ~2,000 / 10,476 (19%) | ~6,000 / 114,480 (5%) | ✅ Better utilization |
| **RAM Blocks** | 4-5 / 20 (22%) | 5-7 / 432 (1.5%) | ✅ Much more available |
| **Clocking** | 1 DCM | 1 PLL | ≈ Similar |
| **I/O Pins** | ~25 / 232 (11%) | ~35 / 528 (7%) | ✅ Better utilization |

**Conclusion**: Updated design uses MORE absolute resources but LOWER percentage of available resources due to larger FPGA.

### Code Size Impact

| Metric | Original | Updated | Increase |
|--------|----------|---------|----------|
| **Modules** | 9 | 12 | +33% |
| **Lines of Code** | ~800-1000 | ~1200-1500 | +40% |
| **Testbenches** | 9 | 12 | +33% |
| **Documentation** | 4 docs | 4 docs | Same |

**Development Time Impact**: ~2 extra weeks for audio implementation

---

## 🎓 EDUCATIONAL VALUE COMPARISON

### Skills Learned

| Skill Category | Original | Updated | Added Value |
|----------------|----------|---------|-------------|
| **FPGA Basics** | ✓ | ✓ | - |
| **VGA Display** | ✓ | ✓ | - |
| **Memory Systems** | ✓ | ✓ | - |
| **Clock Management** | Basic | **Advanced (PLL)** | ⭐ |
| **Serial Protocols** | None | **I2S + I2C** | ⭐⭐⭐ |
| **Audio Codec** | None | **WM8731 Config** | ⭐⭐⭐ |
| **Analog Signals** | None | **Audio Transmission** | ⭐⭐ |
| **System Integration** | Single board | **Two-board** | ⭐⭐ |
| **Signal Integrity** | Basic | **Oscilloscope Analysis** | ⭐⭐ |

**Educational ROI**: ⭐⭐⭐⭐⭐ (5/5)  
Audio interface adds significant real-world skills rarely taught in courses.

---

## 🔧 IMPLEMENTATION COMPLEXITY

### Development Phases Comparison

| Phase | Original Time | Updated Time | Reason for Change |
|-------|--------------|--------------|-------------------|
| **Setup** | 1 week | 1 week | Same |
| **Clock Mgmt** | 0.5 weeks | 0.5 weeks | PLL replaces divider |
| **Memory** | 1 week | 1 week | M9K similar to BRAM |
| **VGA** | 2 weeks | 2 weeks | Same design |
| **Interface** | 1 week (GPIO) | **3 weeks (Audio)** ⭐ | I2C+I2S+codec |
| **User Interface** | 1 week | 1 week | Same |
| **Integration** | 1 week | **2 weeks (Two boards)** ⭐ | Cross-board testing |

**Total**: 7.5 weeks → **10.5 weeks**  
**Additional Time**: ~3 weeks for audio implementation  
**Fits in COE 70B?**: Yes (8 weeks + winter break + can prioritize)

---

## 🚀 MIGRATION GUIDE

### If You Need to Switch Between Versions

#### From Original to Updated (Current Direction)
1. ✅ Copy core modules (mostly compatible):
   - `sample_rate_controller.vhd` ✓
   - `ecg_memory.vhd` (change BRAM → M9K) ✓
   - `ecg_sample_generator.vhd` ✓
   - `vga_timing_generator.vhd` ✓
   - `ecg_vga_renderer.vhd` (update RGB width) ✓
   - `user_interface_controller.vhd` (update LED count) ✓

2. 🔄 Replace platform-specific:
   - UCF → QSF pin assignments
   - ISE project → Quartus project
   - Xilinx primitives → Altera primitives (if any)

3. ⭐ Add new audio modules:
   - Create `i2c_master.vhd` (from scratch or Altera example)
   - Create `wm8731_config.vhd` (from datasheet)
   - Create `sample_upsampler.vhd` (new algorithm)
   - Create `i2s_transmitter.vhd` (from I2S spec)
   - Create `audio_output_controller.vhd` (integration)

4. 🔗 Modify top-level:
   - Add PLL instantiation
   - Add audio controller instantiation
   - Update port list (remove GPIO, add audio pins)
   - Update internal signals (add clk_48mhz)

#### From Updated Back to Original (Fallback)
If audio fails and need to revert to GPIO:

1. Remove audio modules (5 modules)
2. Remove PLL (use simple clock divider)
3. Change QSF → UCF
4. Add GPIO pins for direct CNN connection
5. Remove upsampling logic

**Time to Revert**: 2-3 days

---

## 📝 DOCUMENTATION UPDATES

### All Documents Updated in `docs_de2115/`

| Document | Key Changes |
|----------|-------------|
| **technical_reference.md** | + DE2-115 specs<br>+ WM8731 codec details<br>+ I2S/I2C protocols<br>+ Audio upsampling algorithms<br>+ Pin assignments for audio |
| **system_architecture.md** | + Two-board system overview<br>+ Audio module hierarchy<br>+ Updated timing diagrams (3 clocks)<br>+ Audio interface specs<br>+ Integration with CNN board |
| **presentation_slides.md** | + Slide content updated for audio<br>+ Emphasis on design choice (audio vs GPIO)<br>+ Two-board architecture diagrams<br>+ Audio-related Q&A prep<br>+ Updated risk analysis |
| **implementation_roadmap.md** | + Weeks 1-4 focus on audio<br>+ Week 7-8 two-board integration<br>+ Audio testing procedures<br>+ Oscilloscope verification steps<br>+ Two-board coordination tasks |
| **README.md** | + Two-board overview<br>+ Audio interface summary<br>+ Updated module count<br>+ Version history<br>+ Migration guide |

---

## 🎤 PRESENTATION STRATEGY CHANGES

### What to Emphasize in Mid-Term

**BEFORE (Original)**:
- Focus: VGA rendering, BRAM usage, GPIO interface
- Complexity: Medium
- Differentiator: Scrolling display

**AFTER (Updated)**:
- Focus: **Audio interface design** ⭐ (50% of grade is design choices!)
- Complexity: Medium-High
- Differentiator: **Two-board system with audio codec**

### Key Talking Points (NEW)

1. **"Chose DE2-115 specifically for built-in audio codec"**
   - Show comparison table (Slide 4)
   - Emphasize WM8731 availability
   - Explain why audio > GPIO

2. **"Audio interface teaches I2S and I2C protocols"**
   - Industry-standard protocols
   - Rarely taught in courses
   - High educational value

3. **"Two-board system mimics real embedded systems"**
   - Separate development
   - Physical integration challenges
   - Realistic project complexity

4. **"Hold-and-repeat upsampling preserves ECG integrity"**
   - No signal processing artifacts
   - Simple algorithm
   - Easy to verify

5. **"Massive resource headroom enables enhancements"**
   - Only 5% usage
   - Can add features freely
   - Professional-quality implementation

### Questions Likely to Arise

**Q**: "Why complicate with audio when GPIO is simpler?"  
**A**: Standard cables, physical separation, galvanic isolation, educational value (I2S/I2C), easy testing with oscilloscope. Only 3 extra weeks development time for significant learning.

**Q**: "What if audio quality is poor?"  
**A**: Multiple mitigations - shielded cable, short cable, adjustable gain, differential signaling. Test with oscilloscope at both ends. Worst case, revert to GPIO in 2-3 days.

**Q**: "Is this too ambitious for 8 weeks?"  
**A**: No - Weeks 1-4 for audio (proven Altera examples available), Weeks 5-6 for VGA (reusing design), Weeks 7-8 for integration. Clear milestones, testable increments.

---

## 🛠️ NEW TOOLS & EQUIPMENT NEEDED

### Software
- ❌ Remove: Xilinx ISE Design Suite
- ✅ Add: **Intel Quartus Prime**
- ✅ Add: **Altera MegaWizard** (for PLL)
- ✅ Keep: ModelSim (simulation - works for both)
- ✅ Keep: Python (data conversion)

### Hardware
- ✅ Keep: VGA monitor
- ✅ Add: **Oscilloscope** (critical for audio verification!)
- ✅ Add: **3.5mm audio cables** (stereo, shielded)
- ✅ Add: **Logic analyzer** (optional but helpful for I2C/I2S)
- ✅ Add: **Audio analyzer** (optional - for SNR measurements)

### Lab Equipment Needs
- DE2-115 board (request from COE758 lab)
- Spartan-3E board (team already has)
- Oscilloscope (mandatory for audio testing)
- Possible: Audio ADC module for Spartan-3E (if no audio input)

---

## 📐 SIGNAL SPECIFICATIONS

### Original: GPIO Interface
```
Signal Name       | Width  | Direction | Protocol
------------------|--------|-----------|----------
ecg_sample        | 12-bit | Output    | Parallel
sample_tick       | 1-bit  | Output    | Pulse
sample_valid      | 1-bit  | Output    | Handshake
cnn_result        | 2-bit  | Input     | Parallel
cnn_valid         | 1-bit  | Input     | Handshake
```
**Total Pins**: 12 + 1 + 1 + 2 + 1 = 17 pins  
**Cable**: Ribbon cable (17+ wires)

### Updated: Audio Interface
```
Signal Name       | Protocol | Direction | Purpose
------------------|----------|-----------|----------
AUD_BCLK          | I2S      | Output    | Bit clock (3.072 MHz)
AUD_DACLRCK       | I2S      | Output    | L/R clock (48 kHz)
AUD_DACDAT        | I2S      | Output    | Serial data
I2C_SCLK          | I2C      | Output    | I2C clock (~100 kHz)
I2C_SDAT          | I2C      | Bidir     | I2C data
```
**Total Pins**: 5 digital pins → WM8731 codec → 3.5mm analog output  
**Cable**: Standard 3.5mm stereo cable (2 audio + 1 ground)

**Simplification**: 5 digital pins vs 17 GPIO pins, PLUS analog transmission!

---

## 🎯 RISK ASSESSMENT CHANGES

### New Risks Introduced

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Audio codec config fails** | Medium | High | Altera examples, fallback bit-bang |
| **I2S timing issues** | Medium | Medium | Logic analyzer, proven patterns |
| **Audio signal noise** | Medium | High | Shielded cable, oscilloscope verify |
| **Two-board sync** | Medium | High | Early integration, test vectors |
| **PLL lock failure** | Low | Medium | Proven settings, monitor status |

### Risks Removed

| Risk | Reason Removed |
|------|---------------|
| GPIO pin shortage | DE2-115 has 528 I/O pins (vs 232) |
| BRAM synthesis issues | M9K more straightforward than BRAM |
| Limited LEDs | Now have 27 LEDs vs 4-8 |

**Net Risk**: Slightly increased, but well-mitigated with clear fallback plans

---

## ⏱️ TIMELINE IMPACT

### Original Timeline (Spartan-3E - 8 weeks)
- Week 1-2: Setup + clocks + VGA timing
- Week 3-4: ECG data + VGA rendering
- Week 5-6: User interface + GPIO interface
- Week 7-8: Testing + integration

### Updated Timeline (DE2-115 - 8 weeks)
- Week 1-2: Setup + **PLL** + **I2C master** + **codec init** ⭐
- Week 3-4: **I2S transmitter** + **ECG upsampling** + **audio output** ⭐
- Week 5-6: VGA timing + rendering + **simultaneous VGA+audio** ⭐
- Week 7-8: User interface + **two-board integration** ⭐

**Critical Path**: Audio implementation (Weeks 1-4)  
**Risk Mitigation**: Start audio early, use proven Altera examples

---

## 📚 NEW LEARNING REQUIREMENTS

### Additional Topics to Study

1. **I2S Protocol** (NEW)
   - Serial audio transmission
   - BCLK, LRCK, DATA signals
   - MSB-first serialization
   - Left/right channel multiplexing

2. **I2C Protocol** (NEW)
   - Two-wire serial bus
   - Start/stop conditions
   - ACK/NACK handling
   - 7-bit addressing

3. **WM8731 Audio Codec** (NEW)
   - Register map
   - Configuration sequence
   - Power-on requirements
   - Sample rate settings

4. **Sample Rate Conversion** (NEW)
   - Upsampling theory
   - Hold-and-repeat algorithm
   - Audio frequency domain
   - Nyquist considerations

5. **Altera Tools** (NEW - different from Xilinx)
   - Quartus Prime workflow
   - MegaWizard (PLL, IP cores)
   - TimeQuest timing analyzer
   - QSF file format

**Study Time**: ~20-30 hours total (spread over winter break + Week 1)

---

## 🎬 DEMO DIFFERENCES

### Original Demo Flow
1. Show VGA displaying ECG waveform
2. User switches between waveforms
3. GPIO cable to CNN board (hidden)
4. CNN classification result displayed

**Demo Duration**: ~3-4 minutes

### Updated Demo Flow
1. Show two boards: DE2-115 + Spartan-3E
2. **Highlight 3.5mm audio cable connection** ⭐
3. Show VGA displaying ECG waveform
4. User switches between waveforms
5. **Show audio output on oscilloscope** ⭐ (ECG pattern visible)
6. **Show audio level meter on LEDs** ⭐ (real-time)
7. CNN board receives audio, classifies
8. Classification result displayed back on DE2-115

**Demo Duration**: ~5-6 minutes (more to show!)  
**Visual Impact**: Much higher (oscilloscope, two boards, audio cable)

---

## 💡 RECOMMENDED APPROACH

### For Mid-Term Presentation (This Week)

**DO**:
- ✅ Emphasize educational value of audio interface
- ✅ Show two-board system diagram prominently
- ✅ Explain design rationale clearly (audio vs GPIO)
- ✅ Demonstrate preparedness (detailed 8-week plan)
- ✅ Highlight DE2-115 selection reasoning

**DON'T**:
- ❌ Apologize for complexity increase
- ❌ Minimize audio interface as "just a cable"
- ❌ Ignore fallback plans (professor will ask)
- ❌ Forget to mention team coordination

### For Implementation (COE 70B)

**Strategy**:
1. Start with audio modules (highest risk)
2. Test tone generator first (simpler than ECG)
3. Verify on oscilloscope at each step
4. VGA in parallel after audio works
5. Integrate only after both subsystems work independently

**Parallel Work Possible**:
- One person: Audio modules
- Another: VGA modules
- But you're alone, so sequential development

---

## 📞 SUPPORT RESOURCES

### Altera/Intel Resources
- DE2-115 User Manual: https://www.terasic.com.tw/cgi-bin/page/archive.pl?No=502
- Altera University Program: Audio examples, I2C examples
- Quartus documentation: PLL configuration guides
- Forums: Intel FPGA forums, Stack Overflow

### Audio Resources
- WM8731 Datasheet: Detailed register map, I2C commands
- I2S Specification: Philips/NXP I2S bus standard
- Audio engineering guides: For signal quality, SNR

### Team Resources
- Ayoub: CNN interface requirements
- Malcolm/Pierre: Lab equipment access, schedules
- Professor Khan: Technical guidance, equipment approval

---

## ✅ FINAL CHECKLIST FOR MID-TERM

### Documentation Ready?
- [x] All 5 documents in `docs_de2115/` complete
- [x] Presentation slides emphasize audio interface
- [x] Block diagrams show two-board system
- [x] Design rationale clearly explained
- [x] Implementation plan detailed (8 weeks)
- [x] Risk mitigation strategies defined
- [x] Q&A preparation comprehensive

### Presentation Ready?
- [ ] Practiced 10-minute presentation
- [ ] Can explain audio interface in 2 minutes
- [ ] Can defend design choices confidently
- [ ] Know answers to expected questions
- [ ] Have 1-page spec summary for reference
- [ ] Ready for deep technical discussion

### Team Ready?
- [ ] Team knows about two-board change
- [ ] Ayoub aware of audio interface (CNN team)
- [ ] Lab equipment needs communicated
- [ ] Integration timeline shared

---

## 🎓 FINAL THOUGHTS

### This Update Is:
✅ **More Complex** - Audio interface adds modules  
✅ **More Educational** - I2S, I2C, codec configuration  
✅ **More Realistic** - Two-board system integration  
✅ **More Testable** - Oscilloscope, audio analyzer  
✅ **More Impressive** - Physical demonstration with cable  

### This Update Is NOT:
❌ **Impossible** - Clear 8-week plan, proven examples available  
❌ **Over-resourced** - Only 5% of DE2-115 used  
❌ **Risky** - Multiple fallback options defined  
❌ **Disconnected from team** - Clear integration points  

---

## 🚦 STATUS INDICATOR

```
┌────────────────────────────────────────────────┐
│  PLANNING PHASE: ✅ COMPLETE                   │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                                │
│  📚 Research:          ✅ Complete             │
│  🏗️  Architecture:     ✅ Complete             │
│  📊 Presentation:      ✅ Ready                │
│  🗺️  Implementation:   ✅ Planned              │
│  📝 Documentation:     ✅ Complete             │
│                                                │
│  NEXT: Mid-Term Presentation (COE 70A)        │
│  THEN: Implementation (COE 70B)               │
└────────────────────────────────────────────────┘
```

---

**Document Version**: 1.0  
**Created**: November 28, 2025  
**Purpose**: Change Summary for Two-Board Architecture Update  
**Audience**: Marly + Team + Professor  
**Status**: Complete
