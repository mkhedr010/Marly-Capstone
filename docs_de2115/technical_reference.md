# ECG Simulation Component - Technical Reference Document
## DE2-115 FPGA with Audio Interface

## Project Context
**Component**: ECG Signal Simulation & Visualization System  
**Platform**: Altera DE2-115 FPGA (Cyclone IV)  
**Tools**: Quartus Prime, VHDL  
**Purpose**: Provide interactive demo/test system for CNN-based ECG classification SoC

**NEW ARCHITECTURE**: Two-board system
- **Board 1 (DE2-115)**: This simulation component
- **Board 2 (Spartan-3E)**: CNN classifier (team's component)
- **Connection**: 3.5mm audio jack (analog audio transmission)

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

### RGB Color Depth for DE2-115
DE2-115 has 10-bit VGA DAC (4-bit R, 4-bit G, 2-bit B = VGA_R[3:0], VGA_G[3:0], VGA_B[3:0])
- Much better color depth than Spartan-3E
- For ECG trace: Use bright green (0xF0) on black background
- Can add colored zones for abnormal regions

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
  - Use Altera M9K Block RAM on DE2-115

## 3. DE2-115 FPGA Specifications

### Altera Cyclone IV EP4CE115F29C7 Details
- **Logic Elements**: 114,480 LEs (vs 10,476 on Spartan-3E) - **11x more resources!**
- **Memory**: 3,981,312 bits (M9K blocks) - **11x more than Spartan-3E**
- **Embedded Multipliers**: 532 (18x18 bit)
- **PLLs**: 4 PLLs for flexible clock generation
- **Max User I/O**: 528
- **Typical Clock Speed**: 50 MHz onboard oscillator

### M9K Block RAM Usage
- **Type**: 9-Kbit dual-port RAM (M9K blocks)
- **Total**: 432 M9K blocks available
- **Configurations**:
  - 8K × 1 bit
  - 4K × 2 bits
  - 2K × 4 bits
  - 1K × 9 bits
  - 512 × 18 bits

**For ECG Storage (12-bit samples):**
- Use 512 × 18-bit configuration (stores 512 samples of 12-bit + 6 spare bits)
- Each waveform (360 samples) fits in one M9K block with room to spare
- Need 3 M9K blocks for 3 waveforms (or use single block with address multiplexing)
- **Trivial resource usage**: 3/432 blocks = 0.7%

### VHDL BRAM Instantiation Pattern
```vhdl
-- Inferred RAM (Quartus will automatically use M9K)
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
- **System Clock**: 50 MHz (DE2-115 oscillator)
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
                vga_r <= x"F"; vga_g <= x"F"; vga_b <= x"0";  -- Bright green
            else
                vga_r <= x"0"; vga_g <= x"0"; vga_b <= x"0";  -- Black
            end if;
        else
            vga_r <= x"0"; vga_g <= x"0"; vga_b <= x"0";  -- Blanking
        end if;
    end if;
end process;
```

## 6. User Interface Design

### Input Controls (DE2-115 has many switches!)
**Switches (SW[1:0])** - Waveform Selection:
- `00` = Normal beat
- `01` = PVC (Premature Ventricular Contraction)
- `10` = AFib (Atrial Fibrillation)
- `11` = Reserved / Test pattern

**Button (KEY[0])** - Playback Control:
- Press once: Start/Resume
- Press again: Pause
- Requires debouncing (20-50 ms)

### Output Indicators (DE2-115 has 18 red + 9 green LEDs!)
**Red LEDs (LEDR[17:0])**:
- `LEDR[1:0]`: Current waveform mode (mirrors switches)
- `LEDR[2]`: Playback running (1) / paused (0)
- `LEDR[3]`: Audio output active
- `LEDR[17:4]`: Can show audio level meter (optional)

**Green LEDs (LEDG[8:0])**:
- Can show sample count or heart rate (optional)

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

## 7. **AUDIO OUTPUT INTERFACE (NEW!)**

### Audio Interface via 3.5mm Jack

**Purpose**: Transmit ECG samples as analog audio to CNN board  
**Hardware**: DE2-115 has WM8731 audio codec with 3.5mm Line Out jack  
**Sample Rate**: 360 Hz ECG → Need to upsample or use I2S directly  

### WM8731 Audio CODEC Specifications
- **Interface**: I2S (Inter-IC Sound)
- **Resolution**: Up to 24-bit
- **Sample Rates**: 8 kHz to 96 kHz
- **Output**: Line Out (3.5mm jack)
- **Control**: I2C for configuration

### Transmission Strategy

**Option 1: Direct Low-Frequency Audio** (RECOMMENDED)
- Output ECG samples as low-frequency audio (360 Hz sample rate)
- Configure WM8731 for 48 kHz I2S, repeat each ECG sample 133 times
- Receiving board uses ADC to digitize audio back to ECG samples
- Simple, works with standard audio hardware

**Option 2: Modulated Audio**
- Encode 12-bit ECG as audio frequency (FSK/PSK)
- More complex but more robust against audio artifacts

**We'll use Option 1 for simplicity**

### I2S Signal Format
```
     BCLK  ___   ___   ___   ___   ___   ___   ___   ___
(Bit Clock) |   | |   | |   | |   | |   | |   | |   | |   |

     LRCK  _____________________________________
(L/R Select)                                    |_____________

     DATA  ====X===X===X===X===X===X===X===X===X===X===X===
           MSB                             LSB
```

- **BCLK (Bit Clock)**: 48 kHz × 32 bits × 2 channels = 3.072 MHz
- **LRCK (Left/Right Clock)**: 48 kHz (sample rate)
- **DATA**: Serial audio data

### VHDL I2S Transmitter Pattern
```vhdl
entity i2s_transmitter is
    port (
        clk           : in  std_logic;  -- 50 MHz
        reset_n       : in  std_logic;
        
        -- ECG sample input (360 Hz)
        ecg_sample    : in  std_logic_vector(11 downto 0);
        sample_tick   : in  std_logic;
        
        -- I2S outputs to WM8731
        aud_bclk      : out std_logic;  -- Bit clock
        aud_daclrck   : out std_logic;  -- DAC L/R clock
        aud_dacdat    : out std_logic;  -- DAC data
        
        -- I2C for codec config
        i2c_sclk      : out std_logic;
        i2c_sdat      : inout std_logic
    );
end i2s_transmitter;
```

### WM8731 Configuration via I2C
```vhdl
-- Initialize WM8731 codec
-- Set sample rate to 48 kHz
-- Set Line Out as active
-- Bypass DSP (pass-through mode)

constant WM8731_ADDR : std_logic_vector(6 downto 0) := "0011010";

type config_array is array (0 to 9) of std_logic_vector(15 downto 0);
constant WM8731_CONFIG : config_array := (
    x"1E00",  -- Reset
    x"0017",  -- Left Line In: 0dB, unmute
    x"0217",  -- Right Line In: 0dB, unmute
    x"0479",  -- Left Headphone Out: 0dB
    x"0579",  -- Right Headphone Out: 0dB
    x"0A00",  -- DAC power on, Line In off
    x"0C00",  -- Bypass mode off
    x"0E02",  -- Digital audio format: I2S
    x"1002",  -- Sample rate: 48kHz
    x"1201"   -- Activate
);
```

### ECG Sample Upsampling (360 Hz → 48 kHz)
```vhdl
-- Hold each ECG sample for multiple I2S samples
constant UPSAMPLE_RATIO : integer := 133;  -- 48000/360 ≈ 133

signal ecg_sample_held : signed(11 downto 0);
signal hold_counter : integer range 0 to UPSAMPLE_RATIO-1;

process(clk_48khz)
begin
    if rising_edge(clk_48khz) then
        if sample_tick = '1' then
            ecg_sample_held <= ecg_sample;
            hold_counter <= 0;
        elsif hold_counter < UPSAMPLE_RATIO-1 then
            hold_counter <= hold_counter + 1;
        end if;
    end if;
end process;

-- Send ecg_sample_held to I2S transmitter
-- Pad 12-bit to 16-bit or 24-bit as needed
signal i2s_data : std_logic_vector(15 downto 0);
i2s_data <= std_logic_vector(ecg_sample_held) & "0000";  -- Left-align 12-bit in 16-bit
```

### Receiving End (CNN Board - for reference)
The CNN board needs an ADC to digitize the audio back to ECG:
- Use audio Line In on their board (if available)
- Or use external ADC module
- Downsample 48 kHz audio back to 360 Hz
- Extract original 12-bit ECG samples

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

### Method 2: MIF File Format (Altera/Intel)
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

### Method 3: HEX File Format (Altera/Intel)
```
:020000040000FA
:1000000000012025038...
:00000001FF
```

## 9. System Architecture Overview

### Component Hierarchy
```
ecg_system_top (DE2-115)
├── pll_50to48 (PLL: 50MHz → 48MHz for audio)
├── clk_divider (50MHz → 25MHz for VGA)
├── ecg_controller
│   ├── user_interface (buttons, switches, LEDs)
│   ├── ecg_memory (3 waveforms in M9K RAM)
│   └── sample_generator (360 Hz ticker, address counter)
├── vga_controller
│   ├── vga_timing (H/V sync generation)
│   └── ecg_renderer (waveform drawing)
└── audio_output  **NEW!**
    ├── i2c_controller (WM8731 config)
    ├── i2s_transmitter (audio output)
    └── sample_upsampler (360Hz → 48kHz)
```

### Data Flow (Updated for Audio)
1. User selects waveform via switches → UI controller
2. UI controller sets M9K base address
3. Sample generator advances address @ 360 Hz
4. M9K outputs sample → both VGA renderer AND audio output
5. VGA renderer maps sample to Y coordinate
6. VGA timing generates display at 60 Hz refresh
7. **Audio output upsamples and transmits via 3.5mm jack**
8. **CNN board (Spartan-3E) receives audio, digitizes, classifies**

### Timing Domains
- **50 MHz domain**: Main system clock, sample generation, M9K reads
- **48 MHz domain**: **NEW!** Audio I2S clock (from PLL)
- **25 MHz domain**: VGA pixel clock
- **360 Hz domain**: Sample update rate (derived from 50 MHz)
- **60 Hz domain**: VGA frame rate (inherent in VGA timing)

## 10. Pin Constraints (QSF File for Quartus)

### Clock and Reset
```tcl
set_location_assignment PIN_Y2 -to clk_50mhz
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to clk_50mhz

set_location_assignment PIN_M23 -to reset_n
set_instance_assignment -name IO_STANDARD "2.5 V" -to reset_n
```

### VGA Signals (DE2-115 VGA connector)
```tcl
set_location_assignment PIN_D12 -to vga_clk
set_location_assignment PIN_C10 -to vga_blank_n
set_location_assignment PIN_A12 -to vga_sync_n
set_location_assignment PIN_F11 -to vga_hs
set_location_assignment PIN_G13 -to vga_vs

set_location_assignment PIN_E12 -to vga_r[0]
set_location_assignment PIN_E11 -to vga_r[1]
set_location_assignment PIN_D10 -to vga_r[2]
set_location_assignment PIN_F12 -to vga_r[3]

set_location_assignment PIN_G10 -to vga_g[0]
set_location_assignment PIN_J12 -to vga_g[1]
set_location_assignment PIN_H8 -to vga_g[2]
set_location_assignment PIN_H10 -to vga_g[3]

set_location_assignment PIN_G8 -to vga_b[0]
set_location_assignment PIN_B10 -to vga_b[1]
set_location_assignment PIN_A10 -to vga_b[2]
set_location_assignment PIN_C11 -to vga_b[3]
```

### Audio Signals (WM8731 codec)
```tcl
# I2S Audio Output
set_location_assignment PIN_D2 -to aud_bclk
set_location_assignment PIN_C2 -to aud_daclrck
set_location_assignment PIN_D1 -to aud_dacdat

# I2C for WM8731 config
set_location_assignment PIN_C3 -to i2c_sclk
set_location_assignment PIN_D3 -to i2c_sdat
```

### User Interface
```tcl
# Switches SW[17:0]
set_location_assignment PIN_AB28 -to sw[0]
set_location_assignment PIN_AC28 -to sw[1]

# Buttons KEY[3:0] (active low)
set_location_assignment PIN_M23 -to key[0]

# Red LEDs LEDR[17:0]
set_location_assignment PIN_G19 -to ledr[0]
set_location_assignment PIN_F19 -to ledr[1]
set_location_assignment PIN_E19 -to ledr[2]
set_location_assignment PIN_F21 -to ledr[3]
```

## 11. Testing Strategy

### Simulation Tests
1. **Sample Rate Verification**: Measure `sample_tick` period = 2.78 ms
2. **M9K Read Sequence**: Verify address wraps at 360
3. **VGA Timing**: Verify hsync/vsync periods
4. **Waveform Rendering**: Check Y coordinate calculations
5. **I2S Timing**: Verify BCLK, LRCK, DATA timing
6. **Audio Upsampling**: Verify 360 Hz → 48 kHz conversion

### Hardware Tests (DE2-115 Board)
1. **LED Pattern Test**: Verify switch → LED mapping
2. **VGA Display Test**: Display test pattern (grid, colors)
3. **ECG Waveform Test**: Display stored waveform on screen
4. **Audio Output Test**: **NEW!** Measure with oscilloscope/analyzer
   - Connect 3.5mm to oscilloscope
   - Verify audio waveform shape matches ECG
   - Measure frequency spectrum
5. **End-to-End Test**: Connect to CNN board via audio cable

### Acceptance Criteria
- [ ] VGA displays stable image at 640×480 @ 60Hz
- [ ] ECG waveform scrolls smoothly across screen
- [ ] User can select different waveforms via switches
- [ ] LEDs correctly indicate current mode
- [ ] **Audio output active (measurable on oscilloscope)**
- [ ] **CNN board receives intelligible ECG signal**
- [ ] System runs continuously without errors

## 12. Implementation Milestones

### Week 1-2 (COE 70B Start)
- [ ] VHDL module skeletons created
- [ ] Quartus project configured for DE2-115
- [ ] Basic testbenches written
- [ ] Simulation of individual modules successful

### Week 3-4
- [ ] VGA timing verified (test pattern on screen)
- [ ] M9K initialized with sample data
- [ ] Sample generator tested
- [ ] **Audio codec initialization working**

### Week 5-6
- [ ] ECG waveform rendering on VGA
- [ ] User interface functional
- [ ] Waveform selection working
- [ ] **Audio output verified with oscilloscope**

### Week 7-8
- [ ] **Two-board integration complete**
- [ ] Full system test with CNN classification
- [ ] Documentation finalized

## 13. Design Decisions Summary

### Why DE2-115 Instead of Spartan-3E?
- **11x more logic resources** (114K vs 10K LEs)
- **11x more memory** (~4 Mbits vs 360 Kbits)
- **Built-in audio codec** (WM8731 with 3.5mm jacks)
- **Better VGA DAC** (10-bit color vs 3-bit)
- **More I/O** (528 vs 232 pins)
- **4 PLLs** for flexible clock generation

### Why Audio Interface Instead of GPIO?
- **Physical separation**: Two boards can be far apart
- **Standard connection**: 3.5mm cables are common
- **Galvanic isolation**: Reduces ground loop issues
- **Easier testing**: Can monitor with audio equipment
- **Real-world skill**: Learn audio codec interfacing

### Why 48 kHz Audio for 360 Hz ECG?
- Standard audio sample rate (well-supported)
- Easy integer upsampling (133x)
- Sufficient bandwidth (24 kHz Nyquist >> 360 Hz)
- WM8731 natively supports 48 kHz

### Why Hold-and-Repeat Upsampling?
- Simplest method (each ECG sample held for 133 audio samples)
- No interpolation artifacts
- Easy to downsample on receiving end
- Preserves original ECG sample values exactly

## 14. Risk Mitigation

### Risk 1: VGA Timing Issues
- **Mitigation**: DE2-115 has proven VGA examples
- **Fallback**: Use Altera IP cores for VGA timing

### Risk 2: Audio Codec Configuration
- **Mitigation**: Use Altera University Program examples
- **Fallback**: Manual I2C bit-banging if IP fails

### Risk 3: Audio-to-CNN Signal Integrity
- **Mitigation**: Test with oscilloscope first, verify waveform
- **Fallback**: Add error correction or checksum to audio stream

### Risk 4: Sample Rate Drift
- **Mitigation**: Use PLL for precise clocks
- **Fallback**: Make divider configurable

### Risk 5: Two-Board Coordination
- **Mitigation**: Define clear interface early, test loopback first
- **Fallback**: Use longer audio cable for easier debugging

## 15. References & Resources

### DE2-115 Resources
- DE2-115 User Manual (Terasic)
- Cyclone IV Device Handbook
- Quartus Prime Design Software
- Altera University Program Design Examples

### Audio Resources
- WM8731 Datasheet (Wolfson/Cirrus Logic)
- I2S Specification (Philips)
- Audio Engineering guides

### ECG Datasets
- MIT-BIH Arrhythmia Database (physionet.org)
- Kaggle ECG Heartbeat Categorization Dataset

### Design Patterns
- Altera VGA controller examples
- M9K memory inference patterns
- I2S transmitter examples

---

**Document Version**: 2.0 (DE2-115 Update)  
**Last Updated**: November 28, 2025  
**Author**: AI Assistant (Technical Research)  
**Platform**: DE2-115 with Audio Interface  
**Purpose**: Reference for Two-Board ECG Simulation System
