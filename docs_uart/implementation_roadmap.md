# ECG Simulation Component - Implementation Roadmap
## Spartan-3E with PC UART Streaming

## Document Overview
Detailed week-by-week implementation plan for building the UART-based ECG simulation component during COE 70B (8 weeks).

---

## IMPLEMENTATION PHILOSOPHY

### Development Approach
1. **UART First**: Get PC-to-FPGA communication working early (highest risk)
2. **Incremental**: Build modules one at a time, test thoroughly
3. **Parallel Development**: FPGA VHDL + Python PC app can be developed simultaneously
4. **Simulation Heavy**: Verify UART protocol in testbench before hardware
5. **VGA Last**: Reuse proven VGA design from docs/ folder

### Success Metrics
- ✓ UART receives data correctly (verified with LEDs)
- ✓ VGA displays smooth scrolling ECG
- ✓ CNN integration works
- ✓ System runs continuously without errors

---

## WEEK 1: UART Receiver Implementation

### Goals
- UART receiver module working
- Can receive data from PC
- Verified with test patterns

### Tasks

#### Day 1-2: Project Setup
- [ ] **Create ISE project**
  ```
  Project Name: ecg_simulation_uart
  Target Device: xc3s500e-fg320-4 (or your specific Spartan-3E)
  Top Module: ecg_system_top
  ```
- [ ] **Set up directory structure** (already created):
  ```
  src/          (VHDL files)
  src/tb/       (Testbenches)
  python/       (PC application)
  docs_uart/    (Documentation)
  ```
- [ ] **Add to .gitignore**:
  ```
  *.bgn
  *.bit
  *.bld
  *.drc
  *.ncd
  *.ngc
  *.ngd
  *.ngr
  *.pad
  *.par
  *.pcf
  *.prj
  *.ptwx
  *.syr
  *.twr
  *.unroutes
  _xmsgs/
  xlnx_auto_0_xdb/
  iseconfig/
  ```

#### Day 3-5: UART Receiver Module
- [ ] **Implement `uart_receiver.vhd`**
  - Baud rate generator (50MHz → 115200 baud)
  - 16× oversampling clock
  - State machine: IDLE → START → DATA[7:0] → STOP
  - 2-byte assembly into 12-bit sample
  - Error detection (framing errors)
- [ ] **Write `tb_uart_receiver.vhd`**
  - Simulate UART transmission
  - Send test bytes: 0xA3, 0x05 (expect 0x5A3)
  - Verify sample_valid pulse
  - Test frame errors (bad stop bit)
- [ ] **Simulate and verify**
  - Run ISim/ModelSim
  - Check timing (bit periods, sampling points)
  - Verify state transitions

#### Day 6-7: UART Hardware Test
- [ ] **Create simple test top-level**: `uart_test_top.vhd`
  - Instantiate uart_receiver
  - Display ecg_sample[11:0] on LEDs (show lower 4 bits cycling)
  - Display sample_valid on LED
  - Display uart_error on LED
- [ ] **Create UCF file**: `spartan3e_uart.ucf`
  - Clock, reset pins
  - UART RX pin (verify from board manual!)
  - LED pins
- [ ] **Write Python test script**: `uart_test.py`
  ```python
  import serial
  import time
  
  ser = serial.Serial('COM3', 115200)  # Adjust COM port
  
  # Send counting pattern
  for i in range(100):
      sample = i & 0xFFF
      byte1 = sample & 0xFF
      byte2 = (sample >> 8) & 0x0F
      ser.write(bytes([byte1, byte2]))
      time.sleep(0.01)  # 100 Hz for testing
      print(f"Sent: 0x{sample:03X}")
  ```
- [ ] **Test on hardware**
  - Program FPGA
  - Run Python script
  - Verify LEDs show counting pattern
  - Check sample_valid LED blinks

### Deliverables
- [ ] uart_receiver.vhd working and tested
- [ ] Python can send data to FPGA
- [ ] FPGA receives and displays correctly
- [ ] No frame errors in normal operation

### Milestone Review
**Criteria for proceeding to Week 2**:
- ✓ UART receives bytes correctly
- ✓ 12-bit assembly works (2 bytes → 1 sample)
- ✓ Python-FPGA communication verified
- ✓ Error detection functional

---

## WEEK 2: Clock Management & VGA Timing

### Goals
- VGA timing generator working
- Can display test pattern on monitor
- 25 MHz clock stable

### Tasks

#### Day 1-2: Clock Divider
- [ ] **Implement `clk_divider.vhd`**
  ```vhdl
  -- Simple divide-by-2: 50 MHz → 25 MHz
  process(clk_in)
  begin
      if rising_edge(clk_in) then
          if reset_n = '0' then
              clk_out_reg <= '0';
          else
              clk_out_reg <= not clk_out_reg;
          end if;
      end if;
  end process;
  clk_out <= clk_out_reg;
  ```
- [ ] **Write testbench**
  - Verify 50% duty cycle
  - Measure period (should be 40 ns)

#### Day 3-5: VGA Timing Generator
- [ ] **Implement `vga_timing_generator.vhd`**
  - Use specs from docs/technical_reference.md
  - H counter: 0-799, V counter: 0-524
  - Hsync pulse at 656-751, Vsync at 490-491
  - display_on when H<640 and V<480
- [ ] **Write `tb_vga_timing.vhd`**
  - Verify counter sequences
  - Check sync pulse widths
  - Measure frame time (~16.68 ms)

#### Day 6-7: VGA Test Pattern
- [ ] **Implement `vga_test_pattern.vhd`**
  - Color bars: 8 vertical stripes (White, Yellow, Cyan, Green, Magenta, Red, Blue, Black)
  - Simple combinational logic based on pixel_x
- [ ] **Create `vga_test_top.vhd`**
  - Integrate clk_divider, vga_timing, vga_test_pattern
- [ ] **Update UCF** with VGA pins
- [ ] **Test on hardware**
  - Connect VGA monitor
  - Verify color bars display
  - Take photo

### Deliverables
- [ ] VGA timing working (verified with test pattern)
- [ ] VGA test pattern on monitor
- [ ] UCF file complete
- [ ] Photos of test pattern

### Milestone Review
**Criteria for proceeding to Week 3**:
- ✓ VGA displays stable image
- ✓ Correct 640×480 @ 60Hz timing
- ✓ No flickering or artifacts

---

## WEEK 3: VGA ECG Renderer

### Goals
- Can display scrolling waveform
- Waveform buffer working
- Y-coordinate mapping correct

### Tasks

#### Day 1-3: Waveform Buffer & Y-Mapping
- [ ] **Implement waveform buffer in `ecg_vga_renderer.vhd`**
  ```vhdl
  type waveform_buffer_type is array (0 to 639) of signed(11 downto 0);
  signal waveform_buffer : waveform_buffer_type;
  signal write_ptr : integer range 0 to 639 := 0;
  ```
- [ ] **Implement buffer write logic**
  - Triggered by sample_valid (from UART)
  - Circular buffer (wraps at 639)
- [ ] **Implement Y-mapping function**
  ```vhdl
  function ecg_to_y(sample : signed(11 downto 0)) return integer is
      variable y : integer;
  begin
      y := 240 - (to_integer(sample) / 10);
      if y < 0 then y := 0; end if;
      if y > 479 then y := 479; end if;
      return y;
  end function;
  ```

#### Day 4-5: Pixel Generator
- [ ] **Implement pixel drawing logic**
  - Read waveform_buffer[pixel_x] during VGA scan
  - Calculate expected Y from sample value
  - If pixel_y matches, draw green pixel
  - Else draw black
- [ ] **Write testbench**
  - Simulate with known waveform
  - Verify Y-coordinates calculated correctly

#### Day 6-7: Integration Test with UART
- [ ] **Create integration top**: `ecg_display_test_top.vhd`
  - Instantiate: clk_divider, uart_receiver, vga_timing, ecg_vga_renderer
- [ ] **Python sends sine wave**:
  ```python
  import math
  for i in range(1000):
      sample = int(1000 * math.sin(2 * math.pi * i / 50))
      # Send via UART...
  ```
- [ ] **Test on hardware**
  - Verify sine wave appears on VGA
  - Check scrolling motion
  - Adjust Y-scaling if needed

### Deliverables
- [ ] ecg_vga_renderer.vhd complete
- [ ] Can display waveforms from UART
- [ ] Scrolling works smoothly
- [ ] Python-UART-VGA pipeline verified

### Milestone Review
**Criteria for proceeding to Week 4**:
- ✓ Waveform visible on VGA
- ✓ Scrolling smooth (no tearing)
- ✓ Y-scaling appropriate

---

## WEEK 4: Python ECG Streamer Application

### Goals
- Python app loads real ECG data
- Streams at correct rate (360 Hz)
- Can select different waveforms

### Tasks

#### Day 1-2: Data Loading Module
- [ ] **Create `ecg_loader.py`**
  ```python
  import pandas as pd
  import numpy as np
  
  class ECGLoader:
      def load_csv(self, filename):
          # Load MIT-BIH or Kaggle CSV
          df = pd.read_csv(filename)
          ecg_data = df['ECG'].values
          return ecg_data
          
      def normalize_and_convert(self, ecg_data):
          # Normalize to [-1, 1]
          normalized = (ecg_data - ecg_data.mean()) / ecg_data.std()
          normalized = np.clip(normalized, -1, 1)
          
          # Scale to 12-bit signed
          scaled = (normalized * 2047).astype(int)
          scaled = np.clip(scaled, -2048, 2047)
          
          return scaled
  ```

#### Day 3-4: UART Handler Module
- [ ] **Create `uart_handler.py`**
  ```python
  import serial
  
  class UARTHandler:
      def __init__(self, port='COM3', baud=115200):
          self.ser = serial.Serial(port, baud, timeout=1)
          
      def send_sample(self, sample):
          # Convert to unsigned 12-bit
          if sample < 0:
              sample = (1 << 12) + sample
          sample = sample & 0xFFF
          
          # Split into 2 bytes
          byte1 = sample & 0xFF
          byte2 = (sample >> 8) & 0x0F
          
          # Send
          self.ser.write(bytes([byte1, byte2]))
          
      def close(self):
          self.ser.close()
  ```

#### Day 5-6: Main Streaming Application
- [ ] **Create `ecg_streamer.py`**
  - Command-line interface (argparse)
  - Select waveform type
  - Select COM port
  - Set sample rate
  - Loop playback option
  - Statistics display (samples sent, time elapsed)
- [ ] **Create `requirements.txt`**
  ```
  pyserial==3.5
  numpy>=1.21.0
  pandas>=1.3.0
  ```
- [ ] **Create sample data files** (in python/data/):
  - normal_ecg.csv (360 samples)
  - pvc_ecg.csv (360 samples)
  - afib_ecg.csv (360 samples)

#### Day 7: End-to-End Test
- [ ] **Test complete pipeline**
  - Run Python with real ECG data
  - Verify appears correctly on VGA
  - Test all 3 waveform types
  - Verify recognizable ECG features

### Deliverables
- [ ] Complete Python application
- [ ] Sample ECG data files
- [ ] Python README with usage
- [ ] End-to-end test successful

### Milestone Review
**Criteria for proceeding to Week 5**:
- ✓ Python streams real ECG data
- ✓ FPGA displays it correctly on VGA
- ✓ All 3 waveforms (Normal, PVC, AFib) work
- ✓ ECG features recognizable

---

## WEEK 5: User Interface & CNN Integration

### Goals
- User can pause/resume
- LEDs show status
- CNN interface ready

### Tasks

#### Day 1-2: User Interface Controller
- [ ] **Implement `user_interface_controller.vhd`**
  - Button debouncing (50 ms)
  - Pause/resume toggle
  - LED control:
    - LED[0]: UART active (uart_rx toggling)
    - LED[1]: VGA displaying (always on)
    - LED[2]: System paused (button)
    - LED[3]: CNN result (if valid)
- [ ] **Write testbench**
  - Test button debouncing
  - Verify toggle behavior
  - Check LED outputs

#### Day 3-4: CNN Interface Module
- [ ] **Implement `cnn_interface.vhd`**
  ```vhdl
  entity cnn_interface is
      port (
          clk             : in  std_logic;
          reset_n         : in  std_logic;
          
          -- From UART/system
          ecg_sample_in   : in  std_logic_vector(11:0);
          sample_valid_in : in  std_logic;
          
          -- To CNN module (internal)
          cnn_sample      : out std_logic_vector(11:0);
          cnn_valid       : out std_logic;
          
          -- From CNN module
          cnn_result      : in  std_logic_vector(1:0);
          cnn_result_valid: in  std_logic
      );
  end cnn_interface;
  ```
- [ ] **Implementation**: Simple passthrough with optional buffering
- [ ] **Write testbench** (with behavioral CNN model)

#### Day 5-7: Top-Level Integration
- [ ] **Create `ecg_system_top.vhd`** (complete)
  - Instantiate all modules:
    - clk_divider
    - uart_receiver
    - vga_timing_generator
    - ecg_vga_renderer
    - user_interface_controller
    - cnn_interface
  - Wire everything together
  - Map to top-level ports
- [ ] **Update UCF** with all pins
- [ ] **Full system test**
  - Python streams ECG
  - VGA displays
  - LED[0] blinks (UART active)
  - Button pauses display

### Deliverables
- [ ] user_interface_controller.vhd complete
- [ ] cnn_interface.vhd complete
- [ ] ecg_system_top.vhd complete (full integration)
- [ ] UCF file complete
- [ ] Full system working on hardware

### Milestone Review
**Criteria for proceeding to Week 6**:
- ✓ Complete system operational
- ✓ UART → VGA pipeline working
- ✓ User can pause/resume
- ✓ LEDs indicate status
- ✓ CNN interface ready (signals available)

---

## WEEK 6: CNN Module Integration

### Goals
- Physical integration with Ayoub's CNN
- Classification results displayed
- End-to-end system working

### Tasks

#### Day 1-2: Integration Meeting & Planning
- [ ] **Meet with Ayoub (CNN team)**
  - Confirm CNN module interface:
    - Input: cnn_sample[11:0], cnn_valid
    - Output: cnn_result[1:0], cnn_result_valid
  - Discuss timing requirements
  - Plan integration testing
  - Agree on test vectors

#### Day 3-4: CNN Module Integration
- [ ] **Obtain Ayoub's CNN module** (VHDL files)
- [ ] **Add to ISE project**
  - Add CNN source files
  - Create wrapper if needed
- [ ] **Wire in top-level**
  ```vhdl
  cnn_inst : entity work.cnn_classifier
      port map (
          clk => clk_50mhz,
          reset_n => reset_n,
          ecg_sample => cnn_sample_internal,
          sample_valid => cnn_valid_internal,
          classification => cnn_result_internal,
          result_valid => cnn_result_valid_internal
      );
  ```

#### Day 5-6: Classification Display
- [ ] **Add result display to VGA** (optional enhancement)
  - Show "N" / "V" / "A" in corner of screen
  - Or use color coding (green=Normal, red=Abnormal)
- [ ] **Update LED mapping**
  - LED[3]: Blink on classification result
  - Or use pattern to indicate class

#### Day 7: End-to-End Testing
- [ ] **Test with known waveforms**
  - Stream Normal ECG → expect "Normal" classification
  - Stream PVC → expect "PVC" or "Ventricular"
  - Stream AFib → expect "AFib"
- [ ] **Measure performance**
  - Latency (sample in → result out)
  - Classification accuracy
  - System stability

### Deliverables
- [ ] CNN module integrated
- [ ] Classification results displayed
- [ ] End-to-end system verified
- [ ] Performance measurements documented

### Milestone Review
**Criteria for proceeding to Week 7**:
- ✓ CNN receives samples from UART data
- ✓ CNN produces classification results
- ✓ Results displayed on VGA/LEDs
- ✓ System works reliably

---

## WEEK 7: Optimization & Enhancement

### Goals
- System optimized and polished
- Enhanced features added
- Comprehensive testing

### Tasks

#### Day 1-2: Performance Optimization
- [ ] **Timing analysis**
  - Review critical paths in ISE report
  - Ensure all constraints met
  - Add timing constraints if needed
- [ ] **Resource optimization**
  - Check utilization report
  - Optimize if needed (should be <20%)

#### Day 3-4: Enhancements (Choose 1-2)
- [ ] **Option A: Better scrolling**
  - Line drawing between samples (Bresenham)
  - Smoother waveform appearance
- [ ] **Option B: Grid overlay**
  - Horizontal line at Y=240 (baseline)
  - Vertical time markers
- [ ] **Option C: Statistics display**
  - Heart rate calculation (from R-peaks)
  - Display on 7-segment or VGA text
- [ ] **Option D: Color coding**
  - Green for Normal classification
  - Yellow for PVC
  - Red for AFib

#### Day 5-7: Comprehensive Testing
- [ ] **Long-run stability test** (4+ hours)
- [ ] **Multiple dataset test**
- [ ] **Error injection test**
  - Disconnect USB cable → verify graceful handling
  - Reconnect → verify recovery
- [ ] **Create test report**

### Deliverables
- [ ] Optimized design
- [ ] At least one enhancement working
- [ ] Complete test report
- [ ] System stable and reliable

### Milestone Review
**Criteria for proceeding to Week 8**:
- ✓ System polished and professional
- ✓ All features working
- ✓ Ready for demo

---

## WEEK 8: Documentation & Demo Preparation

### Goals
- Complete documentation
- Demo ready
- Video backup prepared

### Tasks

#### Day 1-3: Documentation
- [ ] **Complete README.md** (main project)
  - System overview
  - Hardware requirements
  - Software requirements
  - Build instructions (ISE)
  - Usage instructions (Python + FPGA)
- [ ] **Module documentation**
  - Each module has header comments
  - Interface descriptions
  - Usage examples
- [ ] **Python documentation**
  - How to install dependencies
  - How to run ecg_streamer.py
  - Troubleshooting guide

#### Day 4-5: Demo Preparation
- [ ] **Create demo script**
  1. Show Python terminal streaming data
  2. Show VGA monitor with ECG
  3. Switch between waveforms (reload Python with different file)
  4. Show CNN classification results
  5. Highlight technical features
- [ ] **Record demo video** (backup)
  - Screen capture of Python terminal
  - Video of VGA monitor
  - Narration of features
- [ ] **Prepare demo setup**
  - PC with Python installed
  - FPGA programmed and tested
  - VGA monitor connected
  - USB cable connected
  - All files ready to run

#### Day 6-7: Final Testing & Cleanup
- [ ] **Final system test**
  - Complete demo run-through
  - Test all features
  - Verify stability
- [ ] **Code cleanup**
  - Remove debug code
  - Add final comments
  - Format consistently
- [ ] **Git release**
  - Tag version v1.0
  - Push to repository
  - Create release notes

### Deliverables
- [ ] Complete documentation
- [ ] Demo ready and rehearsed
- [ ] Video backup
- [ ] Clean, commented code
- [ ] Git repository organized

### Final Milestone
**Criteria for success**:
- ✓ System demonstrates reliably
- ✓ All features functional
- ✓ Documentation complete
- ✓ Demo rehearsed
- ✓ Backup plan ready

---

## RISK MITIGATION

### Risk 1: UART Communication Fails
**Symptoms**: No data received, frame errors, unstable  
**Mitigation**:
1. Test UART loopback first (hardware loopback wire)
2. Use logic analyzer to debug UART signals
3. Try lower baud rate (9600) for testing
4. Verify COM port and driver settings

**Fallback**: Use parallel GPIO for data input (2-day switch)

### Risk 2: VGA Timing Issues
**Symptoms**: No display, flickering, rolling image  
**Mitigation**:
1. Use proven VGA timing code (from docs/)
2. Test with color bars first
3. Verify pixel clock exactly 25 MHz
4. Check hsync/vsync polarities

**Fallback**: Lower resolution (320×240) if timing critical

### Risk 3: Python Timing Inaccuracy
**Symptoms**: Waveform scrolls too fast/slow  
**Mitigation**:
1. Use time.perf_counter() for better accuracy
2. Compensate for transmission time
3. Measure actual rate with oscilloscope
4. Add timing calibration option

**Fallback**: FPGA doesn't enforce rate - just displays what arrives

### Risk 4: CNN Interface Mismatch
**Symptoms**: CNN doesn't receive data, errors  
**Mitigation**:
1. Early meeting with Ayoub (Week 5)
2. Test with behavioral CNN model first
3. Clear interface documentation
4. Test vectors for validation

**Fallback**: Display on VGA/LED only, integrate CNN later

---

## SIMPLIFIED TIMELINE (FOR REFERENCE)

```
Week 1: UART RX module working
Week 2: VGA test pattern on monitor
Week 3: ECG waveform displayed from UART
Week 4: Python app streaming real ECG data
Week 5: User interface + CNN interface ready
Week 6: CNN integrated, classification working
Week 7: Optimization + enhancements
Week 8: Documentation + demo ready
```

**Critical Path**: UART RX (Week 1) → VGA display (Week 2-3)  
**Parallel Work**: Python app can be developed Week 1-4 alongside FPGA

---

## DELIVERABLES CHECKLIST

### FPGA Deliverables
- [ ] 8 VHDL modules (uart_rx + 7 others)
- [ ] 8 testbenches
- [ ] UCF pin constraints
- [ ] ISE project file (.xise)
- [ ] Bitstream (.bit file)

### Python Deliverables
- [ ] ecg_streamer.py (main app)
- [ ] ecg_loader.py (data loading)
- [ ] uart_handler.py (serial communication)
- [ ] requirements.txt
- [ ] Sample data files (3 CSV files)
- [ ] Python README

### Documentation Deliverables
- [ ] System architecture (this doc)
- [ ] Technical reference
- [ ] Implementation roadmap (this doc)
- [ ] Main README
- [ ] Module documentation (in source files)
- [ ] User guide

### Demo Deliverables
- [ ] Working hardware demo
- [ ] Demo video
- [ ] Demo script
- [ ] Results/performance data

---

## WEEKLY CHECKPOINT TEMPLATE

```
WEEK X CHECKPOINT
Date: ___________
Completed: ___/___
Simulation Tests: ___/___
Hardware Tests: ___/___

✅ Successes:
- 

❌ Issues:
- 

🔧 Solutions:
- 

📋 Next Week:
- 

⚠️ Risks:
- 
```

---

**Document Version**: 3.0 (PC-UART Streaming)  
**Created**: January 21, 2026  
**Platform**: Spartan-3E + PC  
**Status**: Ready to Execute
