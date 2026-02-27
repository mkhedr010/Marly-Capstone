# ECG Simulation Component - System Architecture
## Spartan-3E SoC with PC UART Streaming

## Document Overview
This document defines the complete architecture for the ECG Simulation & Visualization Component running on Spartan-3E FPGA, receiving ECG data from PC via UART and integrating with on-chip CNN classifier.

**Architecture**: Single Spartan-3E FPGA SoC with PC data source

---

## 1. COMPLETE SYSTEM OVERVIEW

```
┌────────────────────────────────────────────────────────────────────┐
│                         PC (Data Source)                           │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────┐     │
│  │  Python Application (ecg_streamer.py)                    │     │
│  │                                                           │     │
│  │  • Load MIT-BIH ECG Dataset                              │     │
│  │  • Select waveform (Normal/PVC/AFib)                     │     │
│  │  • Stream via UART @ 360 Hz                              │     │
│  │  • Send 12-bit samples as 2 bytes                        │     │
│  └────────────────────────┬─────────────────────────────────┘     │
└────────────────────────────┼────────────────────────────────────────┘
                             │
                             │ USB Cable
                             │ (UART: 115200 baud)
                             │
┌────────────────────────────┼────────────────────────────────────────┐
│                            ▼                                        │
│                    ┌───────────────┐                               │
│                    │  UART RX      │                               │
│                    │  (FT232 chip) │                               │
│                    └───────┬───────┘                               │
│                            │                                        │
│         SPARTAN-3E FPGA    │                                        │
│              (SoC)         │                                        │
│  ┌─────────────────────────▼──────────────────────────────────┐   │
│  │         YOUR SIMULATION COMPONENT                           │   │
│  │                                                              │   │
│  │  ┌──────────────────────────────────────────────────────┐   │   │
│  │  │  UART Receiver Module                                │   │   │
│  │  │  • Receive 12-bit samples from PC                    │   │   │
│  │  │  • Buffer samples                                    │   │   │
│  │  │  • Generate sample_valid signal                      │   │   │
│  │  └────────────────┬─────────────────────────────────────┘   │   │
│  │                   │                                          │   │
│  │                   │ ecg_sample[11:0]                         │   │
│  │                   │ sample_valid                             │   │
│  │                   │                                          │   │
│  │    ┌──────────────┴──────────────┬──────────────────┐       │   │
│  │    │                              │                  │       │   │
│  │    ▼                              ▼                  ▼       │   │
│  │  ┌─────────────┐    ┌──────────────────┐   ┌──────────────┐│   │
│  │  │   VGA       │    │  User Interface  │   │     CNN      ││   │
│  │  │ Controller  │    │  • SW[1:0] Mode  │   │  Interface   ││   │
│  │  │             │    │  • BTN Pause     │   │  (to Ayoub)  ││   │
│  │  │ • Timing    │    │  • LED Status    │   └──────┬───────┘│   │
│  │  │ • Renderer  │    └──────────────────┘          │        │   │
│  │  │ • Scrolling │                                  │        │   │
│  │  └──────┬──────┘                                  │        │   │
│  └─────────┼─────────────────────────────────────────┼────────┘   │
│            │                                          │            │
│            │                                          │            │
│            ▼                                          ▼            │
│     ┌──────────────┐                    ┌────────────────────┐    │
│     │ VGA Monitor  │                    │  AYOUB'S CNN       │    │
│     │ 640×480      │                    │  Classification    │    │
│     │              │                    │  Module            │    │
│     │ Shows:       │                    └─────────┬──────────┘    │
│     │ • ECG trace  │                              │               │
│     │ • Mode       │                              │               │
│     │ • Status     │              ┌───────────────┘               │
│     └──────────────┘              │ cnn_result[1:0]               │
│                                   │ cnn_valid                     │
│                                   ▼                               │
│                          Back to your component                   │
│                          (display on VGA/LEDs)                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## 2. DETAILED FPGA ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ECG SIMULATION COMPONENT (Spartan-3E)                    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                       DATA INPUT (UART)                             │  │
│  │                                                                     │  │
│  │  UART_RX Pin ──▶ ┌──────────────────────────────────────┐          │  │
│  │                  │  UART Receiver Module                 │          │  │
│  │                  │  • Baud: 115200                       │          │  │
│  │                  │  • Data: 8-bit (2 bytes for 12-bit)  │          │  │
│  │                  │  • State machine: Idle→Start→Data→Stop│          │  │
│  │                  └──────────────┬───────────────────────┘          │  │
│  │                                 │                                   │  │
│  │                                 │ ecg_sample[11:0], sample_valid    │  │
│  └─────────────────────────────────┼───────────────────────────────────┘  │
│                                    │                                       │
│  ┌─────────────────────────────────▼───────────────────────────────────┐  │
│  │                       USER INTERFACE                                │  │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐                      │  │
│  │  │ SW[1:0]  │───▶│  Switch  │───▶│  Mode    │                      │  │
│  │  │ (unused) │    │  (future)│    │ (future) │                      │  │
│  │  └──────────┘    └──────────┘    └─────┬────┘                      │  │
│  │                                         │                           │  │
│  │  ┌──────────┐    ┌──────────┐          │                           │  │
│  │  │ BTN[0]   │───▶│  Button  │──────────┼──────────────┐            │  │
│  │  │ Pause    │    │ Debounce │          │              │            │  │
│  │  └──────────┘    └──────────┘          │              │            │  │
│  │                                         ▼              ▼            │  │
│  │  ┌──────────┐                     ┌─────────────────────────┐      │  │
│  │  │ LED[3:0] │◀────────────────────│   LED Controller        │      │  │
│  │  │ Status   │                     │   • UART active         │      │  │
│  │  └──────────┘                     │   • VGA active          │      │  │
│  │                                    │   • CNN result          │      │  │
│  └─────────────────────────────────────┴─────────────────────────────┘  │
│                                    │                                      │
│                                    │ ecg_sample[11:0]                     │
│                                    │ sample_valid                         │
│                                    │                                      │
│                     ┌──────────────┴──────────────┐                       │
│                     │                              │                       │
│       ┌─────────────▼──────┐                      ▼                       │
│       │                    │             ┌─────────────────────┐          │
│       │  VGA CONTROLLER    │             │  CNN INTERFACE      │          │
│       │                    │             │  (Internal Signals) │          │
│       │  ┌──────────────┐  │             │                     │          │
│       │  │ VGA Timing   │  │             │  ecg_sample[11:0]───┼──────▶   │
│       │  │ 640×480@60Hz │  │             │  sample_valid───────┼──────▶   │
│       │  └──────────────┘  │             │  sample_tick────────┼──────▶   │
│       │                    │             │                     │  To CNN  │
│       │  ┌──────────────┐  │             │  cnn_result[1:0]◀───┼──────▶   │
│       │  │ ECG Renderer │  │             │  cnn_valid◀─────────┼──────▶   │
│       │  │ • Buffer     │  │             └─────────────────────┘          │
│       │  │   (640 samp) │  │                                              │
│       │  │ • Y-Mapping  │  │                                              │
│       │  │ • Scrolling  │  │                                              │
│       │  └──────┬───────┘  │                                              │
│       │         │          │                                              │
│       │         ▼          │                                              │
│       │  ┌──────────────┐  │                                              │
│       │  │ RGB Output   │──┼────────────────────────────────────────▶     │
│       │  │ HSYNC, VSYNC │  │                            To VGA Monitor    │
│       │  └──────────────┘  │                                              │
│       └────────────────────┘                                              │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                     CLOCK MANAGEMENT                                │  │
│  │  ┌──────────┐     ┌──────────────┐      ┌──────────────┐           │  │
│  │  │ 50 MHz   │────▶│ Clock Divider│─────▶│  25 MHz VGA  │           │  │
│  │  │ Onboard  │     │   (÷2)       │      │  Pixel Clock │           │  │
│  │  └──────────┘     └──────────────┘      └──────────────┘           │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. DATA FLOW DIAGRAM

```
PC DATA SOURCE          UART LINK               FPGA PROCESSING              OUTPUTS
══════════════          ═════════               ═══════════════              ═══════

┌──────────────┐
│  Python      │
│  ecg_stream  │
│              │
│ • Load CSV   │
│ • Normal     │
│ • PVC        │        ┌─────────────────┐
│ • AFib       │───────▶│  USB-UART       │
│              │  USB   │  FT232 Chip     │
│ • Send       │        │  (on board)     │
│   @ 360 Hz   │        └────────┬────────┘
└──────────────┘                 │
                                 │ UART RX
                                 │ 115200 baud
                                 │
                      ┌──────────▼───────────┐
                      │  UART Receiver       │
                      │  • Start bit detect  │
                      │  • 8-bit deserialize │
                      │  • Assemble 12-bit   │
                      │  • Generate valid    │
                      └──────────┬───────────┘
                                 │ ecg_sample[11:0]
                                 │ sample_valid
                                 │
                 ┌───────────────┴──────────────┐
                 │                              │
                 ▼                              ▼
    ┌────────────────────────┐    ┌────────────────────────┐
    │  VGA Controller        │    │  CNN Interface         │
    │                        │    │  (Internal)            │
    │  ┌──────────────────┐  │    │                        │
    │  │ Waveform Buffer  │  │    │  ecg_sample[11:0] ──────┼──▶ To
    │  │ Write @ arrival  │  │    │  sample_valid ───────────┼──▶ CNN
    │  │ Read  @ 25 MHz   │  │    │  sample_tick (optional)──┼──▶ Module
    │  └────────┬─────────┘  │    │                        │
    │           │            │    │  cnn_result[1:0] ◀───────┼──▶
    │           ▼            │    │  cnn_valid ◀─────────────┼──▶
    │  ┌──────────────────┐  │    └────────────────────────┘
    │  │ Y Coordinate     │  │
    │  │ Calculator       │  │              ┌──────────┐
    │  │ Y = 240-(S/10)   │  │              │ LED[3:0] │
    │  └────────┬─────────┘  │              └────▲─────┘
    │           │            │                   │
    │           ▼            │         ┌─────────┴─────────┐
    │  ┌──────────────────┐  │         │  Status Display   │
    │  │ VGA Timing Gen   │  │         │  • UART RX active │
    │  │ (H/V counters)   │  │         │  • VGA displaying │
    │  └────────┬─────────┘  │         │  • CNN result     │
    │           │            │         └───────────────────┘
    │           ▼            │
    │  ┌──────────────────┐  │
    │  │ Pixel Generator  │  │
    │  │ (RGB logic)      │  │
    │  └────────┬─────────┘  │
    └───────────┼────────────┘
                │
                ▼
         ┌──────────────┐
         │ VGA_R[2:0]   │──▶ To VGA Monitor
         │ VGA_G[2:0]   │──▶
         │ VGA_B[1:0]   │──▶
         │ HSYNC        │──▶
         │ VSYNC        │──▶
         └──────────────┘
```

---

## 4. TIMING DIAGRAM

```
Time Scale: Not to scale (relationships shown)

50 MHz Clock (System)
    _   _   _   _   _   _   _   _   _   _   _   _   _   _   _
___| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |___
   |<--- 20 ns --->|


25 MHz Clock (VGA Pixel)
    _____       _____       _____       _____       _____
___|     |_____|     |_____|     |_____|     |_____|     |_______
   |<--- 40 ns --->|


UART RX (115200 baud)
    ____      _______________________________________________      ____
___|    |____|_____|_____|_____|_____|_____|_____|_____|____|____|    |___
   Start   D0   D1   D2   D3   D4   D5   D6   D7   Stop
   |<-------------- 86.8 μs (1 byte) ------------->|


ECG Sample Arrival (from PC @ ~360 Hz)
          ________________
_________|                |_____________________________________...
         |  Valid Sample  |
         | (12-bit)       |
         |<-- 2.78 ms -->|


Waveform Buffer Update
         ┌─────┐                           ┌─────┐
_________|     |___________________________|     |___________________...
         Update                            Update
         X=0                               X=1
         (on each sample_valid from UART)


VGA Horizontal Sync (31.77 μs period)
    ____________________________________________________________________     ____
___|                                                                    |___|
   |<-------------------------- 31.77 μs ---------------------------->|


VGA Vertical Sync (16.68 ms period)
    ______________________________________________________________________
___|                                                                      |___
   |<-------------------------- 16.68 ms ---------------------------->|


Clock Domain Summary:
┌──────────────┬───────────┬────────────────────────────┐
│ Domain       │ Frequency │ Purpose                    │
├──────────────┼───────────┼────────────────────────────┤
│ System       │ 50 MHz    │ Main logic, UART RX        │
│ VGA Pixel    │ 25 MHz    │ Pixel clock for display    │
│ UART Bit     │ 115200 Hz │ Serial data reception      │
│ Sample Rate  │ ~360 Hz   │ ECG arrival from PC        │
│ VGA Frame    │ 60 Hz     │ Screen refresh             │
└──────────────┴───────────┴────────────────────────────┘
```

---

## 5. MODULE HIERARCHY & SPECIFICATIONS

### 5.1 Top-Level Module: `ecg_system_top`

**Purpose**: Top-level wrapper for complete SoC

**Port List**:
```vhdl
entity ecg_system_top is
    generic (
        CLK_FREQ        : integer := 50_000_000;   -- 50 MHz
        UART_BAUD       : integer := 115200;       -- UART baud rate
        VGA_PIXEL_FREQ  : integer := 25_000_000    -- 25 MHz
    );
    port (
        -- Clock and Reset
        clk_50mhz    : in  std_logic;
        reset_n      : in  std_logic;
        
        -- UART Interface (from PC)
        uart_rx      : in  std_logic;
        
        -- User Interface
        sw           : in  std_logic_vector(1 downto 0);   -- Future use
        btn          : in  std_logic_vector(0 downto 0);   -- Pause
        led          : out std_logic_vector(3 downto 0);   -- Status
        
        -- VGA Output
        vga_hsync    : out std_logic;
        vga_vsync    : out std_logic;
        vga_r        : out std_logic_vector(2 downto 0);
        vga_g        : out std_logic_vector(2 downto 0);
        vga_b        : out std_logic_vector(1 downto 0);
        
        -- CNN Interface (Internal - connects to Ayoub's module)
        cnn_sample   : out std_logic_vector(11 downto 0);
        cnn_valid    : out std_logic;
        cnn_result   : in  std_logic_vector(1 downto 0);
        cnn_result_valid : in  std_logic
    );
end ecg_system_top;
```

---

### 5.2 Module: `uart_receiver` ⭐ **NEW!**

**Purpose**: Receive 12-bit ECG samples from PC via UART

**Port List**:
```vhdl
entity uart_receiver is
    generic (
        CLK_FREQ  : integer := 50_000_000;
        BAUD_RATE : integer := 115200
    );
    port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;
        
        -- UART input
        uart_rx      : in  std_logic;
        
        -- ECG output (12-bit samples sent as 2 bytes)
        ecg_sample   : out std_logic_vector(11:0);
        sample_valid : out std_logic;   -- Pulses high when new sample ready
        
        -- Status
        uart_error   : out std_logic;   -- Frame error
        uart_active  : out std_logic    -- Receiving data
    );
end uart_receiver;
```

**Functionality**:
- Sample UART RX line @ 16× baud rate (1.8432 MHz from 50 MHz)
- State machine: IDLE → START_BIT → DATA_BITS[7:0] → STOP_BIT
- Receive 2 bytes per ECG sample:
  - Byte 1: Lower 8 bits [7:0]
  - Byte 2: Upper 4 bits [11:8] + padding
- Assemble into 12-bit sample
- Assert sample_valid for 1 cycle when complete

**Implementation Notes**:
- Baud rate divider: 50,000,000 / 115,200 = 434 (for bit period)
- Oversampling: 16× = 50,000,000 / (115,200 × 16) = 27 clocks per sample
- Start bit detection by falling edge
- Frame error if stop bit not high

---

### 5.3 Module: `clk_divider`

**Purpose**: Generate 25 MHz pixel clock from 50 MHz

**Port List**:
```vhdl
entity clk_divider is
    port (
        clk_in   : in  std_logic;  -- 50 MHz
        reset_n  : in  std_logic;
        clk_out  : out std_logic   -- 25 MHz
    );
end clk_divider;
```

---

### 5.4 Module: `vga_timing_generator`

**Purpose**: Generate VGA sync signals (unchanged from original)

**Port List**:
```vhdl
entity vga_timing_generator is
    port (
        clk_pixel   : in  std_logic;  -- 25 MHz
        reset_n     : in  std_logic;
        
        hsync       : out std_logic;
        vsync       : out std_logic;
        display_on  : out std_logic;
        
        pixel_x     : out std_logic_vector(9 downto 0);
        pixel_y     : out std_logic_vector(9 downto 0)
    );
end vga_timing_generator;
```

---

### 5.5 Module: `ecg_vga_renderer`

**Purpose**: Display scrolling ECG waveform (updated for UART input)

**Port List**:
```vhdl
entity ecg_vga_renderer is
    generic (
        WAVEFORM_WIDTH : integer := 640
    );
    port (
        clk_pixel     : in  std_logic;  -- 25 MHz
        clk_system    : in  std_logic;  -- 50 MHz
        reset_n       : in  std_logic;
        
        -- VGA timing inputs
        pixel_x       : in  std_logic_vector(9 downto 0);
        pixel_y       : in  std_logic_vector(9 downto 0);
        display_on    : in  std_logic;
        
        -- ECG sample input (from UART, not on fixed tick)
        ecg_sample    : in  std_logic_vector(11 downto 0);
        sample_valid  : in  std_logic;  -- From UART receiver
        
        -- RGB output
        vga_r         : out std_logic_vector(2 downto 0);
        vga_g         : out std_logic_vector(2 downto 0);
        vga_b         : out std_logic_vector(1 downto 0)
    );
end ecg_vga_renderer;
```

**Key Change**: Uses `sample_valid` from UART instead of internal `sample_tick`

---

### 5.6 Module: `user_interface_controller`

**Purpose**: Handle buttons/LEDs (simplified - no mode selection needed)

**Port List**:
```vhdl
entity user_interface_controller is
    generic (
        CLK_FREQ        : integer := 50_000_000;
        DEBOUNCE_MS     : integer := 50
    );
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        
        -- Physical inputs
        btn             : in  std_logic_vector(0 downto 0);  -- Pause
        
        -- Status inputs
        uart_active     : in  std_logic;
        cnn_result      : in  std_logic_vector(1 downto 0);
        cnn_valid       : in  std_logic;
        
        -- Control outputs
        system_enable   : out std_logic;  -- System pause
        
        -- LED outputs
        led             : out std_logic_vector(3 downto 0)
    );
end user_interface_controller;
```

**LED Mapping**:
- LED[0]: UART receiving data
- LED[1]: VGA displaying (always on)
- LED[2]: System paused (from button)
- LED[3]: CNN result (if valid)

---

### 5.7 Module: `cnn_interface`

**Purpose**: Connect to Ayoub's CNN module (internal signals)

**Port List**:
```vhdl
entity cnn_interface is
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        
        -- From UART receiver
        ecg_sample_in   : in  std_logic_vector(11 downto 0);
        sample_valid_in : in  std_logic;
        
        -- To CNN module (Ayoub's)
        cnn_sample      : out std_logic_vector(11 downto 0);
        cnn_valid       : out std_logic;
        
        -- From CNN module
        cnn_result      : in  std_logic_vector(1 downto 0);
        cnn_result_valid: in  std_logic
    );
end cnn_interface;
```

**Functionality**: Simple passthrough with optional buffering

---

## 6. RESOURCE ESTIMATION

### FPGA Resources (Spartan-3E XC3S500E)

| Resource Type    | Usage Estimate | Total Available | Percentage |
|------------------|----------------|-----------------|------------|
| Logic Cells      | ~1,500         | 10,476          | ~14%       |
| Block RAM (18Kb) | 1-2 blocks     | 20 blocks       | ~7%        |
| DCM              | 0              | 4               | 0%         |
| I/O Pins         | ~15            | 232             | ~6%        |

**Reduction from Original**: No longer need 3 BRAM blocks for ECG storage!

**BRAM Usage**:
- Waveform Buffer only: 1-2 blocks (640×12-bit)

---

## 7. PC-TO-FPGA INTERFACE SPECIFICATION

### UART Protocol

**Settings**:
- Baud Rate: 115200 bps
- Data Bits: 8
- Stop Bits: 1
- Parity: None
- Flow Control: None

**Data Format** (per ECG sample):
```
Byte 1: ecg_sample[7:0]   (lower 8 bits)
Byte 2: 0000 + ecg_sample[11:8]  (upper 4 bits, padded)
```

**Timing**:
- Sample rate: ~360 Hz from PC
- Bytes per sample: 2
- Total baud requirement: 360 × 2 × 10 bits = 7,200 bps
- 115200 baud >> 7200 bps ✓ (plenty of margin)

**Example Python Transmission**:
```python
import serial
import struct

ser = serial.Serial('COM3', 115200)

# Send 12-bit sample (example: 0x5A3)
sample = 0x5A3  # 12-bit value
byte1 = sample & 0xFF        # Lower 8 bits: 0xA3
byte2 = (sample >> 8) & 0x0F  # Upper 4 bits: 0x05

ser.write(bytes([byte1, byte2]))
```

---

## 8. SYSTEM ARCHITECTURE COMPARISON

### Original Design (BRAM-based)
```
ECG Storage → BRAM (3 waveforms) → Sample Gen → VGA + CNN
```
- ❌ Limited to 3 pre-stored waveforms
- ❌ Requires BRAM initialization (complex)
- ❌ Hard to change datasets

### UART Design (PC-based)
```
PC Stream → UART RX → VGA + CNN
```
- ✅ Unlimited waveforms (any MIT-BIH data)
- ✅ No BRAM initialization needed
- ✅ Easy to test with different datasets
- ✅ Real-time streaming capability

---

## 9. DESIGN DECISIONS RATIONALE

### Decision 1: UART Over Other Interfaces

| Interface | Speed | Complexity | Availability | Chosen |
|-----------|-------|------------|--------------|--------|
| SPI | Fast | Medium | Need adapter | ❌ |
| I2C | Slow | Medium | Need adapter | ❌ |
| Parallel GPIO | Very Fast | Low | Need many pins | ❌ |
| **UART** | **Adequate** | **Low** | **Built-in** | ✅ |

**Rationale**:
- Spartan-3E boards have USB-UART bridge (FT232 chip)
- No additional hardware needed
- 115200 baud easily handles 360 Hz × 12-bit
- Simple protocol, well-documented
- Python pyserial library makes PC side trivial

### Decision 2: 115200 Baud Rate

**Calculation**:
```
Required: 360 samples/sec × 2 bytes × 10 bits/byte = 7,200 bps
Available: 115,200 bps
Margin: 115,200 / 7,200 = 16× overhead ✓
```

**Why not faster?**
- 115200 is standard, well-supported
- Plenty of margin for timing variations
- Easy to generate from 50 MHz (divider = 434)

### Decision 3: 2-Byte Transmission per Sample

**Format**: 
- Byte 1: [7:0] (lower 8 bits)
- Byte 2: [11:8] (upper 4 bits) + 4 padding bits

**Why 2 bytes?**
- UART transmits 8-bit chunks
- Simple to assemble on FPGA side
- Padding bits can be used for future flags/commands

**Alternative Considered**: 3 bytes with checksumming → Rejected (unnecessary complexity)

---

## 10. INTEGRATION POINTS

### With PC (Python Application)
**Your Responsibilities**:
- Provide UART specs (baud, format)
- Test with loopback first
- Verify sample rate timing

**PC Provides**:
- ECG dataset streaming
- Consistent 360 Hz rate
- Proper byte formatting

### With CNN Module (Ayoub's Component)
**Interface Signals** (internal FPGA):**
```vhdl
-- To CNN
signal cnn_sample : std_logic_vector(11 downto 0);
signal cnn_valid  : std_logic;

-- From CNN
signal cnn_result : std_logic_vector(1 downto 0);  -- Classification
signal cnn_result_valid : std_logic;
```

**No GPIO needed - internal FPGA signals!**

---

## 11. TESTING STRATEGY

### Level 1: UART Reception Test
1. Python sends known pattern (0x000, 0x001, 0x002, ...)
2. FPGA receives and displays on LEDs
3. Verify byte assembly correct
4. Check error detection

### Level 2: VGA Display Test
1. Python streams constant value
2. Verify appears on VGA as flat line
3. Stream sine wave pattern
4. Verify appears as sine wave on VGA

### Level 3: ECG Waveform Test
1. Stream real ECG (Normal)
2. Verify ECG features visible (P, QRS, T)
3. Test all 3 types (Normal, PVC, AFib)
4. Verify scrolling smooth

### Level 4: CNN Integration Test
1. Stream known Normal ECG
2. Verify CNN receives samples
3. Check CNN classification result
4. Display result on LED/VGA

---

## 12. NEXT STEPS (IMPLEMENTATION ORDER)

### Phase 1: UART Module (Week 1)
1. Implement uart_receiver.vhd
2. Create testbench (simulate UART protocol)
3. Test on hardware with Python loopback

### Phase 2: VGA Display (Week 2-3)
4. Implement VGA modules (from original design)
5. Test with test pattern
6. Add ECG rendering

### Phase 3: Integration (Week 4)
7. Connect UART → VGA
8. Python streams ECG
9. Verify display

### Phase 4: CNN Connection (Week 5)
10. Add CNN interface
11. Test with Ayoub's module
12. Display classification

---

**Document Version**: 3.0 (PC-UART-FPGA)  
**Created**: January 21, 2026  
**Platform**: Spartan-3E + PC  
**Status**: Ready for Implementation
