# ECG Simulation Component - Technical Reference
## Spartan-3E with PC UART Streaming

## Project Context
**Component**: ECG Signal Simulation & Visualization System  
**Platform**: Xilinx Spartan-3E FPGA  
**Tools**: ISE Design Suite, VHDL, Python  
**Data Source**: PC via UART (115200 baud)  
**Purpose**: Display ECG on VGA + feed CNN classifier

**Key Change**: ECG data streams from PC instead of being stored in BRAM

---

## 1. UART INTERFACE SPECIFICATION

### UART Hardware

**Spartan-3E boards typically include**:
- FT232 USB-UART bridge chip
- USB mini/micro connector
- Automatic COM port assignment when connected to PC

**UART Settings**:
```
Baud Rate:    115200 bps
Data Bits:    8
Parity:       None
Stop Bits:    1
Flow Control: None
```

### Baud Rate Generation

**Clock Divider Calculation**:
```
System Clock: 50 MHz
Baud Rate: 115200
Bit Period: 50,000,000 / 115,200 = 434.03 ≈ 434 clocks/bit
Actual Baud: 50,000,000 / 434 = 115,207 bps
Error: 0.006% (negligible)
```

**Oversampling for Reception**:
```
Oversampling Rate: 16× (standard for UART)
Sample Clock: 115,200 × 16 = 1,843,200 Hz
Clock Divider: 50,000,000 / 1,843,200 = 27.13 ≈ 27 clocks
Actual Sample Rate: 50,000,000 / 27 = 1,851,851 Hz
Oversampling: 1,851,851 / 115,207 = 16.07× ✓
```

### UART Frame Format

**Single Byte Transmission**:
```
     Start                  Data Bits                    Stop
     Bit     D0   D1   D2   D3   D4   D5   D6   D7       Bit
    _____   ____________________________________________________   _____
____|   |___|  |___|  |___|  |___|  |___|  |___|  |___|  |___|  |__|   |___
     0    LSB                                           MSB      1
     
    |<----------------------- 86.8 μs @ 115200 baud ---------------------->|
```

**12-bit ECG Sample Transmission** (2 bytes):
```
Byte 1: ecg_sample[7:0]    (lower 8 bits)
Byte 2: 0000 + ecg_sample[11:8]  (upper 4 bits + padding)

Example for sample value 0x5A3:
Byte 1: 0xA3 (binary: 10100011)
Byte 2: 0x05 (binary: 00000101)
```

### UART Receiver State Machine

```vhdl
type uart_state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
signal state : uart_state_type := IDLE;
signal bit_index : integer range 0 to 7 := 0;
signal data_reg : std_logic_vector(7 downto 0);

process(clk)
begin
    if rising_edge(clk) then
        case state is
            when IDLE =>
                if uart_rx = '0' then  -- Start bit detected
                    state <= START_BIT;
                end if;
                
            when START_BIT =>
                -- Wait for middle of start bit, verify still low
                if sample_counter = 8 then  -- Middle of bit
                    if uart_rx = '0' then
                        state <= DATA_BITS;
                        bit_index <= 0;
                    else
                        state <= IDLE;  -- False start
                    end if;
                end if;
                
            when DATA_BITS =>
                if sample_counter = 15 then  -- Sample point
                    data_reg(bit_index) <= uart_rx;
                    if bit_index = 7 then
                        state <= STOP_BIT;
                    else
                        bit_index <= bit_index + 1;
                    end if;
                end if;
                
            when STOP_BIT =>
                if sample_counter = 15 then
                    if uart_rx = '1' then  -- Valid stop bit
                        byte_received <= '1';
                        rx_data <= data_reg;
                    else
                        frame_error <= '1';  -- Framing error
                    end if;
                    state <= IDLE;
                end if;
        end case;
    end if;
end process;
```

---

## 2. VGA DISPLAY SPECIFICATIONS

*(Same as original design - see docs/technical_reference.md §1)*

### Standard VGA 640×480 @ 60Hz Timing
- Pixel Clock: 25 MHz (from 50 MHz ÷ 2)
- Refresh Rate: 60 Hz
- Horizontal: 640 visible + 160 blanking = 800 total
- Vertical: 480 visible + 45 blanking = 525 total

### RGB Color Mapping (Spartan-3E)
```vhdl
-- For ECG trace (green on black)
if drawing_waveform then
    vga_r <= "000";  -- Red: off
    vga_g <= "111";  -- Green: full
    vga_b <= "00";   -- Blue: off
else
    vga_r <= "000";  -- Black background
    vga_g <= "000";
    vga_b <= "00";
end if;
```

---

## 3. ECG DATA HANDLING

### Data Source: PC Python Application

**Instead of BRAM storage, data flows from PC**:
- Python loads MIT-BIH CSV files
- Converts to 12-bit signed integers
- Streams via UART at 360 Hz
- FPGA receives and immediately displays + feeds CNN

### Sample Format (unchanged)
- 12-bit signed integer
- Range: -2048 to +2047
- Two's complement representation

### Python Conversion Code
```python
import numpy as np

def convert_to_12bit(ecg_signal):
    # Normalize to [-1, 1]
    normalized = (ecg_signal - np.mean(ecg_signal)) / np.std(ecg_signal)
    normalized = np.clip(normalized, -1, 1)
    
    # Scale to 12-bit signed
    scaled = (normalized * 2047).astype(int)
    scaled = np.clip(scaled, -2048, 2047)
    
    return scaled
```

---

## 4. MEMORY ORGANIZATION

### Waveform Buffer (BRAM)

**Purpose**: Store last 640 samples for VGA display

**Specifications**:
- Size: 640 × 12-bit = 7,680 bits
- Type: Dual-port RAM (inferred BRAM)
- Write Port: System clock (50 MHz), write on sample_valid
- Read Port: VGA pixel clock (25 MHz), continuous read

**Implementation**:
```vhdl
type waveform_buffer_type is array (0 to 639) of signed(11 downto 0);
signal waveform_buffer : waveform_buffer_type := (others => (others => '0'));
signal write_ptr : integer range 0 to 639 := 0;

-- Write on sample arrival from UART
process(clk_system)
begin
    if rising_edge(clk_system) then
        if sample_valid = '1' then
            waveform_buffer(write_ptr) <= signed(ecg_sample);
            if write_ptr = 639 then
                write_ptr <= 0;
            else
                write_ptr <= write_ptr + 1;
            end if;
        end if;
    end if;
end process;

-- Read during VGA scan
process(clk_pixel)
begin
    if rising_edge(clk_pixel) then
        if display_on = '1' and pixel_x < 640 then
            current_sample <= waveform_buffer(to_integer(unsigned(pixel_x)));
        end if;
    end if;
end process;
```

---

## 5. PIN CONSTRAINTS (UCF File)

### Spartan-3E Starter Kit Pin Assignments

```
# Clock and Reset
NET "clk_50mhz" LOC = "C9" | IOSTANDARD = LVCMOS33;
NET "reset_n"   LOC = "B18" | IOSTANDARD = LVCMOS33 | PULLUP;

# UART (USB-Serial)
NET "uart_rx" LOC = "R7" | IOSTANDARD = LVCMOS33;  # Check your board manual!

# VGA Signals
NET "vga_hsync" LOC = "J14" | IOSTANDARD = LVCMOS33;
NET "vga_vsync" LOC = "K13" | IOSTANDARD = LVCMOS33;
NET "vga_r<0>"  LOC = "F13" | IOSTANDARD = LVCMOS33;
NET "vga_r<1>"  LOC = "D13" | IOSTANDARD = LVCMOS33;
NET "vga_r<2>"  LOC = "C14" | IOSTANDARD = LVCMOS33;
NET "vga_g<0>"  LOC = "G14" | IOSTANDARD = LVCMOS33;
NET "vga_g<1>"  LOC = "G13" | IOSTANDARD = LVCMOS33;
NET "vga_g<2>"  LOC = "F14" | IOSTANDARD = LVCMOS33;
NET "vga_b<0>"  LOC = "J13" | IOSTANDARD = LVCMOS33;
NET "vga_b<1>"  LOC = "H13" | IOSTANDARD = LVCMOS33;

# User Interface
NET "btn<0>" LOC = "H13" | IOSTANDARD = LVCMOS33 | PULLDOWN;
NET "led<0>" LOC = "J12" | IOSTANDARD = LVCMOS33;
NET "led<1>" LOC = "K12" | IOSTANDARD = LVCMOS33;
NET "led<2>" LOC = "L12" | IOSTANDARD = LVCMOS33;
NET "led<3>" LOC = "M12" | IOSTANDARD = LVCMOS33;
```

**IMPORTANT**: Verify UART_RX pin location in your board's manual!

---

## 6. PYTHON PC APPLICATION SPECIFICATION

### Requirements

**Python Libraries**:
```
pyserial==3.5
numpy>=1.21.0
pandas>=1.3.0  (for CSV reading)
```

### Application Features

**ecg_streamer.py Functionality**:
1. Load ECG dataset from CSV (MIT-BIH format)
2. Select waveform type (command-line or interactive)
3. Convert to 12-bit signed integers
4. Stream via UART at 360 Hz
5. Display status (samples sent, errors)

**Command-Line Interface**:
```bash
python ecg_streamer.py --port COM3 --waveform normal --file normal_ecg.csv
```

**Features**:
- Auto-detect COM port (if possible)
- Configurable sample rate (default 360 Hz)
- Loop playback option
- Pause/resume control
- Real-time statistics

---

## 7. TIMING AND SYNCHRONIZATION

### Sample Rate from PC

**Target**: 360 Hz (one sample every 2.778 ms)

**Python Implementation**:
```python
import time

sample_period = 1.0 / 360.0  # 2.778 ms

for sample in ecg_data:
    # Send 2 bytes
    byte1 = sample & 0xFF
    byte2 = (sample >> 8) & 0x0F
    ser.write(bytes([byte1, byte2]))
    
    # Wait for next sample time
    time.sleep(sample_period)
```

**Accuracy**: Python sleep() has ~1ms resolution on Windows
- Good enough for demo purposes
- FPGA doesn't enforce timing (just receives when data arrives)

### VGA Frame Rate

**Independent of UART**:
- VGA refreshes at 60 Hz (fixed)
- Waveform buffer updated when UART receives data
- Buffer is read continuously by VGA scan

**No synchronization needed** - asynchronous operation works fine!

---

## 8. ERROR HANDLING

### UART Errors

**Frame Error Detection**:
- Stop bit not high → frame error
- LED indicator for errors
- Optional: count and display error rate

**Missing Data**:
- If PC stops sending → waveform freezes
- Timeout detection (no data for >1 second)
- LED indicator for "no signal"

**Recovery**:
- UART receiver automatically recovers on next valid frame
- Waveform buffer retains last 640 samples

### VGA Display Robustness

**Continuous Operation**:
- VGA always displays from buffer
- Even if UART stops, last waveform visible
- No crash or blank screen

---

## 9. DESIGN ADVANTAGES

### Vs. BRAM Storage (Original Design)

| Aspect | BRAM Storage | UART Streaming |
|--------|--------------|----------------|
| **Waveforms** | 3 pre-loaded | Unlimited |
| **FPGA Resources** | 4-5 BRAM blocks | 1-2 BRAM blocks |
| **Data Update** | Fixed at synthesis | Real-time from PC |
| **Testing** | Reprogram FPGA | Just run Python |
| **Flexibility** | Low | High |
| **Complexity** | Medium (BRAM init) | Low (UART simple) |

**Winner**: UART streaming! ✅

### Educational Value

**You Still Learn**:
- ✅ VGA display in HDL (main goal!)
- ✅ UART protocol (valuable skill)
- ✅ Clock domain crossing
- ✅ FPGA-PC communication
- ✅ Real-time data streaming

**Bonus**:
- + Python serial communication
- + Dataset manipulation
- + System integration (PC + FPGA)

---

## 10. TESTING SPECIFICATIONS

### UART Loopback Test

**Purpose**: Verify UART receiver works

**Setup**:
```python
# Python sends counting pattern
for i in range(1000):
    sample = i & 0xFFF  # 0 to 4095, then wrap
    byte1 = sample & 0xFF
    byte2 = (sample >> 8) & 0x0F
    ser.write(bytes([byte1, byte2]))
    time.sleep(0.001)  # 1 ms between samples
```

**FPGA displays on LEDs**: ecg_sample[11:0] should count 0, 1, 2, ...

### VGA Test Patterns

**Test 1**: Flat Line
- Stream constant value (e.g., 0x000)
- Expect horizontal line at Y=240

**Test 2**: Sine Wave
- Stream sine wave samples
- Expect smooth wave on display

**Test 3**: Square Wave
- Alternate between +1000 and -1000
- Expect square wave pattern

### ECG Waveform Tests

**Test 1**: Normal ECG
- Load from MIT-BIH dataset
- Verify P-wave, QRS complex, T-wave visible

**Test 2**: PVC
- Should show wide QRS complex

**Test 3**: AFib
- Should show irregular rhythm

---

## 11. MODULE-SPECIFIC DETAILS

### UART Receiver Timing

**Bit Sampling Strategy**:
- Sample UART_RX at middle of each bit
- Use 16× oversampling for robustness
- Start bit: Sample at count 8 (mid-point)
- Data bits: Sample at count 15 (mid-point)
- Stop bit: Sample at count 15

**Implementation**:
```vhdl
constant SAMPLES_PER_BIT : integer := 16;
signal sample_counter : integer range 0 to SAMPLES_PER_BIT-1 := 0;

process(clk, sample_tick_16x)
begin
    if rising_edge(clk) then
        if sample_tick_16x = '1' then
            if sample_counter = SAMPLES_PER_BIT-1 then
                sample_counter <= 0;
            else
                sample_counter <= sample_counter + 1;
            end if;
        end if;
    end if;
end process;
```

### VGA Renderer Modifications

**Original** (BRAM-based):
- Samples arrive at fixed 360 Hz tick
- Buffer update synchronized to sample generation

**UART-based** (new):
- Samples arrive asynchronously from UART
- Buffer update on sample_valid signal
- VGA read is independent (always reads from buffer)

**No other changes needed** - VGA rendering logic identical!

---

## 12. RESOURCE OPTIMIZATION

### Reduced FPGA Usage

**BRAM Savings**:
- Original: 3-4 blocks (ECG storage + waveform buffer)
- UART: 1-2 blocks (waveform buffer only)
- **Saved**: 2-3 BRAM blocks (10-15% of total)

**Logic Savings**:
- Removed: ecg_memory module
- Removed: Address base calculation
- Removed: Mode-based address generation
- Added: UART receiver (small ~100 LUTs)
- **Net**: Slightly reduced logic usage

**Total Resource Usage**:
- Logic: ~14% (vs 19% original)
- BRAM: ~7% (vs 22% original)
- I/O: ~6% (vs 11% original)

---

## 13. ADVANTAGES & TRADE-OFFS

### Advantages ✅

1. **Simplified FPGA Design**
   - No BRAM initialization complexity
   - No COE/MIF file generation
   - Smaller codebase

2. **Flexibility**
   - Test with any ECG dataset
   - Easy to add new waveforms
   - Real-time parameter tuning from PC

3. **Development Speed**
   - Faster iteration (no FPGA reprogram to change data)
   - Easy debugging (Python prints, logs)
   - Separate concerns (PC handles data, FPGA handles display)

4. **Educational Value**
   - Learn UART protocol (universal skill)
   - Learn FPGA-PC integration
   - Learn Python serial communication

### Trade-Offs ⚠️

1. **Requires PC**
   - Not standalone (needs PC connected)
   - But realistic for development/demo

2. **UART Latency**
   - ~86 μs per byte, ~174 μs per sample
   - Negligible for 360 Hz (2.778 ms period)

3. **Cable Dependency**
   - Needs USB cable connected
   - But standard equipment

**Conclusion**: Trade-offs are minor, advantages are significant!

---

## 14. PYTHON APPLICATION ARCHITECTURE

### File Structure
```
python/
├── ecg_streamer.py       (Main application)
├── uart_handler.py       (UART communication)
├── ecg_loader.py         (Dataset loading)
├── requirements.txt      (Dependencies)
├── data/                 (Sample ECG files)
│   ├── normal_ecg.csv
│   ├── pvc_ecg.csv
│   └── afib_ecg.csv
└── README.md            (Usage instructions)
```

### ecg_streamer.py Overview
```python
import serial
import numpy as np
import time

class ECGStreamer:
    def __init__(self, port, baud=115200):
        self.ser = serial.Serial(port, baud)
        
    def stream_ecg(self, ecg_data, sample_rate=360):
        period = 1.0 / sample_rate
        for sample in ecg_data:
            self.send_sample(sample)
            time.sleep(period)
            
    def send_sample(self, value):
        # Convert to 12-bit
        value = int(value) & 0xFFF
        if value > 2047:  # Handle negative (two's complement)
            value = value - 4096
        if value < 0:
            value = (1 << 12) + value
            
        # Send as 2 bytes
        byte1 = value & 0xFF
        byte2 = (value >> 8) & 0x0F
        self.ser.write(bytes([byte1, byte2]))
```

---

## 15. FALLBACK TO OPTION B (PC Display)

### If VGA Fails (Contingency Plan)

**Quick Switch to Option B**:
1. Modify Python to receive CNN results via UART TX
2. Display ECG + results using matplotlib
3. FPGA becomes simple passthrough (UART RX → CNN → UART TX)

**Time to Switch**: 1-2 days

**Files Affected**:
- Python: Add matplotlib display (~100 lines)
- FPGA: Add UART TX module (~same as RX)
- Top-level: Wire UART TX

**Keep as backup if VGA proves difficult!**

---

## 16. REFERENCES & RESOURCES

### UART Resources
- UART Protocol Specification
- FT232 Datasheet (USB-UART bridge)
- Xilinx UART examples (XAPP223)

### Python Resources
- pyserial documentation
- NumPy/Pandas for data manipulation
- MIT-BIH dataset format guides

### FPGA Resources
- Spartan-3E Data Sheet (DS312)
- ISE Design Suite User Guide
- VHDL UART implementations (many online)

### ECG Datasets
- MIT-BIH Arrhythmia Database (physionet.org)
- Kaggle ECG Heartbeat Categorization Dataset

---

**Document Version**: 3.0 (PC-UART Streaming)  
**Last Updated**: January 21, 2026  
**Platform**: Spartan-3E + PC  
**Purpose**: Technical Reference for UART-Based ECG System
