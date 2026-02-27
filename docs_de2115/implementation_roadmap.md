# ECG Simulation Component - Implementation Roadmap for COE 70B
## DE2-115 FPGA with Audio Interface

## Document Overview
This roadmap provides a detailed, week-by-week implementation plan for building the ECG Simulation & Visualization Component on DE2-115 FPGA with audio transmission to CNN board during COE 70B (8 weeks).

---

## IMPLEMENTATION PHILOSOPHY

### Development Approach
1. **Bottom-up**: Build and test individual modules first
2. **Incremental**: Add one feature at a time, verify before proceeding
3. **Test-driven**: Write testbenches before/alongside implementation
4. **Simulation-first**: Verify in simulation before hardware
5. **Risk-first**: Tackle hardest problems early (Audio codec, PLL, clock domains)

### Success Metrics
- ✓ Each module passes testbench
- ✓ Integration tests pass in simulation
- ✓ Resource usage < 80% of available
- ✓ Audio output verified with oscilloscope
- ✓ Two-board system demonstrates successfully

---

## WEEK 1: Project Setup & PLL Configuration

### Goals
- Development environment configured
- PLL generating all required clocks
- Foundation for all other modules

### Tasks

#### Day 1-2: Environment Setup
- [ ] **Install Quartus Prime** (Intel/Altera - latest version compatible with Cyclone IV)
  - Verify synthesis tools work
  - Test with simple LED blink example on DE2-115
- [ ] **Create project directory structure**:
  ```
  ecg_simulation_de2115/
  ├── rtl/           (VHDL source files)
  ├── tb/            (Testbenches)
  ├── data/          (ECG waveform data, .mif files)
  ├── sim/           (Simulation results)
  ├── quartus/       (Quartus project files)
  ├── constraints/   (QSF, SDC files)
  ├── audio/         (Audio-specific modules)
  └── docs/          (Documentation)
  ```
- [ ] **Set up version control** (Git)
  - Initialize repository
  - Add .gitignore for Quartus files
  - Create README with build instructions

#### Day 3-4: PLL MegaWizard Configuration
- [ ] **Create PLL using Altera MegaWizard**
  ```
  Input: 50 MHz (CLOCK_50)
  Output c0: 48 MHz (for audio I2S)
  Output c1: 25 MHz (for VGA pixel clock)
  Output c2: 50 MHz (pass-through, optional)
  ```
- [ ] **Write testbench for PLL**
  - Verify phase-locked status
  - Measure output frequencies
  - Check clock stability
- [ ] **Hardware test**
  - Program DE2-115
  - Use oscilloscope to verify 48 MHz and 25 MHz outputs on GPIO
  - Monitor PLL lock LED

#### Day 5-7: Sample Rate Controller
- [ ] **Implement `sample_rate_controller.vhd`**
  ```vhdl
  -- Generate 360 Hz tick from 50 MHz
  constant SAMPLE_DIVIDER : integer := 138889;
  ```
- [ ] **Write `tb_sample_rate_controller.vhd`**
  - Verify sample_tick period = 2.778 ms ±1%
  - Test enable/disable functionality
  - Verify single-cycle pulse width
- [ ] **Calculate actual frequency**:
  - Expected: 50,000,000 / 138,889 = 359.998 Hz
  - Measure in simulation
  - Document any discrepancy

### Deliverables
- [ ] Quartus project configured and building for DE2-115
- [ ] PLL generating 48 MHz (audio) and 25 MHz (VGA) verified
- [ ] Sample rate controller working (360 Hz verified)
- [ ] All modules have passing testbenches
- [ ] Documentation: module descriptions, PLL settings

### Milestone Review
**Criteria for proceeding to Week 2**:
- ✓ PLL locked and stable
- ✓ All clock frequencies verified (48/25 MHz)
- ✓ Sample tick timing correct (360 Hz)
- ✓ No timing violations in Quartus TimeQuest analysis

---

## WEEK 2: I2C Master & Audio Codec Initialization

### Goals
- I2C protocol working
- WM8731 codec configured
- Can initialize audio hardware

### Tasks

#### Day 1-3: I2C Master Implementation
- [ ] **Implement `i2c_master.vhd`**
  - State machine: IDLE → START → ADDR → ACK → REG → ACK → DATA → ACK → STOP
  - I2C clock generation (100 kHz or 400 kHz from 50 MHz)
  - SDA bidirectional control
  - ACK detection
- [ ] **Write `tb_i2c_master.vhd`**
  - Simulate write transaction
  - Verify timing (start condition, stop condition)
  - Check ACK pulse detection
  - Test with WM8731 address and register writes

#### Day 4-5: WM8731 Configuration Controller
- [ ] **Implement `wm8731_config.vhd`**
  ```vhdl
  -- Configuration sequence (10 transactions)
  type config_array is array (0 to 9) of std_logic_vector(15 downto 0);
  constant WM8731_INIT : config_array := (
      x"1E00",  -- Reset
      x"0017",  -- Left Line In
      x"0217",  -- Right Line In
      x"0479",  -- Left Headphone Out
      x"0579",  -- Right Headphone Out
      x"0A00",  -- DAC power on
      x"0C00",  -- Bypass off
      x"0E02",  -- I2S format
      x"1002",  -- 48kHz sample rate
      x"1201"   -- Activate
  );
  ```
- [ ] **Write testbench**
  - Simulate full configuration sequence
  - Verify all 10 transactions complete
  - Check status outputs (busy, done, ready)

#### Day 6-7: Hardware Audio Codec Test
- [ ] **Create test module**: `audio_test_top.vhd`
  - Instantiate PLL, I2C master, WM8731 config
  - Use LED to show codec_ready status
- [ ] **Update QSF file** with audio pins
  ```tcl
  set_location_assignment PIN_D2 -to aud_bclk
  set_location_assignment PIN_C2 -to aud_daclrck
  set_location_assignment PIN_D1 -to aud_dacdat
  set_location_assignment PIN_C3 -to i2c_sclk
  set_location_assignment PIN_D3 -to i2c_sdat
  ```
- [ ] **Program DE2-115 and verify**
  - Monitor I2C signals with logic analyzer (if available)
  - Check for I2C ACK pulses
  - Verify codec_ready LED turns on
  - Measure I2C timing (start, stop conditions)

### Deliverables
- [ ] I2C master module fully functional
- [ ] WM8731 configuration controller working
- [ ] Hardware test confirms codec initialization
- [ ] Logic analyzer traces (or simulation waveforms) documented

### Milestone Review
**Criteria for proceeding to Week 3**:
- ✓ I2C transactions complete successfully
- ✓ WM8731 codec initialized (LED confirms)
- ✓ No I2C bus errors or timeouts

---

## WEEK 3: I2S Transmitter & Audio Test Tone

### Goals
- I2S transmitter working
- Can output audio test tone
- Audio verified on oscilloscope

### Tasks

#### Day 1-3: I2S Transmitter Core
- [ ] **Implement `i2s_transmitter.vhd`**
  ```vhdl
  -- Generate I2S signals from 48 kHz clock
  -- BCLK = 3.072 MHz (48kHz × 64)
  -- LRCK = 48 kHz (left/right channel)
  -- DATA = serial audio data (MSB first)
  ```
- [ ] **Write `tb_i2s_transmitter.vhd`**
  - Verify BCLK frequency (3.072 MHz)
  - Verify LRCK frequency (48 kHz)
  - Check data serialization (16-bit samples)
  - Verify left/right channel alignment

#### Day 4-5: Audio Test Tone Generator
- [ ] **Implement `tone_generator.vhd`**
  ```vhdl
  -- Generate 1 kHz sine wave at 48 kHz sample rate
  -- Use lookup table (LUT) with 48 samples per period
  ```
- [ ] **Integrate**: PLL → Tone Gen → I2S TX → WM8731
- [ ] **Write testbench**
  - Verify sine wave generation
  - Check sample rate timing
  - Verify I2S output sequence

#### Day 6-7: First Audio Output Test
- [ ] **Program DE2-115 with tone generator**
  - Connect 3.5mm output to oscilloscope
  - **VERIFY**: 1 kHz sine wave visible
  - **VERIFY**: Amplitude appropriate (~1-2V peak-to-peak)
  - **OPTIONAL**: Connect to speaker/headphones (should hear 1 kHz tone)
- [ ] **Measure audio quality**
  - Check for distortion
  - Verify frequency accuracy
  - Test both left and right channels
- [ ] **Take measurements for documentation**
  - Oscilloscope screenshots
  - Frequency spectrum analysis (if available)

### Deliverables
- [ ] I2S transmitter module complete
- [ ] Tone generator working
- [ ] Audio output confirmed (oscilloscope, speaker)
- [ ] Photos/screenshots of oscilloscope waveforms
- [ ] Audio quality report

### Milestone Review
**Criteria for proceeding to Week 4**:
- ✓ 1 kHz tone clearly audible and visible on scope
- ✓ I2S timing correct (BCLK, LRCK, DATA)
- ✓ No audio artifacts or distortion
- ✓ Both audio channels working

---

## WEEK 4: ECG Sample Upsampler & ECG Audio Output

### Goals
- ECG samples converted to audio format
- Can output ECG waveform via audio jack
- ECG recognizable on oscilloscope

### Tasks

#### Day 1-2: ECG Data Preparation
- [ ] **Obtain MIT-BIH dataset samples**
  - Download from PhysioNet or use Kaggle dataset
  - Select representative samples:
    - Normal sinus rhythm
    - Premature Ventricular Contraction (PVC)
    - Atrial Fibrillation (AFib)
- [ ] **Create Python conversion script**: `ecg_to_mif.py`
  ```python
  def convert_to_12bit_mif(ecg_signal, output_file):
      # Normalize to [-1, 1]
      normalized = (ecg_signal - np.mean(ecg_signal)) / np.std(ecg_signal)
      normalized = np.clip(normalized, -1, 1)
      
      # Scale to 12-bit signed
      scaled = (normalized * 2047).astype(int)
      scaled = np.clip(scaled, -2048, 2047)
      
      # Generate .mif file for Quartus
      with open(output_file, 'w') as f:
          f.write("WIDTH=12;\nDEPTH=360;\n")
          f.write("ADDRESS_RADIX=DEC;\nDATA_RADIX=HEX;\n")
          f.write("CONTENT BEGIN\n")
          for i, val in enumerate(scaled):
              hex_val = val & 0xFFF
              f.write(f"    {i} : {hex_val:03X};\n")
          f.write("END;\n")
  ```
- [ ] **Generate .mif files**
  - normal_ecg.mif
  - pvc_ecg.mif
  - afib_ecg.mif

#### Day 3-4: Sample Upsampler Implementation
- [ ] **Implement `sample_upsampler.vhd`**
  ```vhdl
  constant UPSAMPLE_RATIO : integer := 133;
  
  -- Hold each ECG sample for 133 audio frames
  process(clk_48khz)
      if sample_tick_sync = '1' then
          held_sample <= ecg_sample;
          hold_count <= 0;
      elsif hold_count < UPSAMPLE_RATIO-1 then
          hold_count <= hold_count + 1;
      end if;
      
      -- Output to I2S (pad 12-bit to 16-bit)
      audio_out <= held_sample & "0000";
  end process;
  ```
- [ ] **Write testbench**
  - Input test ECG samples at 360 Hz
  - Verify output at 48 kHz
  - Check hold duration (133 cycles)
  - Verify padding to 16-bit

#### Day 5-6: ECG Memory + Integration
- [ ] **Implement `ecg_memory.vhd`**
  - Use M9K with .mif file initialization
  - 3 waveforms at base addresses (0, 360, 720)
- [ ] **Implement `ecg_sample_generator.vhd`**
  - Address counter with mode selection
  - Sample latching on sample_tick
- [ ] **Integrate**: Memory → Sample Gen → Upsampler → I2S → WM8731

#### Day 7: First ECG Audio Output Test
- [ ] **Program DE2-115 with complete audio pipeline**
  - Connect 3.5mm output to oscilloscope
  - Play Normal ECG waveform
  - **VERIFY**: ECG pattern visible on oscilloscope (not just 1 kHz tone!)
  - Should see characteristic ECG features: P-wave, QRS complex, T-wave
- [ ] **Test all 3 waveforms**
  - Normal: Regular pattern
  - PVC: Wide QRS, irregular
  - AFib: Chaotic baseline
- [ ] **Document waveforms**
  - Take oscilloscope screenshots of all 3 types
  - Compare to original MIT-BIH data visually

### Deliverables
- [ ] Python script for ECG→MIF conversion
- [ ] 3 ECG waveforms in .mif format
- [ ] ECG memory module working
- [ ] Sample upsampler module working
- [ ] **ECG waveforms outputting via audio (verified on oscilloscope)**
- [ ] Oscilloscope captures of all 3 ECG types

### Milestone Review
**Criteria for proceeding to Week 5**:
- ✓ Can output all 3 ECG waveforms via audio
- ✓ Waveforms recognizable on oscilloscope
- ✓ Sample rate timing correct (360 Hz base rate)
- ✓ Audio upsampling working (48 kHz I2S)

---

## WEEK 5: VGA Timing & Display Foundation

### Goals
- VGA timing generator working
- Can display test pattern on monitor
- Foundation for ECG rendering

### Tasks

#### Day 1-3: VGA Timing Generator
- [ ] **Implement `vga_timing_generator.vhd`**
  ```vhdl
  -- 640×480 @ 60Hz timing
  -- Use 25 MHz clock from PLL c1 output
  constant H_DISPLAY : integer := 640;
  constant H_FPORCH  : integer := 16;
  constant H_SYNC    : integer := 96;
  constant H_BPORCH  : integer := 48;
  constant H_TOTAL   : integer := 800;
  -- Similar for vertical...
  ```
- [ ] **Write `tb_vga_timing.vhd`**
  - Verify horizontal counter: 0→799→0
  - Verify vertical counter: 0→524→0
  - Measure hsync pulse width (96 pixels)
  - Measure vsync pulse width (2 lines)
  - Verify display_on region (640×480)
  - Check sync polarities (negative)

#### Day 4-5: VGA Test Pattern
- [ ] **Implement `vga_test_pattern.vhd`**
  - Color bars (8 vertical stripes)
  - Use 4-bit RGB for DE2-115 (better than 1-bit)
  ```vhdl
  -- Example colors (R G B in hex)
  White:   x"F" x"F" x"F"
  Yellow:  x"F" x"F" x"0"
  Cyan:    x"0" x"F" x"F"
  Green:   x"0" x"F" x"0"
  Magenta: x"F" x"0" x"F"
  Red:     x"F" x"0" x"0"
  Blue:    x"0" x"0" x"F"
  Black:   x"0" x"0" x"0"
  ```
- [ ] **Create test top-level**: `vga_test_top.vhd`
  - Instantiate PLL (for 25 MHz)
  - Instantiate vga_timing_generator
  - Instantiate vga_test_pattern

#### Day 6-7: VGA Hardware Test
- [ ] **Update QSF with VGA pins**
  ```tcl
  # VGA pins for DE2-115
  set_location_assignment PIN_F11 -to vga_hs
  set_location_assignment PIN_G13 -to vga_vs
  # R[3:0], G[3:0], B[3:0] pins...
  ```
- [ ] **Synthesize and program**
  - Check resource usage
  - Review timing analysis
- [ ] **Connect VGA monitor**
  - Verify color bars display
  - Check for stability (no flickering)
  - Take photo for documentation

### Deliverables
- [ ] VGA timing generator tested
- [ ] Test pattern displaying on monitor
- [ ] QSF file with VGA pin assignments
- [ ] Photos of color bars on monitor
- [ ] Timing analysis report

### Milestone Review
**Criteria for proceeding to Week 6**:
- ✓ VGA test pattern displays correctly
- ✓ No timing violations
- ✓ Stable display (60 Hz refresh)

---

## WEEK 6: VGA ECG Rendering & Simultaneous VGA+Audio

### Goals
- Display ECG waveform on VGA
- VGA and audio running simultaneously
- Smooth scrolling visualization

### Tasks

#### Day 1-3: VGA ECG Renderer
- [ ] **Implement `ecg_vga_renderer.vhd`**
  - Waveform buffer (640 × 12-bit dual-port RAM)
  - Write side: 50 MHz (on sample_tick)
  - Read side: 25 MHz (VGA pixel clock)
  - Y-coordinate mapping: `y = 240 - (sample / 10)`
  - Pixel generator: draw green if at waveform Y
- [ ] **Write testbench**
  - Simulate waveform buffer writes
  - Verify Y-coordinate calculation
  - Test edge cases (max/min values)

#### Day 4-5: Full Integration (VGA + Audio)
- [ ] **Create complete top-level**: `ecg_system_top.vhd`
  - Instantiate: PLL, memory, sample generator, VGA controller, audio controller
  - Wire all modules together
  - Add control logic (mode selection, playback enable)
- [ ] **Update QSF with all pins**
  - VGA pins
  - Audio pins
  - Switch pins
  - Button pins
  - LED pins

#### Day 6-7: Simultaneous VGA & Audio Test
- [ ] **Program DE2-115 with complete system**
  - Connect VGA monitor
  - Connect 3.5mm to oscilloscope
- [ ] **Verify both outputs working**
  - **VGA**: Scrolling ECG waveform visible
  - **Audio**: ECG pattern on oscilloscope
  - **Timing**: Both synchronized to same 360 Hz source
- [ ] **Test all 3 waveforms**
  - Normal: See on VGA + oscilloscope
  - PVC: Verify abnormal pattern visible on both
  - AFib: Verify chaotic pattern on both
- [ ] **Long-run test**
  - Let system run for 1+ hours
  - Check for drift or stability issues

### Deliverables
- [ ] VGA renderer module complete
- [ ] Complete system with VGA + audio working
- [ ] Photos: VGA display showing ECG
- [ ] Oscilloscope traces: audio output
- [ ] Stability test report (long-run results)

### Milestone Review
**Criteria for proceeding to Week 7**:
- ✓ VGA displays ECG clearly
- ✓ Audio outputs ECG pattern
- ✓ Both work simultaneously without interference
- ✓ Can switch between 3 waveforms
- ✓ System stable for extended operation

---

## WEEK 7: User Interface & LED Enhancements

### Goals
- User can control system via switches/buttons
- LEDs show comprehensive status
- Polished user experience

### Tasks

#### Day 1-2: Button Debouncer & UI Controller
- [ ] **Implement `button_debouncer.vhd`**
  - 50ms debounce time
  - Edge detection for toggle behavior
- [ ] **Implement `user_interface_controller.vhd`**
  - Switch inputs (mode selection)
  - Button input (playback toggle)
  - LED outputs:
    - LEDR[1:0]: Mode
    - LEDR[2]: Playing status
    - LEDR[3]: Audio active
    - LEDR[17:4]: Audio level meter
    - LEDG[8:0]: Sample counter (optional)

#### Day 3-4: Audio Level Meter
- [ ] **Implement audio level visualization on LEDs**
  ```vhdl
  -- Map ECG amplitude to LED bar graph
  -- LEDR[17:4] shows real-time signal strength
  if abs(ecg_sample) > threshold_14 then LEDR[17] <= '1';
  if abs(ecg_sample) > threshold_13 then LEDR[16] <= '1';
  -- ... down to LEDR[4]
  ```
- [ ] **Test with different waveforms**
  - Normal: Moderate LED activity
  - PVC: High LED activity (large amplitude)
  - AFib: Varying LED activity

#### Day 5-7: Full System Polish
- [ ] **Add VGA enhancements** (optional, if time)
  - Grid lines (baseline at Y=240)
  - Mode label in corner
  - Sample counter display
- [ ] **Complete system test**
  - All features working together
  - Smooth user experience
  - Professional-looking demo
- [ ] **Create user manual**
  - How to operate the system
  - What each control does
  - LED indicator meanings

### Deliverables
- [ ] User interface module complete
- [ ] All LEDs functional and meaningful
- [ ] Polished, demo-ready system
- [ ] User manual / operation guide
- [ ] Demo video (for backup)

### Milestone Review
**Criteria for proceeding to Week 8**:
- ✓ User can easily control system
- ✓ LEDs provide clear status feedback
- ✓ System is polished and demo-ready
- ✓ VGA + Audio + UI all working together

---

## WEEK 8: Two-Board Integration & Final Demo

### Goals
- DE2-115 connected to Spartan-3E CNN board
- End-to-end ECG classification working
- Final demo rehearsed and ready

### Tasks

#### Day 1-2: Integration Planning Meeting
- [ ] **Meet with CNN team (Ayoub, others)**
  - Review Spartan-3E ADC capabilities
  - Agree on audio signal levels (voltage)
  - Discuss downsampling approach (48 kHz → 360 Hz)
  - Plan physical setup for demo
- [ ] **Create integration test plan**
  - Define test vectors (known ECG → expected classification)
  - List measurements to take (SNR, error rate, latency)
  - Create troubleshooting checklist

#### Day 3-4: Audio Cable Connection
- [ ] **Physical connection**
  - DE2-115 Line Out → 3.5mm cable → Spartan-3E Line In
  - Use short cable first (1 meter)
  - Verify cable quality (continuity test)
- [ ] **Signal integrity measurement**
  - Oscilloscope at DE2-115 output
  - Oscilloscope at Spartan-3E input
  - Compare waveforms (check attenuation, noise)
  - Measure SNR (signal-to-noise ratio)
- [ ] **Adjust if needed**
  - Adjust WM8731 gain
  - Try different cable if noisy
  - Add ferrite beads if RF interference

#### Day 5-6: End-to-End Classification Testing
- [ ] **Test Normal ECG**
  - Select Normal on DE2-115 (SW[1:0] = 00)
  - Verify waveform on VGA
  - Verify audio output on oscilloscope
  - Check CNN board classification → expect "Normal"
  - Display result on DE2-115 LEDs
- [ ] **Test PVC ECG**
  - Select PVC (SW = 01)
  - Verify on VGA + oscilloscope
  - Check CNN → expect "PVC"
- [ ] **Test AFib ECG**
  - Select AFib (SW = 10)
  - Verify on VGA + oscilloscope
  - Check CNN → expect "AFib"
- [ ] **Record results**
  - Classification accuracy for each type
  - Latency measurements
  - Any errors or misclassifications

#### Day 7: Final Demo Preparation
- [ ] **Practice demo script**
  - Opening: Show both boards, explain system
  - Demo 1: Normal ECG → classification
  - Demo 2: PVC → classification
  - Demo 3: AFib → classification
  - Highlight: VGA display, audio transmission, LED feedback
- [ ] **Prepare contingencies**
  - Video backup if hardware fails
  - Spare audio cable
  - Spare VGA cable
  - Simulation screenshots as fallback
- [ ] **Create demo slides** (if needed beyond mid-term slides)
- [ ] **Final system check**
  - All connections secure
  - All features working
  - Demo flow smooth (< 5 minutes for full demo)

### Deliverables
- [ ] Two-board system operational
- [ ] End-to-end classification verified
- [ ] Test results documented (accuracy, latency)
- [ ] Demo script and contingency plans
- [ ] Final demo video recording
- [ ] Complete project documentation

### Final Milestone Review
**Criteria for successful completion**:
- ✓ Both boards communicate via audio
- ✓ CNN correctly classifies all 3 waveform types
- ✓ VGA display working
- ✓ User interface intuitive
- ✓ System demonstrates reliably
- ✓ Documentation complete

---

## RISK MITIGATION STRATEGIES

### Risk 1: Audio Codec Configuration Fails
**Symptoms**: No audio output, I2C errors, codec not responding  
**Debug Steps**:
1. Verify I2C timing with logic analyzer
2. Check ACK pulses from WM8731
3. Verify I2C address (0x34 for WM8731)
4. Try slower I2C clock (100 kHz instead of 400 kHz)
5. Use Altera reference design as template

**Fallback**: Manual I2C bit-banging, or use pre-configured audio example

### Risk 2: I2S Timing Issues
**Symptoms**: Distorted audio, no audio, intermittent output  
**Debug Steps**:
1. Verify BCLK frequency (3.072 MHz)
2. Verify LRCK frequency (48 kHz)
3. Check data alignment (MSB first, correct timing)
4. Compare with I2S specification timing diagrams
5. Use logic analyzer to capture I2S bus

**Fallback**: Use Altera I2S transmitter IP core

### Risk 3: Audio Signal Quality Poor
**Symptoms**: Noisy audio, ECG not recognizable, CNN errors  
**Debug Steps**:
1. Measure SNR with audio analyzer
2. Try shorter cable
3. Use shielded cable
4. Adjust WM8731 gain settings
5. Check for ground loops (oscilloscope DC coupling)

**Fallback**: Add analog filtering, or use digital GPIO if audio unusable

### Risk 4: PLL Lock Failures
**Symptoms**: Clocks unstable, system crashes, intermittent operation  
**Debug Steps**:
1. Monitor PLL locked signal
2. Check PLL bandwidth settings
3. Verify input clock is stable (50 MHz)
4. Try different PLL parameters
5. Add reset delay after PLL lock

**Fallback**: Use clock dividers instead of PLL (less precise but simpler)

### Risk 5: Two-Board Synchronization
**Symptoms**: CNN receives wrong samples, classification random  
**Debug Steps**:
1. Verify sample rate on both boards (oscilloscope)
2. Add sync pulse or frame marker in audio
3. Test with known test vector
4. Check ADC sampling on CNN board
5. Coordinate timing with team

**Fallback**: Add handshake protocol or use frame synchronization tone

### Risk 6: VGA + Audio Resource Contention
**Symptoms**: VGA flickers, audio drops out, timing violations  
**Debug Steps**:
1. Review TimeQuest timing analysis
2. Check for critical paths
3. Add pipeline stages if needed
4. Verify dual-port RAM timing
5. Monitor resource utilization

**Fallback**: Reduce VGA refresh rate or audio sample rate

---

## WEEKLY CHECKPOINT FORMAT

At end of each week, complete this checklist:

### Week N Checkpoint
**Date**: [Fill in]  
**Completed Tasks**: [X/Y]  
**Simulation Tests Passing**: [X/Y]  
**Hardware Tests Passing**: [X/Y]

**What Worked Well**:
- [List successes]

**What Didn't Work**:
- [List problems encountered]

**Solutions Implemented**:
- [How problems were solved]

**Carryover to Next Week**:
- [Incomplete tasks]

**Risks Identified**:
- [New risks discovered]

**Team Coordination**:
- [Meetings held, decisions made with CNN team]

**Two-Board Integration Status**:
- [Progress on inter-board communication]

---

## SUCCESS CRITERIA SUMMARY

### Minimum Viable Product (Week 8)
Must demonstrate:
- ✓ DE2-115 displays ECG on VGA
- ✓ Audio output measurable on oscilloscope
- ✓ User can select 3 waveforms
- ✓ Audio signal reaches CNN board (via 3.5mm cable)
- ✓ CNN can classify at least one waveform type correctly

### Full Feature Product (Week 8)
Should also have:
- ✓ Smooth VGA scrolling display
- ✓ Clean audio transmission (CNN classifies all 3 types)
- ✓ Pause/resume control working
- ✓ LED status indicators (mode + audio level meter)
- ✓ Both boards operating reliably
- ✓ Classification results displayed on DE2-115

### Stretch Goals (if time permits)
Nice to have:
- ○ Line-drawn waveform on VGA (smoother trace)
- ○ Heart rate calculation from R-peaks
- ○ Real-time audio level meter on LED bar graph
- ○ Classification confidence displayed on VGA
- ○ Waveform statistics on 7-segment displays

---

## RESOURCE ALLOCATION

### Time Budget (8 weeks × 7 days = 56 days)
- Audio development: 14 days (25%)
- VGA development: 10 days (18%)
- Integration: 14 days (25%)
- Testing: 10 days (18%)
- Documentation: 6 days (10%)
- Buffer: 2 days (4%)

### Lab Time Required
- Weeks 1-4: Heavy lab time (audio codec testing, oscilloscope work)
- Weeks 5-6: VGA testing
- Weeks 7-8: Two-board integration (coordinate with CNN team)
- Book COE758 lab in advance, coordinate schedules

### Equipment Needed
- DE2-115 board (Board 1)
- Spartan-3E board (Board 2 - CNN team)
- VGA monitor
- Oscilloscope (critical for audio verification)
- Audio analyzer (optional but helpful)
- 3.5mm audio cables (multiple for testing)
- Logic analyzer (for I2C/I2S debugging)

### External Dependencies
- **Ayoub (CNN team)**: 
  - ADC interface spec by Week 3
  - Spartan-3E board ready Week 6
  - Integration testing Week 7-8
- **Malcolm/Pierre (SoC team)**: 
  - May share lab resources
  - Coordinate testing schedules
- **Lab Equipment**: 
  - Reserve oscilloscope time
  - Ensure audio cables available

---

## DELIVERABLES CHECKLIST

### Code Deliverables
- [ ] All VHDL source files (~12 modules with audio)
  - Audio modules: i2c_master, i2s_transmitter, sample_upsampler, wm8731_config, audio_output_controller
  - VGA modules: vga_timing_generator, ecg_vga_renderer
  - Core modules: ecg_memory, sample_rate_controller, ecg_sample_generator, user_interface_controller
  - Top-level: ecg_system_top, pll_50to48 (MegaWizard)
- [ ] All testbench files
- [ ] QSF constraint file (pin assignments)
- [ ] SDC timing constraints file
- [ ] Quartus project file (.qpf, .qsf)
- [ ] Build script / instructions

### Data Deliverables
- [ ] ECG waveform data (3 types, 360 samples each)
- [ ] .mif files for Quartus memory initialization
- [ ] Python conversion script (CSV → MIF)
- [ ] Test vectors for verification

### Documentation Deliverables
- [ ] README.md (build & usage for DE2-115)
- [ ] Technical reference document (this document)
- [ ] System architecture document
- [ ] Module specifications
- [ ] **Audio interface specification** (for CNN team)
- [ ] **Two-board integration guide**
- [ ] Test plan & results
- [ ] User guide (operation instructions)

### Demo Deliverables
- [ ] Working two-board hardware demo
- [ ] Demo video (backup recording)
- [ ] Demo script / presentation
- [ ] Results analysis (classification accuracy)
- [ ] Oscilloscope captures (audio waveforms)
- [ ] Photos (VGA display, physical setup)

### Audio-Specific Deliverables
- [ ] I2C transaction timing diagrams
- [ ] I2S signal timing diagrams
- [ ] Audio signal analysis (frequency spectrum)
- [ ] SNR measurements
- [ ] Audio-to-digital conversion guide (for CNN team)

---

## SPECIAL CONSIDERATIONS FOR AUDIO INTERFACE

### Testing Audio Output

#### Equipment Setup
1. **Oscilloscope Connection**
   - Channel 1: Left audio (tip)
   - Channel 2: Right audio (ring)
   - Ground: Sleeve
   - AC coupling recommended

2. **Expected Waveform**
   - Should look like ECG trace
   - Frequency: Varies with ECG features (P, QRS, T waves)
   - Amplitude: ~1-2V peak-to-peak (adjustable via WM8731 gain)

3. **Measurements to Take**
   - Peak-to-peak voltage
   - Frequency content (FFT if oscilloscope has it)
   - Noise floor
   - SNR calculation

#### Audio Signal Verification Checklist
- [ ] Waveform shape matches ECG trace
- [ ] All three waveforms distinguishable
- [ ] No clipping or saturation
- [ ] No DC offset (should be centered at 0V)
- [ ] No high-frequency noise (clean signal)
- [ ] Frequency spectrum shows <200 Hz content (expected for ECG)

### Coordinating with CNN Team

#### Information to Share (Week 3)
- Audio signal levels (voltage range)
- Sample format (12-bit signed, padded to 16-bit)
- Upsampling ratio (133x)
- Sample rate (48 kHz audio, 360 Hz effective)
- Cable type (standard 3.5mm stereo)
- Test waveforms (.csv files for verification)

#### Integration Test Plan (Week 7)
1. **Loopback test on DE2-115 first**
   - Audio out → audio in on same board (if possible)
   - Verify signal quality
2. **One-way test**
   - DE2-115 → Spartan-3E
   - Measure signal at Spartan-3E input
3. **Classification test**
   - Feed known Normal → expect "Normal" output
   - Feed known PVC → expect "PVC" output
   - Feed known AFib → expect "AFib" output
4. **Full system test**
   - User selects on DE2-115
   - CNN classifies on Spartan-3E
   - Result displayed back on DE2-115

---

## CONTINGENCY PLANS

### If Audio Interface Fails Completely
**Plan B**: Use GPIO connection instead
- Requires rewiring
- Need ribbon cable (12 pins minimum)
- Lose educational value of audio codec
- But ensures project completion

**Implementation Time**: 2-3 days to switch

### If VGA Has Issues
**Plan C**: Focus on audio demonstration
- Skip VGA, use LEDs only for visualization
- Oscilloscope shows ECG waveform
- Still demonstrates core functionality

**Implementation Time**: 0 days (just disable VGA)

### If CNN Board Not Ready
**Plan D**: Simulate CNN on DE2-115
- Create simple behavioral CNN model in VHDL
- Test full pipeline on single board
- Replace with real CNN when ready

**Implementation Time**: 3-4 days

---

## RESOURCE OPTIMIZATION TIPS

### If Running Out of Time
**Priority Order** (complete in this sequence):
1. ✓ Audio output working (core functionality)
2. ✓ Basic VGA display (test pattern or static ECG)
3. ✓ User interface (mode selection)
4. ✓ Two-board connection (basic audio transmission)
5. ○ Scrolling VGA (enhancement)
6. ○ LED level meter (enhancement)
7. ○ Classification result display (if CNN ready)

### If Running Out of Resources (unlikely on DE2-115)
- Use distributed RAM instead of M9K if needed
- Reduce waveform buffer size (640 → 320 samples)
- Simplify VGA (lower resolution or monochrome)
- Share clock (use 48 MHz for everything with dividers)

---

**Document Version**: 2.0 (DE2-115 Audio Interface)  
**Created**: November 28, 2025  
**For**: COE 70B Implementation (Winter 2026)  
**Platform**: DE2-115 + Spartan-3E Two-Board System  
**Status**: Ready to Execute
