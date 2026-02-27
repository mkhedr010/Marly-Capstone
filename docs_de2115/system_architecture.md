# ECG Simulation Component - System Architecture
## DE2-115 FPGA with Audio Interface to CNN Board

## Document Overview
This document defines the complete architecture for the ECG Simulation & Visualization Component running on DE2-115 FPGA, which transmits ECG data via 3.5mm audio jack to a separate Spartan-3E board running the CNN classifier.

---

## 1. TWO-BOARD SYSTEM OVERVIEW

```
┌──────────────────────────────────────────────────────────────────┐
│                    BOARD 1: DE2-115 FPGA                         │
│              (ECG Simulation & Visualization)                    │
│                                                                  │
│  ┌────────────────────┐        ┌─────────────────┐             │
│  │  User Interface    │        │  VGA Display    │             │
│  │  SW, BTN, LED      │        │  640×480@60Hz   │             │
│  └──────────┬─────────┘        └────────┬────────┘             │
│             │                           │                       │
│             ▼                           ▼                       │
│  ┌──────────────────────────────────────────────┐              │
│  │         ECG Data Management                   │              │
│  │  • M9K Memory (3 waveforms)                  │              │
│  │  • Sample Generator (360 Hz)                 │              │
│  │  • Address Controller                        │              │
│  └──────────┬───────────────────────────────────┘              │
│             │                                                   │
│             ├─────────────┬────────────────┐                   │
│             │             │                │                   │
│             ▼             ▼                ▼                   │
│  ┌────────────────┐  ┌──────────┐  ┌──────────────┐          │
│  │  VGA Renderer  │  │  Audio   │  │  Audio Level │          │
│  │  (Scrolling)   │  │  Output  │  │  LEDs        │          │
│  └────────────────┘  │  WM8731  │  └──────────────┘          │
│                      │  Codec   │                             │
│                      └────┬─────┘                             │
│                           │                                    │
│                           │ 3.5mm                              │
└───────────────────────────┼────────────────────────────────────┘
                            │ Audio Jack
                            │ (Analog Audio)
                            │
                     ┌──────▼───────┐
                     │  Audio Cable │
                     │  (Stereo)    │
                     └──────┬───────┘
                            │
┌───────────────────────────┼────────────────────────────────────┐
│                           │ 3.5mm                              │
│                           │ Line In                             │
│                      ┌────▼─────┐                             │
│                      │   ADC    │                             │
│                      │  (Audio  │                             │
│                      │   Input) │                             │
│                      └────┬─────┘                             │
│                           │                                    │
│                           ▼                                    │
│  ┌──────────────────────────────────────────────┐             │
│  │      CNN Classifier Module                    │             │
│  │  • Signal Processing                          │             │
│  │  • Feature Extraction                         │             │
│  │  • Neural Network                             │             │
│  │  • Classification (Normal/PVC/AFib)          │             │
│  └──────────────────────────────────────────────┘             │
│                                                                │
│                BOARD 2: Spartan-3E FPGA                        │
│                  (CNN Classifier - Team)                        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. DETAILED BOARD 1 ARCHITECTURE (DE2-115)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ECG SIMULATION COMPONENT (DE2-115)                      │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                          USER INTERFACE                             │  │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐                      │  │
│  │  │ SW[1:0]  │───▶│  Switch  │───▶│  Mode    │                      │  │
│  │  │ Switches │    │ Debounce │    │ Control  │                      │  │
│  │  └──────────┘    └──────────┘    └─────┬────┘                      │  │
│  │                                         │                           │  │
│  │  ┌──────────┐    ┌──────────┐          │                           │  │
│  │  │ KEY[0]   │───▶│  Button  │──────────┼──────────────┐            │  │
│  │  │ Button   │    │ Debounce │          │              │            │  │
│  │  └──────────┘    └──────────┘          │              │            │  │
│  │                                         ▼              ▼            │  │
│  │  ┌────────────┐                  ┌─────────────────────────┐       │  │
│  │  │ LEDR[17:0] │◀─────────────────│   LED Controller        │       │  │
│  │  │ LEDG[8:0]  │                  └─────────────────────────┘       │  │
│  │  └────────────┘                                                    │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                       │                                    │
│                                       ▼                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                      ECG DATA MANAGEMENT                            │  │
│  │                                                                     │  │
│  │  ┌──────────────────────────────────────────────────────────┐      │  │
│  │  │             ECG MEMORY (M9K Block RAM)                   │      │  │
│  │  │                                                          │      │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │      │  │
│  │  │  │  Normal ECG │  │   PVC ECG   │  │  AFib ECG   │     │      │  │
│  │  │  │ 360 samples │  │ 360 samples │  │ 360 samples │     │      │  │
│  │  │  │   12-bit    │  │   12-bit    │  │   12-bit    │     │      │  │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘     │      │  │
│  │  │                                                          │      │  │
│  │  └────────────────────────┬─────────────────────────────────┘      │  │
│  │                           │                                         │  │
│  │  ┌────────────────────────▼──────────────────────────┐             │  │
│  │  │        Address Generator & Sample Controller      │             │  │
│  │  │  • 360 Hz Sample Tick Generator (from 50 MHz)    │             │  │
│  │  │  • Address Counter (0-359)                       │             │  │
│  │  │  • Waveform Selector (based on mode)             │             │  │
│  │  │  • Playback Control (start/pause)                │             │  │
│  │  └────────────────────┬──────────────┬───────────────┘             │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                          │              │                                 │
│                          │              │                                 │
│       ┌──────────────────▼──────┐       ▼                                 │
│       │                         │  ┌─────────────────────────┐            │
│       │   VGA CONTROLLER        │  │  AUDIO OUTPUT (NEW!)    │            │
│       │                         │  │                         │            │
│       │  ┌──────────────────┐   │  │  ┌──────────────────┐  │            │
│       │  │  VGA Timing Gen  │   │  │  │ Sample Upsampler │  │            │
│       │  │  (640×480@60Hz)  │   │  │  │ 360Hz→48kHz      │  │            │
│       │  └──────────────────┘   │  │  └────────┬─────────┘  │            │
│       │                         │  │           │            │            │
│       │  ┌──────────────────┐   │  │  ┌────────▼─────────┐  │            │
│       │  │  ECG Renderer    │   │  │  │ I2S Transmitter  │  │            │
│       │  │  • Waveform      │   │  │  │ (WM8731 Codec)   │  │            │
│       │  │    Buffer        │   │  │  └────────┬─────────┘  │            │
│       │  │  • Y-Mapping     │   │  │           │            │            │
│       │  │  • Pixel Gen     │   │  │  ┌────────▼─────────┐  │            │
│       │  └──────────────────┘   │  │  │ I2C Controller   │  │            │
│       │           │              │  │  │ (Codec Config)   │  │            │
│       │           ▼              │  │  └──────────────────┘  │            │
│       │  ┌──────────────────┐   │  │                         │            │
│       │  │  VGA_R[3:0]      │───┼──┼─────────────────────────────────▶   │
│       │  │  VGA_G[3:0]      │   │  │                 To VGA Monitor      │
│       │  │  VGA_B[3:0]      │───┼──┼─────────────────────────────────▶   │
│       │  │  HSYNC, VSYNC    │   │  │                                     │
│       │  └──────────────────┘   │  │                                     │
│       └─────────────────────────┘  │  ┌──────────────────┐               │
│                                    │  │ AUD_BCLK        │──┼───────────▶  │
│                                    │  │ AUD_DACLRCK     │──┼───────────▶  │
│                                    │  │ AUD_DACDAT      │──┼───────────▶  │
│                                    │  │ I2C_SCLK        │──┼───────────▶  │
│                                    │  │ I2C_SDAT        │◄─┼───────────▶  │
│                                    │  └──────────────────┘  │   To WM8731 │
│                                    └─────────────────────────┘   3.5mm Out│
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                     CLOCK MANAGEMENT                                │  │
│  │  ┌──────────┐     ┌──────────────┐      ┌──────────────┐           │  │
│  │  │ 50 MHz   │────▶│ Clock Divider│─────▶│  25 MHz VGA  │           │  │
│  │  │ Onboard  │     │   (÷2)       │      │  Pixel Clock │           │  │
│  │  │ Clock    │     └──────────────┘      └──────────────┘           │  │
│  │  └────┬─────┘                                                       │  │
│  │       │                                                             │  │
│  │       │            ┌──────────────┐                                 │  │
│  │       └───────────▶│     PLL      │                                 │  │
│  │                    │  50→48 MHz   │─────▶ Audio I2S Clock           │  │
│  │                    └──────────────┘                                 │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. DATA FLOW DIAGRAM (TWO-BOARD SYSTEM)

```
BOARD 1 (DE2-115)           PROCESSING PIPELINE              OUTPUTS
═════════════════           ════════════════════             ═══════════

USER INPUTS
┌──────────┐
│ SW[1:0]  │──┐
└──────────┘  │
              │            ┌─────────────────┐
┌──────────┐  ├───────────▶│  Mode Selector  │
│ KEY[0]   │──┘            │  • Debounce     │
└──────────┘               │  • Edge Detect  │
                           └────────┬─────────┘
                                    │ mode[1:0], enable
                                    ▼
                           ┌──────────────────────┐
                           │  Sample Controller   │
                           │  ┌────────────────┐  │
          50 MHz ─────────▶│  │ Clock Divider  │  │
                           │  │ ÷138,889       │  │
                           │  └───────┬────────┘  │
                           │          │           │
                           │          ▼ 360 Hz    │
                           │  ┌────────────────┐  │
                           │  │ Address Gen    │  │
                           │  │ Counter (0-359)│  │
                           │  └───────┬────────┘  │
                           └──────────┼───────────┘
                                      │ address[8:0]
                                      ▼
                           ┌──────────────────────┐
                           │   ECG MEMORY (M9K)   │
                           │                      │
                           │  Base Addr Decode:   │
                           │  mode=00 → 0x000     │
                           │  mode=01 → 0x168     │
                           │  mode=10 → 0x2D0     │
                           │                      │
                           │  Read: addr + base   │
                           └──────────┬───────────┘
                                      │ ecg_sample[11:0]
                                      │
                      ┌───────────────┴──────────────┬─────────────────┐
                      │                              │                 │
                      ▼                              ▼                 ▼
         ┌────────────────────────┐    ┌────────────────────┐  ┌──────────────┐
         │  VGA Renderer          │    │  Audio Upsampler   │  │  LED Display │
         │                        │    │  360Hz → 48kHz     │  │              │
         │  ┌──────────────────┐  │    │                    │  └──────────────┘
         │  │ Waveform Buffer  │  │    │  ┌──────────────┐  │
         │  │ (640 samples)    │  │    │  │ Hold & Repeat│  │
         │  └────────┬─────────┘  │    │  │ (133x each)  │  │
         │           │            │    │  └──────┬───────┘  │
         │           ▼            │    │         │          │
         │  ┌──────────────────┐  │    │         ▼          │
         │  │ Y Coordinate     │  │    │  ┌──────────────┐  │
         │  │ Calculator       │  │    │  │ I2S Transmit │  │
         │  │ Y = 240-(S/10)   │  │    │  │ (WM8731)     │  │
         │  └────────┬─────────┘  │    │  └──────┬───────┘  │
         │           │            │    │         │          │
         │           ▼            │    │         ▼          │
         │  ┌──────────────────┐  │    │  ┌──────────────┐  │
         │  │ VGA Timing Gen   │  │    │  │ I2C Config   │  │
         │  │ (H/V counters)   │  │    │  │ (Codec Init) │  │
         │  └────────┬─────────┘  │    │  └──────────────┘  │
         │           │            │    │                    │
         │           ▼            │    └──────────┬─────────┘
         │  ┌──────────────────┐  │               │
         │  │ Pixel Generator  │  │               │ I2S Signals
         │  │ (RGB logic)      │  │               │
         │  └────────┬─────────┘  │               ▼
         └───────────┼────────────┘        ┌──────────────┐
                     │                     │  WM8731      │
                     ▼                     │  Audio CODEC │
              ┌──────────────┐             └──────┬───────┘
              │ VGA_R[3:0]   │──▶                 │
              │ VGA_G[3:0]   │──▶ To VGA          │ Analog Audio
              │ VGA_B[3:0]   │──▶ Monitor         │
              │ HSYNC        │──▶                 ▼
              │ VSYNC        │──▶          ┌──────────────┐
              └──────────────┘             │  3.5mm Jack  │
                                           │  (Line Out)  │
                                           └──────┬───────┘
                                                  │
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━━━━━━━━━━━━━━━
                       AUDIO CABLE                │
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┼━━━━━━━━━━━━━━━━
                                                  │
BOARD 2 (Spartan-3E)                              │
                                           ┌──────▼───────┐
                                           │  3.5mm Jack  │
                                           │  (Line In)   │
                                           └──────┬───────┘
                                                  │ Analog Audio
                                                  ▼
                                           ┌──────────────┐
                                           │     ADC      │
                                           │  (Audio In)  │
                                           └──────┬───────┘
                                                  │ Digital
                                                  ▼
                                    ┌──────────────────────────┐
                                    │  Signal Conditioning     │
                                    │  • Downsample 48k→360Hz  │
                                    │  • Extract 12-bit samples│
                                    └──────────┬───────────────┘
                                               │
                                               ▼
                                    ┌──────────────────────────┐
                                    │    CNN Classifier        │
                                    │  • Feature Extraction    │
                                    │  • Neural Network        │
                                    │  • Classification Output │
                                    └──────────────────────────┘
                                               │
                                               ▼
                                         Classification
                                         Result (N/V/A)
```

---

## 4. TIMING DIAGRAM (UPDATED WITH AUDIO)

```
Time Scale: Not to scale (relationships shown)

50 MHz Clock (System)
    _   _   _   _   _   _   _   _   _   _   _   _   _   _   _
___| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |___
   |<--- 20 ns --->|


48 MHz Clock (Audio - from PLL)  **NEW!**
    _   _   _   _   _   _   _   _   _   _   _   _   _   _
___| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |_______
   |<-- 20.8 ns -->|


25 MHz Clock (VGA Pixel)
    _____       _____       _____       _____       _____
___|     |_____|     |_____|     |_____|     |_____|     |_______
   |<--- 40 ns --->|


Sample Tick (360 Hz)
          ____
_________|    |_____________________________________________...
         |<2.78 ms>|
         Sample N   Sample N+1


ECG Sample Out [11:0]
_________XXXXXXXXXXXX_______________________________________...
         |  Valid   |
         | Sample N |


I2S Audio Clock (BCLK @ 3.072 MHz)  **NEW!**
  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _  _
_| || || || || || || || || || || || || || || || || || || || |__
 |<>|  326 ns period (3.072 MHz)


I2S L/R Clock (LRCK @ 48 kHz)  **NEW!**
  ___________________                    ___________________
_|                   |__________________|                   |___
 |<---- 20.8 μs ---->|  (48 kHz)


Audio Sample Upsampling:
ECG Sample N held for 133 audio frames @ 48 kHz = 2.77 ms


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
│ System       │ 50 MHz    │ Main logic, sample gen     │
│ Audio I2S    │ 48 MHz    │ Audio codec clock (PLL)    │
│ I2S Bit Clk  │ 3.072 MHz │ I2S serial clock           │
│ VGA Pixel    │ 25 MHz    │ Pixel clock for display    │
│ Sample Rate  │ 360 Hz    │ ECG data update rate       │
│ Audio Frame  │ 48 kHz    │ Audio sample rate          │
│ VGA Frame    │ 60 Hz     │ Screen refresh             │
└──────────────┴───────────┴────────────────────────────┘
```

---

## 5. MODULE HIERARCHY & SPECIFICATIONS

### 5.1 Top-Level Module: `ecg_system_top`

**Purpose**: Top-level wrapper for DE2-115, instantiates all subsystems

**Port List**:
```vhdl
entity ecg_system_top is
    generic (
        CLK_FREQ        : integer := 50_000_000;  -- 50 MHz
        SAMPLE_RATE     : integer := 360;         -- 360 Hz
        VGA_PIXEL_FREQ  : integer := 25_000_000;  -- 25 MHz
        AUDIO_FREQ      : integer := 48_000       -- 48 kHz
    );
    port (
        -- Clock and Reset
        clk_50mhz    : in  std_logic;
        reset_n      : in  std_logic;
        
        -- User Interface (DE2-115)
        sw           : in  std_logic_vector(17 downto 0);  -- 18 switches
        key          : in  std_logic_vector(3 downto 0);   -- 4 buttons (active low)
        ledr         : out std_logic_vector(17 downto 0);  -- 18 red LEDs
        ledg         : out std_logic_vector(8 downto 0);   -- 9 green LEDs
        
        -- VGA Output
        vga_clk      : out std_logic;
        vga_blank_n  : out std_logic;
        vga_sync_n   : out std_logic;
        vga_hs       : out std_logic;
        vga_vs       : out std_logic;
        vga_r        : out std_logic_vector(3 downto 0);   -- 4-bit red
        vga_g        : out std_logic_vector(3 downto 0);   -- 4-bit green
        vga_b        : out std_logic_vector(3 downto 0);   -- 4-bit blue
        
        -- Audio Output (WM8731) **NEW!**
        aud_bclk     : out std_logic;       -- I2S bit clock
        aud_daclrck  : out std_logic;       -- I2S L/R clock
        aud_dacdat   : out std_logic;       -- I2S data
        i2c_sclk     : out std_logic;       -- I2C clock for codec config
        i2c_sdat     : inout std_logic      -- I2C data for codec config
    );
end ecg_system_top;
```

**Internal Signals**:
```vhdl
-- Clock domain signals
signal clk_25mhz         : std_logic;
signal clk_48mhz         : std_logic;  -- NEW for audio
signal pll_locked        : std_logic;

-- Mode control
signal ecg_mode          : std_logic_vector(1 downto 0);
signal playback_enable   : std_logic;

-- Sample generation
signal sample_tick_int   : std_logic;
signal ecg_sample_int    : std_logic_vector(11 downto 0);
signal sample_address    : std_logic_vector(8 downto 0);

-- VGA signals
signal vga_x             : std_logic_vector(9 downto 0);
signal vga_y             : std_logic_vector(9 downto 0);
signal vga_display_on    : std_logic;

-- Audio signals (NEW)
signal audio_sample      : std_logic_vector(15 downto 0);
signal audio_valid       : std_logic;
```

---

### 5.2 Module: `pll_50to48` **NEW!**

**Purpose**: Generate 48 MHz audio clock from 50 MHz system clock using Altera PLL

**Port List**:
```vhdl
entity pll_50to48 is
    port (
        inclk0  : in  std_logic;  -- 50 MHz input
        c0      : out std_logic;  -- 48 MHz output
        c1      : out std_logic;  -- 25 MHz output (VGA)
        locked  : out std_logic   -- PLL lock status
    );
end pll_50to48;
```

**PLL Configuration** (using Altera MegaWizard):
- Input: 50 MHz
- Output 0 (c0): 48 MHz for audio
- Output 1 (c1): 25 MHz for VGA
- Multiplication/Division: 48/50 = 0.96

---

### 5.3 Module: `audio_output_controller` **NEW!**

**Purpose**: Complete audio output chain (upsampling + I2S + I2C)

**Port List**:
```vhdl
entity audio_output_controller is
    port (
        clk_50mhz     : in  std_logic;
        clk_48mhz     : in  std_logic;
        reset_n       : in  std_logic;
        
        -- ECG sample input (360 Hz)
        ecg_sample    : in  std_logic_vector(11 downto 0);
        sample_tick   : in  std_logic;
        
        -- I2S outputs
        aud_bclk      : out std_logic;
        aud_daclrck   : out std_logic;
        aud_dacdat    : out std_logic;
        
        -- I2C outputs
        i2c_sclk      : out std_logic;
        i2c_sdat      : inout std_logic;
        
        -- Status
        codec_ready   : out std_logic;
        audio_active  : out std_logic
    );
end audio_output_controller;
```

**Sub-modules**:
1. `i2c_master` - Configure WM8731 via I2C
2. `sample_upsampler` - Hold ECG sample for 133 audio frames
3. `i2s_transmitter` - Serialize audio data to I2S format

---

### 5.4 Module: `sample_upsampler` **NEW!**

**Purpose**: Convert 360 Hz ECG samples to 48 kHz audio stream

**Port List**:
```vhdl
entity sample_upsampler is
    generic (
        UPSAMPLE_RATIO : integer := 133  -- 48000/360
    );
    port (
        clk_48khz     : in  std_logic;
        reset_n       : in  std_logic;
        
        -- ECG input (360 Hz)
        ecg_sample    : in  std_logic_vector(11 downto 0);
        sample_tick   : in  std_logic;
        
        -- Audio output (48 kHz)
        audio_sample  : out std_logic_vector(15 downto 0);
        audio_valid   : out std_logic
    );
end sample_upsampler;
```

**Functionality**:
- Hold each 12-bit ECG sample for 133 consecutive 48 kHz periods
- Pad to 16-bit for I2S (left-align: append 4 zeros)
- Assert audio_valid every 48 kHz period

---

### 5.5 Module: `i2s_transmitter` **NEW!**

**Purpose**: Serialize 16-bit audio to I2S format

**Port List**:
```vhdl
entity i2s_transmitter is
    port (
        clk_48khz     : in  std_logic;
        reset_n       : in  std_logic;
        
        -- Audio input
        audio_left    : in  std_logic_vector(15 downto 0);
        audio_right   : in  std_logic_vector(15 downto 0);
        audio_valid   : in  std_logic;
        
        -- I2S outputs
        bclk          : out std_logic;  -- 3.072 MHz
        lrck          : out std_logic;  -- 48 kHz
        data          : out std_logic   -- Serial data
    );
end i2s_transmitter;
```

**Timing**:
- BCLK = 48 kHz × 32 bits × 2 channels = 3.072 MHz
- LRCK = 48 kHz (toggles left/right channel)
- DATA = MSB-first serial output

---

### 5.6 Module: `i2c_master` **NEW!**

**Purpose**: Configure WM8731 codec via I2C protocol

**Port List**:
```vhdl
entity i2c_master is
    port (
        clk          : in    std_logic;
        reset_n      : in    std_logic;
        
        -- Control
        start        : in    std_logic;
        slave_addr   : in    std_logic_vector(6 downto 0);
        reg_addr     : in    std_logic_vector(7 downto 0);
        data         : in    std_logic_vector(7 downto 0);
        
        -- I2C bus
        scl          : out   std_logic;
        sda          : inout std_logic;
        
        -- Status
        busy         : out   std_logic;
        done         : out   std_logic;
        ack_error    : out   std_logic
    );
end i2c_master;
```

---

### 5.7 Other Modules (Similar to original design)

The following modules remain largely the same as Spartan-3E version:
- `clk_divider` (for VGA - now redundant if using PLL c1 output)
- `user_interface_controller` (updated LED count)
- `sample_rate_controller` (unchanged)
- `ecg_memory` (M9K instead of BRAM)
- `ecg_sample_generator` (unchanged)
- `vga_timing_generator` (unchanged)
- `ecg_vga_renderer` (better color depth for DE2-115)

---

## 6. RESOURCE ESTIMATION (DE2-115)

### FPGA Resources (Cyclone IV EP4CE115)

| Resource Type    | Usage Estimate | Total Available | Percentage |
|------------------|----------------|-----------------|------------|
| Logic Elements   | ~5,000-8,000   | 114,480         | ~5-7%      |
| M9K Memory       | 5-7 blocks     | 432 blocks      | ~1.5%      |
| PLLs             | 1              | 4               | 25%        |
| I/O Pins         | ~35            | 528             | ~7%        |

**M9K Breakdown**:
- ECG Memory: 3 blocks (3×360×12-bit waveforms)
- Waveform Buffer: 2 blocks (640×12-bit buffer)
- Audio Buffer: 0-1 blocks (optional for smoother audio)

**Conclusion**: Massive headroom on DE2-115 - only ~5% resource usage!

---

## 7. INTEGRATION CHECKLIST

### Board 1 (DE2-115) Self-Test
- [ ] VGA displays test pattern
- [ ] User interface responds (switches, buttons, LEDs)
- [ ] ECG waveforms display correctly
- [ ] Audio codec initializes (check I2C ACK)
- [ ] Audio output measurable on oscilloscope

### Board-to-Board Integration
- [ ] Verify 3.5mm cable quality (test continuity)
- [ ] Measure audio signal at DE2-115 output
- [ ] Measure audio signal at Spartan-3E input
- [ ] Verify signal amplitude and shape
- [ ] Test with different waveforms (Normal, PVC, AFib)
- [ ] Coordinate CNN sample rate expectations

### With CNN Team
- [ ] Share audio signal specifications
- [ ] Define ADC requirements for Spartan-3E
- [ ] Agree on downsampling method
- [ ] Create test vectors (known ECG → expected class)
- [ ] Schedule joint testing sessions

---

## 8. DESIGN DECISIONS RATIONALE

### Decision 1: Audio Interface vs GPIO
**Choice**: 3.5mm audio jack  
**Rationale**:
- **Physical flexibility**: Boards can be separated
- **Standard hardware**: Common cables, easy testing
- **Isolation**: Reduces electrical coupling issues
- **Educational**: Learn audio codec interfacing
- **Debugging**: Can monitor with standard audio tools

### Decision 2: 48 kHz Audio Sample Rate
**Choice**: 48 kHz I2S stream  
**Rationale**:
- Standard rate (native WM8731 support)
- Integer upsampling: 48000/360 = 133.33 ≈ 133
- Sufficient bandwidth: Nyquist 24 kHz >> 360 Hz
- Common in audio equipment

### Decision 3: Hold-and-Repeat Upsampling
**Choice**: Each ECG sample held for 133 audio frames  
**Rationale**:
- Simplest method (no interpolation)
- Preserves original ECG values exactly
- Easy to implement in hardware
- Easy to downsample on receiving end
- No signal processing artifacts

### Decision 4: DE2-115 Instead of Spartan-3E
**Choice**: Use larger DE2-115 for simulation board  
**Rationale**:
- **Built-in audio codec** (WM8731)
- **11x more resources** than Spartan-3E
- **Better VGA** (10-bit DAC vs 3-bit)
- **More LEDs** for status display
- **PLLs available** for flexible clocking
- Team already using Spartan-3E for CNN

---

## 9. CRITICAL TIMING PATHS

### Path 1: Sample Generation (Unchanged)
```
50 MHz Clock → Sample Counter → Sample Tick → M9K Read
Critical: <20 ns (50 MHz period)
Estimated: ~8 ns (safe)
```

### Path 2: VGA Pixel Generation (Unchanged)
```
25 MHz Clock → Pixel Counter → Buffer Read → RGB Mux
Critical: <40 ns (25 MHz period)
Estimated: ~12 ns (safe)
```

### Path 3: Audio I2S Transmission **NEW!**
```
48 MHz Clock → Upsampler → I2S Serializer → Output
Critical: <20.8 ns (48 MHz period)
Estimated: ~15 ns (marginal - needs verification)
```

### Path 4: Cross-Clock Domains
```
50 MHz → VGA Buffer Write @ 25 MHz Read → Dual-port RAM
50 MHz → Audio Upsampler @ 48 MHz Read → Synchronizer needed
```

---

## 10. NEXT STEPS (FOR IMPLEMENTATION)

### Phase A: Audio Module Development (Weeks 1-3)
1. Create PLL (50→48 MHz + 50→25 MHz)
2. Implement I2C master for WM8731 config
3. Test codec initialization (verify with LEDs)
4. Implement I2S transmitter
5. Test audio output with simple tone generator

### Phase B: ECG-to-Audio Integration (Weeks 4-5)
6. Implement sample upsampler (360 Hz → 48 kHz)
7. Connect ECG samples to audio output
8. Verify with oscilloscope (ECG waveform in audio)
9. Test all three waveform types

### Phase C: VGA Display (Week 5-6)
10. Port VGA modules from Spartan design
11. Adapt for 10-bit color on DE2-115
12. Verify simultaneous VGA + audio output

### Phase D: Two-Board Integration (Weeks 7-8)
13. Meet with CNN team to define ADC interface
14. Test audio cable connection
15. Verify end-to-end: DE2-115 → audio → Spartan-3E → CNN
16. Final demo preparation

---

**Document Version**: 2.0 (DE2-115 Two-Board Update)  
**Created**: November 28, 2025  
**Status**: Architecture Complete - Ready for Implementation
