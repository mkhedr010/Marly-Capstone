# ECG Simulation Component - Technical Reference Document

## Project Context
**Component**: ECG Signal Simulation & Visualization System  
**Platform**: Xilinx Spartan-3E FPGA  
**Tools**: ISE Design Suite, VHDL  
**Purpose**: Provide interactive demo/test system for CNN-based ECG classification SoC

## 1. VGA Display Specifications

### Standard VGA 640×480 @ 60Hz Timing
- **Pixel Clock**: 25.175 MHz (can use 25 MHz from 50 MHz / 2)
- **Refresh Rate**: 60 Hz
- **Total Horizontal Pixels**: 800 (visible: 640)
- **Total Vertical Lines**: 525 (visible: 480)

### Horizontal Timing (pixels @ 25.175 MHz)
- Visible Area: 640 pixels
- Front Porch: 16 pixels
- Sync Pulse: 96 pixels (negative polarity)
- Back Porch: 48 pixels
- **Total**: 800 pixels per line
- **Line Time**: ~31.77 μs

### Vertical Timing (lines)
- Visible Area: 480 lines
- Front Porch: 10 lines
- Sync Pulse: 2 lines (negative polarity)
- Back Porch: 33 lines
- **Total**: 525 lines per frame
- **Frame Time**: ~16.68 ms (59.94 Hz actual)

### VHDL Implementation Pattern
```vhdl
-- VGA Timing Generator
process(clk_25mhz)
begin
    if rising_edge(clk_25mhz) then
        -- H counter: 0 to 799
        if h_count = 799 then
            h_count <= 0;
            -- V counter: 0 to 524
            if v_count = 524 then
                v_count <= 0;
            else
                v_count <= v_count + 1;
            end if;
        else
            h_count <= h_count + 1;
        end if;
        
        -- Sync signals (negative polarity)
        hsync <= '0' when (h_count >= 656 and h_count < 752) else '1';
        vsync <= '0' when (v_count >= 490 and v_count < 492) else '1';
        
        -- Display enable
        display_on <= '1' when (h_count < 640 and v_count < 480) else '0';
    end if;
end process;
```

### RGB Color Depth for Spartan-3E
Most Spartan-3E boards have 3-bit RGB (1R, 1G, 1B) or 8-bit RGB (3R, 3G, 2B)
- **High**: VCC (white/color)
- **Low**: GND (black)
- For ECG trace: Use Green or White on Black background

## 2. ECG Signal Characteristics (MIT-BIH Dataset)

### Dataset Specifications
- **Sampling Rate**: 360 Hz (original MIT-BIH)
- **Sample Count per Beat**: 360 samples (1 second window)
- **Channels**: Single-lead (from team specs)
- **Classes**: Normal (N) vs Ventricular (V/E)
- **Data Format**: Normalized floating point → needs conversion to fixed-point

### Signal Characteristics
- **Normal Beat (N)**:
  - Regular R-peak pattern
  - Narrow QRS complex (~80-120 ms)
  - Regular PR interval
  - Amplitude range: typically -0.5 to +1.5 mV (normalized: -1.0 to +1.0)

- **Ventricular Beat (V/E)**:
  - Wide QRS complex (>120 ms)
  - Abnormal morphology
  - No P-wave or abnormal P-wave
  - Higher amplitude variations

### Data Conversion for Hardware
**From Normalized Float to 12-bit Signed Integer:**
```python
# Example conversion
def convert_to_12bit(normalized_value):
    # normalized_value in range [-1.0, +1.0]
    # 12-bit signed: -2048 to +2047
    int_value = int(normalized_value * 2047)
    # Clip to valid range
    int_value = max(-2048, min(2047, int_value))
    # Convert to 12-bit two's complement
    if int_value < 0:
        int_value = (1 << 12) + int_value
    return int_value & 0xFFF
```

### Memory Organization
- **Waveform Count**: 3 minimum (Normal, PVC, AFib)
- **Samples per Waveform**: 256 or 360
- **Bits per Sample**: 12 bits signed
- **Total Memory**: 3 × 360 × 12 = 12,960 bits ≈ 1.6 KB
  - Use Xilinx Block RAM (BRAM): 18-Kbit blocks available on Spartan-3E

## 3. Spartan-3E FPGA Specifications

### Xilinx Spartan-3E XC3S500E Details
- **Logic Cells**: 10,476
- **Block RAM**: 360 Kbits (20 blocks × 18 Kbits)
- **Distributed RAM**: 73 Kbits
- **DCMs (Digital Clock Managers)**: 4
- **Max User I/O**: 232
- **Typical Clock Speed**: 50 MHz onboard oscillator

### Block RAM (BRAM) Usage
- **Type**: 18-Kbit dual-port RAM
- **Configurations**:
  - 16K × 1 bit
  - 8K × 2 bits
  - 4K × 4 bits
  - 2K × 9 bits (with parity)
  - 1K × 18 bits (with parity)

**For ECG Storage (12-bit samples):**
- Use 512 × 18-bit configuration (stores 512 samples of 12-bit + 6 spare bits)
- Each waveform (360 samples) fits in one BRAM with room to spare
- Need 3 BRAMs for 3 waveforms (or use single BRAM with address multiplexing)

### VHDL BRAM Instantiation Pattern
```vhdl
-- Inferred BRAM (simple array)
type ram_type is array (0 to 1023) of std_logic_vector(11 downto 0);
signal ecg_ram : ram_type := (
    0 => x"000",
    1 => x"010",
    -- ... initialize with ECG data
    others => x"000"
);

process(clk)
begin
    if rising_edge(clk) then
        data_out <= ecg_ram(to_integer(unsigned(address)));
    end if;
end process;
```

## 4. Sample Rate Generation (360 Hz)

### Clock Divider Calculation
- **System Clock**: 50 MHz
- **Target Sample Rate**: 360 Hz
- **Divider**: 50,000,000 / 360 = 138,888.89 ≈ 138,889

**Actual Sample Rate**: 50,000,000 / 138,889 = 359.998 Hz ✓

### VHDL Implementation
```vhdl
constant SAMPLE_DIVIDER : integer := 138889;
signal sample_counter : integer range 0 to SAMPLE_DIVIDER-1 := 0;
signal sample_tick : std_logic := '0';

process(clk_50mhz, reset_n)
begin
    if reset_n = '0' then
        sample_counter <= 0;
        sample_tick <= '0';
    elsif rising_edge(clk_50mhz) then
        sample_tick <= '0';  -- Default low
        if sample_counter = SAMPLE_DIVIDER-1 then
            sample_counter <= 0;
            sample_tick <= '1';  -- Pulse high for 1 clock cycle
        else
            sample_counter <= sample_counter + 1;
        end if;
    end if;
end process;
```

## 5. VGA ECG Waveform Rendering

### Display Strategy
- **X-axis**: Time (scrolling, 0-639 pixels)
- **Y-axis**: Amplitude (centered at Y=240)
- **Scaling**: Map 12-bit ECG value to pixel Y coordinate

### Y-Coordinate Calculation
```vhdl
-- Center line at Y=240 (middle of 480 vertical pixels)
-- ECG sample range: -2048 to +2047 (12-bit signed)
-- Scale factor: adjust so full range fits in ±200 pixels

-- Convert signed 12-bit to pixel Y
-- Y = 240 - (ecg_sample / 10)  -- divide by ~10 for good scaling
signal ecg_signed : signed(11 downto 0);
signal y_position : integer range 0 to 479;

y_position <= 240 - to_integer(ecg_signed / 10);
```

### Scrolling Display Implementation
```vhdl
-- X position advances with each new sample
signal x_position : integer range 0 to 639 := 0;

process(clk, sample_tick)
begin
    if rising_edge(clk) then
        if sample_tick = '1' then
            -- Update waveform data at this X position
            waveform_buffer(x_position) <= ecg_sample_out;
            
            -- Advance X position (circular buffer)
            if x_position = 639 then
                x_position <= 0;
            else
                x_position <= x_position + 1;
            end if;
        end if;
    end if;
end process;

-- During VGA scan, draw pixel if at waveform Y coordinate
process(pixel_clk)
begin
    if rising_edge(pixel_clk) then
        if display_on = '1' then
            -- Get waveform value for current X
            pixel_y <= calculate_y(waveform_buffer(h_count));
            
            -- Draw pixel if at correct Y position
            if v_count = pixel_y then
                rgb <= "010";  -- Green
            else
                rgb <= "000";  -- Black
            end if;
        else
            rgb <= "000";  -- Blanking
        end if;
    end if;
end process;
```

## 6. User Interface Design

### Input Controls
**Switches (SW[1:0])** - Waveform Selection:
- `00` = Normal beat
- `01` = PVC (Premature Ventricular Contraction)
- `10` = AFib (Atrial Fibrillation)
- `11` = Reserved / Test pattern

**Button (BTN[0])** - Playback Control:
- Press once: Start/Resume
- Press again: Pause
- Requires debouncing (20-50 ms)

### Output Indicators
**LEDs**:
- `LED[1:0]`: Current waveform mode (mirrors switches)
- `LED[2]`: Playback running (1) / paused (0)
- `LED[3]`: CNN classification result (optional)

### Button Debouncing
```vhdl
constant DEBOUNCE_TIME : integer := 2_500_000;  -- 50ms @ 50MHz
signal btn_counter : integer range 0 to DEBOUNCE_TIME := 0;
signal btn_stable : std_logic := '0';
signal btn_prev : std_logic := '0';
signal btn_edge : std_logic := '0';

process(clk)
begin
    if rising_edge(clk) then
        if btn_raw /= btn_stable then
            btn_counter <= btn_counter + 1;
            if btn_counter = DEBOUNCE_TIME then
                btn_stable <= btn_raw;
                btn_counter <= 0;
            end if;
        else
            btn_counter <= 0;
        end if;
        
        -- Edge detection
        btn_prev <= btn_stable;
        btn_edge <= btn_stable and not btn_prev;  -- Rising edge
    end if;
end process;
```

## 7. CNN Integration Interface

### Signal Protocol (to Ayoub's CNN Module)
**Output Signals from Simulation Component:**
```vhdl
-- Digital ECG sample stream
ecg_sample_out : out signed(11 downto 0);     -- 12-bit ECG value
sample_valid   : out std_logic;                -- Data valid indicator
sample_tick    : out std_logic;                -- 360 Hz pulse

-- Optional debugging (not used by CNN for classification)
ecg_mode       : out std_logic_vector(1 downto 0);  -- Selected waveform
```

**Input Signals from CNN Module (if needed):**
```vhdl
cnn_ready      : in std_logic;                 -- CNN ready for samples
cnn_result     : in std_logic_vector(1 downto 0);  -- Classification result
cnn_valid      : in std_logic;                 -- Result valid
```

### Handshake Protocol
**Simple Streaming (Recommended):**
- Simulation outputs samples at fixed 360 Hz rate
- CNN samples data when `sample_tick` is high
- No backpressure needed (CNN processes faster than 360 Hz)

**Alternative with Ready/Valid:**
```vhdl
process(clk)
begin
    if rising_edge(clk) then
        if sample_tick = '1' and cnn_ready = '1' then
            ecg_sample_out <= current_sample;
            sample_valid <= '1';
        else
            sample_valid <= '0';
        end if;
    end if;
end process;
```

## 8. Memory Initialization Methods

### Method 1: VHDL Array Initialization
```vhdl
type ecg_rom_type is array (0 to 359) of std_logic_vector(11 downto 0);

constant NORMAL_ECG : ecg_rom_type := (
    x"000", x"012", x"025", x"038", x"04B",  -- Sample data
    -- ... 355 more values
    x"FFE", x"FFF"  -- Negative values in two's complement
);

signal ecg_data : std_logic_vector(11 downto 0);
process(clk)
begin
    if rising_edge(clk) then
        ecg_data <= NORMAL_ECG(address);
    end if;
end process;
```

### Method 2: COE File Format
```
memory_initialization_radix=16;
memory_initialization_vector=
000,
012,
025,
038,
04B,
...
FFE,
FFF;
```

### Method 3: MIF File Format
```
WIDTH=12;
DEPTH=360;
ADDRESS_RADIX=DEC;
DATA_RADIX=HEX;
CONTENT BEGIN
    0 : 000;
    1 : 012;
    2 : 025;
    ...
    359 : FFF;
END;
```

## 9. System Architecture Overview

### Component Hierarchy
```
ecg_system_top
├── clk_divider (50MHz → 25MHz for VGA)
├── ecg_controller
│   ├── user_interface (buttons, switches, LEDs)
│   ├── ecg_memory (3 waveforms in BRAM)
│   └── sample_generator (360 Hz ticker, address counter)
├── vga_controller
│   ├── vga_timing (H/V sync generation)
│   └── ecg_renderer (waveform drawing)
└── cnn_interface (output to CNN module)
```

### Data Flow
1. User selects waveform via switches → UI controller
2. UI controller sets BRAM base address
3. Sample generator advances address @ 360 Hz
4. BRAM outputs sample → both CNN interface and VGA renderer
5. VGA renderer maps sample to Y coordinate
6. VGA timing generates display at 60 Hz refresh
7. CNN processes samples and returns classification

### Timing Domains
- **50 MHz domain**: Main system clock, sample generation, BRAM reads
- **25 MHz domain**: VGA pixel clock
- **360 Hz domain**: Sample update rate (derived from 50 MHz)
- **60 Hz domain**: VGA frame rate (inherent in VGA timing)

## 10. Pin Constraints (UCF File Template)

### Clock and Reset
```
NET "clk_50mhz" LOC = "C9" | IOSTANDARD = LVCMOS33;
NET "reset_n"   LOC = "B18" | IOSTANDARD = LVCMOS33 | PULLUP;
```

### VGA Signals
```
NET "vga_hsync" LOC = "J14" | IOSTANDARD = LVCMOS33;
NET "vga_vsync" LOC = "K13" | IOSTANDARD = LVCMOS33;
NET "vga_r<0>"  LOC = "F13" | IOSTANDARD = LVCMOS33;
NET "vga_g<0>"  LOC = "F14" | IOSTANDARD = LVCMOS33;
NET "vga_b<0>"  LOC = "F15" | IOSTANDARD = LVCMOS33;
```

### User Interface
```
# Switches
NET "sw<0>" LOC = "G18" | IOSTANDARD = LVCMOS33;
NET "sw<1>" LOC = "H18" | IOSTANDARD = LVCMOS33;

# Buttons
NET "btn<0>" LOC = "H13" | IOSTANDARD = LVCMOS33 | PULLDOWN;

# LEDs
NET "led<0>" LOC = "J12" | IOSTANDARD = LVCMOS33;
NET "led<1>" LOC = "K12" | IOSTANDARD = LVCMOS33;
NET "led<2>" LOC = "L12" | IOSTANDARD = LVCMOS33;
NET "led<3>" LOC = "M12" | IOSTANDARD = LVCMOS33;
```

### CNN Interface (GPIO Header)
```
# Digital output to CNN module
NET "ecg_sample<0>"  LOC = "B4" | IOSTANDARD = LVCMOS33;
NET "ecg_sample<1>"  LOC = "A4" | IOSTANDARD = LVCMOS33;
# ... <2> through <11>
NET "sample_tick"    LOC = "C4" | IOSTANDARD = LVCMOS33;
```

## 11. Testing Strategy

### Simulation Tests
1. **Sample Rate Verification**: Measure `sample_tick` period = 2.78 ms
2. **BRAM Read Sequence**: Verify address wraps at 360
3. **VGA Timing**: Verify hsync/vsync periods
4. **Waveform Rendering**: Check Y coordinate calculations

### Hardware Tests (Spartan-3E Board)
1. **LED Pattern Test**: Verify switch → LED mapping
2. **VGA Display Test**: Display test pattern (grid, colors)
3. **ECG Waveform Test**: Display stored waveform on screen
4. **Sample Rate Test**: Measure with oscilloscope (if GPIO accessible)
5. **Integration Test**: Connect to CNN, verify data transfer

### Acceptance Criteria
- [ ] VGA displays stable image at 640×480 @ 60Hz
- [ ] ECG waveform scrolls smoothly across screen
- [ ] User can select different waveforms via switches
- [ ] LEDs correctly indicate current mode
- [ ] Sample output updates at ~360 Hz ± 0.5%
- [ ] CNN module receives correct sample stream
- [ ] System runs continuously without errors

## 12. Implementation Milestones

### Week 1-2 (COE 70B Start)
- [ ] VHDL module skeletons created
- [ ] ISE project configured
- [ ] Basic testbenches written
- [ ] Simulation of individual modules successful

### Week 3-4
- [ ] VGA timing verified (test pattern on screen)
- [ ] BRAM initialized with sample data
- [ ] Sample generator tested (LED blink at 360 Hz)

### Week 5-6
- [ ] ECG waveform rendering on VGA
- [ ] User interface functional
- [ ] Waveform selection working

### Week 7-8
- [ ] CNN integration complete
- [ ] Full system test with classification
- [ ] Documentation finalized

## 13. Design Decisions Summary

### Why Block RAM?
- Efficient for storing 1-4 KB of data
- Synchronous read (predictable timing)
- Available resource on Spartan-3E (360 Kbits total)

### Why 12-bit Samples?
- Good precision for ECG signals
- Matches typical ADC resolution
- Efficient BRAM packing (12 bits + 6 spare in 18-bit BRAM)

### Why Scrolling Display?
- Real-time feel (like ECG monitor)
- No buffering of full screen needed
- Visually engaging for demo

### Why 360 Hz Sample Rate?
- Matches MIT-BIH dataset native rate
- Sufficient for ECG (Nyquist: 180 Hz for ~90 Hz max ECG frequency)
- Easy to generate from 50 MHz clock

### Why Simple Streaming Interface?
- CNN processes faster than 360 Hz input
- No backpressure needed
- Simple synchronous design
- Easy to debug

## 14. Risk Mitigation

### Risk 1: VGA Timing Issues
- **Mitigation**: Use proven VGA timing code from references
- **Fallback**: Display static test pattern first

### Risk 2: BRAM Synthesis Problems
- **Mitigation**: Test both inferred and instantiated BRAM
- **Fallback**: Use distributed RAM for smaller datasets

### Risk 3: Sample Rate Drift
- **Mitigation**: Use precise divider calculation, verify in simulation
- **Fallback**: Make divider configurable via generic

### Risk 4: CNN Integration Mismatch
- **Mitigation**: Define interface early, document clearly
- **Fallback**: Add configurable interface layer

### Risk 5: Pin Constraint Issues
- **Mitigation**: Get actual board pinout from team/lab
- **Fallback**: Use generic UCF with placeholders

## 15. References & Resources

### VGA Standards
- VESA VGA Standard (640×480 @ 60Hz)
- Common pixel clock: 25.175 MHz

### FPGA Resources
- Xilinx Spartan-3E Data Sheet (DS312)
- ISE Design Suite User Guide
- VHDL coding guidelines for synthesis

### ECG Datasets
- MIT-BIH Arrhythmia Database (physionet.org)
- Kaggle ECG Heartbeat Categorization Dataset
- 360 Hz sampling, single-lead data

### Design Patterns
- Standard VGA controller implementations
- BRAM inference patterns for Xilinx
- Clock domain crossing techniques

---

**Document Version**: 1.0  
**Last Updated**: November 25, 2025  
**Author**: AI Assistant (Technical Research)  
**Purpose**: Reference for ECG Simulation Component Design
