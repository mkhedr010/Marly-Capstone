# ECG Simulation Component - Implementation Roadmap for COE 70B

## Document Overview
This roadmap provides a detailed, week-by-week implementation plan for building the ECG Simulation & Visualization Component during the COE 70B term (8 weeks).

---

## IMPLEMENTATION PHILOSOPHY

### Development Approach
1. **Bottom-up**: Build and test individual modules first
2. **Incremental**: Add one feature at a time, verify before proceeding
3. **Test-driven**: Write testbenches before/alongside implementation
4. **Simulation-first**: Verify in simulation before hardware
5. **Risk-first**: Tackle hardest problems early (VGA timing, clock domains)

### Success Metrics
- ✓ Each module passes testbench
- ✓ Integration tests pass in simulation
- ✓ Resource usage < 80% of available
- ✓ Hardware demo works on first board programming attempt (after simulation)

---

## WEEK 1: Project Setup & Clock Management

### Goals
- Development environment configured
- Clock infrastructure working
- Foundation for all other modules

### Tasks

#### Day 1-2: Environment Setup
- [ ] **Install ISE Design Suite** (Xilinx 14.7 for Spartan-3E)
  - Verify synthesis tools work
  - Test with simple blink example
- [ ] **Create project directory structure**:
  ```
  ecg_simulation/
  ├── rtl/           (VHDL source files)
  ├── tb/            (Testbenches)
  ├── data/          (ECG waveform data)
  ├── sim/           (Simulation results)
  ├── synthesis/     (ISE project files)
  ├── constraints/   (UCF files)
  └── docs/          (Documentation)
  ```
- [ ] **Set up version control** (Git)
  - Initialize repository
  - Add .gitignore for ISE files
  - Create README with build instructions

#### Day 3-4: Clock Divider Module
- [ ] **Implement `clk_divider.vhd`**
  ```vhdl
  -- Simple divide-by-2 for 25 MHz from 50 MHz
  entity clk_divider is
      port (
          clk_in   : in  std_logic;
          reset_n  : in  std_logic;
          clk_out  : out std_logic
      );
  end clk_divider;
  ```
- [ ] **Write `tb_clk_divider.vhd`**
  - Verify output frequency is exactly half input
  - Check 50% duty cycle
  - Test reset behavior
- [ ] **Simulate and verify**
  - Run for at least 1000 cycles
  - Measure period with waveform viewer

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
- [ ] ISE project configured and building
- [ ] Clock divider working (25 MHz verified)
- [ ] Sample rate controller working (360 Hz verified)
- [ ] Both modules have passing testbenches
- [ ] Documentation: module descriptions, simulation results

### Milestone Review
**Criteria for proceeding to Week 2**:
- ✓ All testbenches pass
- ✓ Timing analysis clean (no setup/hold violations)
- ✓ Waveforms match expected behavior

---

## WEEK 2: VGA Timing & Display Foundation

### Goals
- VGA timing generator working perfectly
- Able to display test pattern on monitor
- Understand VGA timing in depth

### Tasks

#### Day 1-3: VGA Timing Generator
- [ ] **Implement `vga_timing_generator.vhd`**
  ```vhdl
  -- 640×480 @ 60Hz timing
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
  - Check sync polarities (both negative)

#### Day 4-5: Simple VGA Test Pattern
- [ ] **Implement `vga_test_pattern.vhd`**
  - Color bars (8 vertical stripes)
  - Or checkerboard pattern
  - Simple combinational logic based on pixel_x, pixel_y
- [ ] **Create top-level for hardware test**: `vga_test_top.vhd`
  - Instantiate clk_divider
  - Instantiate vga_timing_generator
  - Instantiate vga_test_pattern
  - Map to actual VGA pins

#### Day 6-7: First Hardware Test
- [ ] **Create UCF file**: `spartan3e_starter.ucf`
  - Clock pin (50 MHz oscillator)
  - VGA pins (hsync, vsync, RGB)
  - Reset button
  - Reference Spartan-3E Starter Kit manual
- [ ] **Synthesize and implement**
  - Check resource usage report
  - Review timing report
  - Generate bitstream
- [ ] **Program FPGA**
  - Connect VGA monitor
  - Verify test pattern displays correctly
  - Take photo for documentation

### Deliverables
- [ ] VGA timing generator fully tested
- [ ] Test pattern displaying on actual monitor
- [ ] UCF file with correct pin mappings
- [ ] Photos/screenshots of working display
- [ ] Timing analysis report

### Milestone Review
**Criteria for proceeding to Week 3**:
- ✓ VGA test pattern displays correctly on monitor
- ✓ No timing violations in synthesis report
- ✓ Stable display (no flickering or artifacts)

---

## WEEK 3: ECG Data Management

### Goals
- ECG waveforms stored in BRAM
- Sample generation working
- Data pipeline functional

### Tasks

#### Day 1-2: ECG Data Preparation
- [ ] **Obtain MIT-BIH dataset samples**
  - Download from PhysioNet or use Kaggle dataset
  - Select representative samples:
    - Normal sinus rhythm
    - Premature Ventricular Contraction (PVC)
    - Atrial Fibrillation (AFib)
- [ ] **Create Python conversion script**: `ecg_converter.py`
  ```python
  import numpy as np
  
  def convert_to_12bit(ecg_signal):
      # Normalize to [-1, 1]
      normalized = (ecg_signal - np.mean(ecg_signal)) / np.std(ecg_signal)
      normalized = np.clip(normalized, -1, 1)
      
      # Scale to 12-bit signed
      scaled = (normalized * 2047).astype(int)
      scaled = np.clip(scaled, -2048, 2047)
      
      # Convert to hex
      hex_values = [(x & 0xFFF) for x in scaled]
      return hex_values
  ```
- [ ] **Generate VHDL array constants**
  - Output format: `x"000", x"012", ...`
  - Create one array per waveform
  - Verify 360 samples each

#### Day 3-4: ECG Memory Module
- [ ] **Implement `ecg_memory.vhd`**
  ```vhdl
  type ram_type is array (0 to 1079) of std_logic_vector(11 downto 0);
  -- 1080 = 3 waveforms × 360 samples
  
  constant ECG_ROM : ram_type := (
      -- Normal: 0-359
      x"000", x"012", ...,
      -- PVC: 360-719
      x"100", x"112", ...,
      -- AFib: 720-1079
      x"200", x"212", ...
  );
  ```
- [ ] **Write `tb_ecg_memory.vhd`**
  - Read all addresses sequentially
  - Verify data matches expected values
  - Check BRAM inference in synthesis report

#### Day 5-7: Sample Generator Module
- [ ] **Implement `ecg_sample_generator.vhd`**
  - Address counter (0-359, loops)
  - Base address calculation from mode:
    - mode=00 → base=0
    - mode=01 → base=360
    - mode=10 → base=720
  - Sample latching on sample_tick
- [ ] **Write `tb_ecg_sample_generator.vhd`**
  - Test all three modes
  - Verify address wrapping
  - Check sample output timing
  - Verify enable control (pause functionality)

### Deliverables
- [ ] Python script for ECG data conversion
- [ ] 3 ECG waveforms in VHDL format (verified against source)
- [ ] ECG memory module with initialized data
- [ ] Sample generator module working
- [ ] Integration test: memory + sample generator

### Milestone Review
**Criteria for proceeding to Week 4**:
- ✓ Can read different waveforms by changing mode
- ✓ Sample rate is correct (360 Hz)
- ✓ Data values match original ECG signals

---

## WEEK 4: VGA Waveform Rendering

### Goals
- Display ECG waveform on VGA screen
- Scrolling visualization working
- Smooth real-time updates

### Tasks

#### Day 1-3: Waveform Buffer & Y-Mapping
- [ ] **Implement waveform buffer** (in `ecg_vga_renderer.vhd`)
  ```vhdl
  type waveform_buffer_type is array (0 to 639) of signed(11 downto 0);
  signal waveform_buffer : waveform_buffer_type := (others => (others => '0'));
  ```
- [ ] **Implement buffer write logic**
  - Triggered by sample_tick (50 MHz domain)
  - Circular index: 0→639→0
  - Store incoming ECG sample
- [ ] **Implement Y-coordinate mapper**
  ```vhdl
  function ecg_to_y(sample : signed(11 downto 0)) return integer is
      variable y : integer;
  begin
      y := 240 - (to_integer(sample) / 10);
      y := clip(y, 0, 479);
      return y;
  end function;
  ```
- [ ] **Write testbench for Y-mapping**
  - Test edge cases: max positive, max negative, zero
  - Verify clipping works

#### Day 4-5: VGA Renderer Integration
- [ ] **Implement pixel generator** (in `ecg_vga_renderer.vhd`)
  - On pixel clock (25 MHz domain)
  - Read waveform_buffer[pixel_x]
  - Calculate y_expected from sample
  - If pixel_y == y_expected: draw green pixel
  - Else: draw black pixel
- [ ] **Add grid lines** (optional enhancement)
  - Horizontal line at Y=240 (baseline)
  - Vertical lines every 64 pixels

#### Day 6-7: First ECG Display Test
- [ ] **Create `ecg_display_test_top.vhd`**
  - Integrate: clk_divider, vga_timing, ecg_memory, sample_gen, vga_renderer
  - Hardcode mode to "Normal" initially
  - Feed continuous sample stream
- [ ] **Synthesize and test on hardware**
  - Verify waveform appears on screen
  - Check if recognizable as ECG
  - Verify scrolling motion
  - Adjust Y-scaling if needed

### Deliverables
- [ ] VGA renderer module complete
- [ ] ECG waveform displaying on monitor
- [ ] Scrolling visualization working
- [ ] Video/photo of display for documentation

### Milestone Review
**Criteria for proceeding to Week 5**:
- ✓ ECG waveform clearly visible on VGA
- ✓ Scrolling is smooth (no tearing or flicker)
- ✓ Can identify P-waves, QRS complex, T-waves

---

## WEEK 5: User Interface & Mode Selection

### Goals
- User can select different waveforms
- Button controls playback
- LEDs show system status

### Tasks

#### Day 1-2: Button Debouncer
- [ ] **Implement `button_debouncer.vhd`**
  ```vhdl
  constant DEBOUNCE_TIME : integer := 2_500_000; -- 50ms @ 50MHz
  ```
- [ ] **Write testbench**
  - Simulate button bouncing (rapid toggling)
  - Verify output is stable after debounce time
  - Test edge detection

#### Day 3-4: User Interface Controller
- [ ] **Implement `user_interface_controller.vhd`**
  - Switch inputs (direct passthrough to ecg_mode)
  - Button with debouncing → toggle playback_enable
  - LED outputs:
    - LED[1:0] = ecg_mode
    - LED[2] = playback_enable
    - LED[3] = (reserved for CNN result)
- [ ] **Write testbench**
  - Test mode switching
  - Test playback toggle
  - Verify LED outputs

#### Day 5-7: Full System Integration
- [ ] **Create `ecg_system_top.vhd`** (complete top-level)
  - Instantiate all modules
  - Wire everything together
  - Add CNN interface outputs (stub for now)
- [ ] **Update UCF file**
  - Add switch pins
  - Add button pins
  - Add LED pins
- [ ] **Full system test on hardware**
  - Test switching between Normal/PVC/AFib
  - Test pause/resume
  - Verify LEDs indicate correct mode
  - Verify smooth transitions

### Deliverables
- [ ] User interface module complete
- [ ] Full system working on FPGA
- [ ] Can select and display all 3 waveforms
- [ ] Pause/resume functionality working
- [ ] User manual draft (how to operate)

### Milestone Review
**Criteria for proceeding to Week 6**:
- ✓ Can switch waveforms via switches
- ✓ Can pause/resume via button
- ✓ All LEDs working correctly
- ✓ System is stable and repeatable

---

## WEEK 6: CNN Interface & Integration

### Goals
- CNN interface module complete
- Ready to connect with Ayoub's CNN module
- Integration testing with team

### Tasks

#### Day 1-2: CNN Interface Module
- [ ] **Implement `cnn_interface.vhd`**
  ```vhdl
  entity cnn_interface is
      port (
          clk             : in  std_logic;
          reset_n         : in  std_logic;
          ecg_sample_in   : in  std_logic_vector(11 downto 0);
          sample_tick     : in  std_logic;
          -- CNN outputs
          ecg_sample_out  : out std_logic_vector(11 downto 0);
          sample_tick_out : out std_logic;
          sample_valid    : out std_logic
      );
  end cnn_interface;
  ```
- [ ] **Write testbench**
  - Verify sample registration
  - Check sample_tick passthrough
  - Verify sample_valid timing

#### Day 3-4: Team Integration Meeting
- [ ] **Meet with Ayoub (CNN team)**
  - Review interface specification together
  - Confirm signal names and timing
  - Discuss test vectors
  - Plan physical connection (GPIO pins)
- [ ] **Update UCF with GPIO assignments**
  - Reserve 12 pins for ecg_sample[11:0]
  - Reserve 1 pin for sample_tick
  - Reserve 1 pin for sample_valid
  - Reserve 2 pins for cnn_result (input from CNN)
  - Document pinout clearly

#### Day 5-7: Integration Testing
- [ ] **Create integration testbench**: `tb_cnn_integration.vhd`
  - Simulate CNN module (simple behavioral model)
  - Feed samples, verify CNN receives correct data
  - Test full pipeline: user selects waveform → displayed → sent to CNN
- [ ] **Physical connection test** (if CNN hardware ready)
  - Connect FPGAs via GPIO cables
  - Verify signal integrity with oscilloscope
  - Test data transfer
  - Verify CNN can classify waveforms

### Deliverables
- [ ] CNN interface module complete
- [ ] Integration specification document shared with team
- [ ] GPIO pinout documented
- [ ] Integration testbench passing
- [ ] Photos of physical setup (if connected)

### Milestone Review
**Criteria for proceeding to Week 7**:
- ✓ CNN interface follows agreed specification
- ✓ Sample stream timing verified
- ✓ Ready for physical connection to CNN module

---

## WEEK 7: Optimization & Testing

### Goals
- System optimization (performance, resources)
- Comprehensive testing
- Bug fixes and refinements

### Tasks

#### Day 1-2: Performance Analysis
- [ ] **Timing analysis**
  - Review critical paths from synthesis report
  - Ensure all timing constraints met
  - Add timing constraints if needed (SDC file)
- [ ] **Resource optimization**
  - Review utilization report
  - Optimize if using >50% of any resource
  - Consider pipelining critical paths if needed

#### Day 3-4: Enhanced Features (Optional)
Choose 1-2 to implement if time permits:
- [ ] **Option A: Classification result display**
  - Show CNN result on VGA (text or color indicator)
  - Requires character ROM or simple graphics
- [ ] **Option B: Better scrolling**
  - Line drawing between samples (Bresenham algorithm)
  - Smoother trace appearance
- [ ] **Option C: Waveform statistics**
  - Show heart rate on 7-segment display
  - Calculate from R-peak intervals

#### Day 5-7: Comprehensive Testing
- [ ] **Simulation test suite**
  - Run all testbenches
  - Create regression test script
  - Document any failures
- [ ] **Hardware test plan execution**
  - Test all switch combinations
  - Long-run test (24 hours if possible)
  - Temperature test (measure FPGA temp)
  - Power-cycle test (does it work after reset?)
- [ ] **Create test report**
  - Document all tests performed
  - List any issues found
  - Note any workarounds

### Deliverables
- [ ] Optimized design (timing clean, resources <50%)
- [ ] At least one enhanced feature working
- [ ] Complete test report
- [ ] Known issues document

### Milestone Review
**Criteria for proceeding to Week 8**:
- ✓ All critical functionality working
- ✓ System is stable and reliable
- ✓ Ready for final demo

---

## WEEK 8: Documentation & Final Demo

### Goals
- Complete documentation
- Final demo preparation
- Presentation ready

### Tasks

#### Day 1-2: Technical Documentation
- [ ] **Complete README.md**
  - Project overview
  - Build instructions
  - Usage instructions
  - Hardware requirements
- [ ] **Complete module documentation**
  - Block diagrams
  - Interface descriptions
  - Timing diagrams
- [ ] **Create user guide**
  - How to operate the system
  - What each waveform represents
  - Troubleshooting section

#### Day 3-4: Integration Documentation
- [ ] **CNN Integration Guide**
  - For Ayoub and team
  - Pin mapping table
  - Timing specifications
  - Test procedure
- [ ] **Create test vectors**
  - Sample ECG data files
  - Expected CNN outputs
  - Validation checklist

#### Day 5-6: Demo Preparation
- [ ] **Practice demo script**
  - Show waveform selection
  - Show pause/resume
  - Show CNN classification (if integrated)
  - Highlight technical features
- [ ] **Prepare backup plan**
  - Video recording of working system
  - Simulation screenshots
  - In case hardware fails during demo
- [ ] **Create demo slides** (if needed)
  - Key features
  - Technical highlights
  - Results and achievements

#### Day 7: Final Check
- [ ] **Complete system test**
  - Run through entire demo sequence
  - Verify all features work
  - Check all connections
- [ ] **Code cleanup**
  - Remove debug code
  - Add final comments
  - Format code consistently
  - Create Git release tag

### Deliverables
- [ ] Complete technical documentation
- [ ] User guide
- [ ] Integration guide for team
- [ ] Demo ready
- [ ] All source code cleaned and commented
- [ ] Git repository organized

### Final Milestone Review
**Criteria for successful completion**:
- ✓ All required features implemented
- ✓ System demonstrates reliably
- ✓ Documentation is complete
- ✓ Code is clean and well-commented
- ✓ Can explain all design decisions

---

## RISK MITIGATION STRATEGIES

### Risk 1: VGA Timing Issues
**Symptoms**: Flickering, no display, rolling image  
**Debug Steps**:
1. Verify pixel clock is exactly 25 MHz (measure with oscilloscope)
2. Check hsync/vsync polarities
3. Test with simple test pattern first
4. Verify counter wrap-around points
5. Use ChipScope to debug internal signals

**Fallback**: Use DCM to generate exact 25.175 MHz if divider isn't precise enough

### Risk 2: BRAM Initialization Problems
**Symptoms**: Wrong data read from memory, synthesis errors  
**Debug Steps**:
1. Verify initialization syntax matches ISE requirements
2. Check memory depth matches address range
3. Verify data width is correct (12 bits)
4. Test with small known dataset first
5. Read back all addresses in testbench

**Fallback**: Use distributed RAM instead of BRAM (less efficient but works)

### Risk 3: Clock Domain Crossing Issues
**Symptoms**: Metastability, random errors, system crashes  
**Debug Steps**:
1. Use dual-port RAM with separate clock domains
2. Add synchronizers for control signals
3. Verify in simulation with different clock phases
4. Use Xilinx constraints for CDC paths
5. Monitor with ChipScope

**Fallback**: Run entire system on single clock (slower VGA refresh)

### Risk 4: Sample Rate Drift
**Symptoms**: CNN reports timing issues, waveform speed changes  
**Debug Steps**:
1. Measure actual sample_tick period with oscilloscope
2. Verify divider counter wraps correctly
3. Check for integer overflow in calculations
4. Monitor over long time period (drift detection)

**Fallback**: Make divider value configurable via generic

### Risk 5: Physical Connection Problems
**Symptoms**: CNN doesn't receive data, signal integrity issues  
**Debug Steps**:
1. Check cable connections
2. Verify pin assignments match UCF
3. Measure signals with oscilloscope
4. Test with loopback first
5. Slow down data rate for testing

**Fallback**: Use UART or other serial protocol instead of parallel GPIO

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
- [Meetings held, decisions made]

---

## SUCCESS CRITERIA SUMMARY

### Minimum Viable Product (Week 8)
Must demonstrate:
- ✓ VGA displaying ECG waveform
- ✓ User can select 3 different waveforms
- ✓ Data streams to CNN interface
- ✓ System runs stably

### Full Feature Product (Week 8)
Should also have:
- ✓ Smooth scrolling display
- ✓ Pause/resume control
- ✓ LED status indicators
- ✓ Integration with CNN working
- ✓ Classification result visible

### Stretch Goals (if time permits)
Nice to have:
- ○ Line-drawn waveform (smoother)
- ○ Classification result on VGA
- ○ Heart rate calculation
- ○ Multiple color schemes
- ○ Waveform freeze/capture

---

## RESOURCE ALLOCATION

### Time Budget (8 weeks × 7 days = 56 days)
- Development: 40 days (70%)
- Testing: 8 days (15%)
- Documentation: 6 days (10%)
- Buffer: 2 days (5%)

### Lab Time Required
- Weeks 2, 4, 5, 6: Heavy lab time (VGA testing, integration)
- Book COE758 lab in advance
- Coordinate with team for shared resources

### External Dependencies
- **Ayoub** (CNN module): Interface spec by Week 3, integration Week 6
- **Malcolm/Pierre** (SoC team): Pin assignments, may share resources
- **Lab Equipment**: VGA monitor, oscilloscope, cables

---

## DELIVERABLES CHECKLIST

### Code Deliverables
- [ ] All VHDL source files (9 modules minimum)
- [ ] All testbench files
- [ ] UCF constraint file
- [ ] ISE project file
- [ ] Build script / instructions

### Data Deliverables
- [ ] ECG waveform data (3 types, 360 samples each)
- [ ] Python conversion script
- [ ] Test vectors for verification

### Documentation Deliverables
- [ ] README.md (build & usage)
- [ ] Technical reference document
- [ ] System architecture document
- [ ] Module specifications
- [ ] Integration guide (for CNN team)
- [ ] Test plan & results
- [ ] User guide

### Demo Deliverables
- [ ] Working hardware demo
- [ ] Demo video (backup)
- [ ] Demo script / presentation
- [ ] Results analysis

---

**Document Version**: 1.0  
**Created**: November 25, 2025  
**For**: COE 70B Implementation (Winter 2026)  
**Status**: Ready to Execute
