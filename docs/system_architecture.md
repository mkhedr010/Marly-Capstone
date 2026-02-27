# ECG Simulation Component - System Architecture

## Document Overview
This document defines the complete architecture for the ECG Simulation & Visualization Component, including block diagrams, data flow, timing relationships, and module specifications.

---

## 1. HIGH-LEVEL SYSTEM BLOCK DIAGRAM

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ECG SIMULATION COMPONENT (Spartan-3E)                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                          USER INTERFACE                             │  │
│  │  ┌──────────┐    ┌──────────┐    ┌──────────┐                      │  │
│  │  │ SW[1:0]  │───▶│  Switch  │───▶│  Mode    │                      │  │
│  │  │ Switches │    │ Debounce │    │ Control  │                      │  │
│  │  └──────────┘    └──────────┘    └─────┬────┘                      │  │
│  │                                         │                           │  │
│  │  ┌──────────┐    ┌──────────┐          │                           │  │
│  │  │ BTN[0]   │───▶│  Button  │──────────┼──────────────┐            │  │
│  │  │ Button   │    │ Debounce │          │              │            │  │
│  │  └──────────┘    └──────────┘          │              │            │  │
│  │                                         ▼              ▼            │  │
│  │  ┌──────────┐                     ┌─────────────────────────┐      │  │
│  │  │ LED[3:0] │◀────────────────────│   LED Controller        │      │  │
│  │  │ Status   │                     └─────────────────────────┘      │  │
│  │  └──────────┘                                                      │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                       │                                    │
│                                       ▼                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                      ECG DATA MANAGEMENT                            │  │
│  │                                                                     │  │
│  │  ┌──────────────────────────────────────────────────────────┐      │  │
│  │  │             ECG MEMORY (Block RAM)                       │      │  │
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
│       │   VGA CONTROLLER        │  │  CNN INTERFACE          │            │
│       │                         │  │                         │            │
│       │  ┌──────────────────┐   │  │  ┌──────────────────┐  │            │
│       │  │  VGA Timing Gen  │   │  │  │ ecg_sample[11:0] │──┼───────────▶│
│       │  │  (640×480@60Hz)  │   │  │  │                  │  │  To CNN    │
│       │  └──────────────────┘   │  │  │ sample_tick      │──┼───────────▶│
│       │                         │  │  │                  │  │  Module    │
│       │  ┌──────────────────┐   │  │  │ sample_valid     │──┼───────────▶│
│       │  │  ECG Renderer    │   │  │  └──────────────────┘  │            │
│       │  │  • Waveform      │   │  │                         │            │
│       │  │    Buffer        │   │  │  ┌──────────────────┐  │            │
│       │  │  • Y-Mapping     │   │  │  │ cnn_result[1:0]  │◀─┼───────────▶│
│       │  │  • Pixel Gen     │   │  │  │ cnn_valid        │◀─┼───────────▶│
│       │  └──────────────────┘   │  │  └──────────────────┘  │            │
│       │           │              │  │                         │            │
│       │           ▼              │  └─────────────────────────┘            │
│       │  ┌──────────────────┐   │                                         │
│       │  │  VGA_R, VGA_G,   │───┼──────────────────────────────────────▶  │
│       │  │  VGA_B           │   │                          To VGA Monitor │
│       │  │  HSYNC, VSYNC    │───┼──────────────────────────────────────▶  │
│       │  └──────────────────┘   │                                         │
│       └─────────────────────────┘                                         │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                     CLOCK MANAGEMENT                                │  │
│  │  ┌──────────┐     ┌──────────────┐      ┌──────────────┐           │  │
│  │  │ 50 MHz   │────▶│ Clock Divider│─────▶│  25 MHz VGA  │           │  │
│  │  │ Onboard  │     │   (÷2)       │      │  Pixel Clock │           │  │
│  │  │ Clock    │     └──────────────┘      └──────────────┘           │  │
│  │  └──────────┘                                                       │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. DATA FLOW DIAGRAM

```
USER INPUTS                 PROCESSING PIPELINE              OUTPUTS
═══════════                 ════════════════════             ═══════════

┌──────────┐
│ SW[1:0]  │──┐
└──────────┘  │
              │            ┌─────────────────┐
┌──────────┐  ├───────────▶│  Mode Selector  │
│ BTN[0]   │──┘            │  • Debounce     │
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
                           │   ECG MEMORY (BRAM)  │
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
                      ┌───────────────┴──────────────┐
                      │                              │
                      ▼                              ▼
         ┌────────────────────────┐    ┌────────────────────────┐
         │  VGA Renderer          │    │  CNN Interface         │
         │                        │    │                        │
         │  ┌──────────────────┐  │    │  ┌──────────────────┐  │
         │  │ Waveform Buffer  │  │    │  │ Sample Register  │  │
         │  │ (640 samples)    │  │    │  │ (12-bit)         │  │
         │  └────────┬─────────┘  │    │  └────────┬─────────┘  │
         │           │            │    │           │            │
         │           ▼            │    │           │            │
         │  ┌──────────────────┐  │    │  sample_tick ────────┼──▶ To CNN
         │  │ Y Coordinate     │  │    │  ecg_sample[11:0] ───┼──▶ Module
         │  │ Calculator       │  │    │  sample_valid ────────┼──▶
         │  │ Y = 240-(S/10)   │  │    │                        │
         │  └────────┬─────────┘  │    └────────────────────────┘
         │           │            │
         │           ▼            │              ┌──────────┐
         │  ┌──────────────────┐  │              │ LED[3:0] │
         │  │ VGA Timing Gen   │  │              └────▲─────┘
         │  │ (H/V counters)   │  │                   │
         │  └────────┬─────────┘  │                   │
         │           │            │         ┌─────────┴─────────┐
         │           ▼            │         │  Status Display   │
         │  ┌──────────────────┐  │         │  • Mode[1:0]      │
         │  │ Pixel Generator  │  │         │  • Running        │
         │  │ (RGB logic)      │  │         │  • CNN Result     │
         │  └────────┬─────────┘  │         └───────────────────┘
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

## 3. TIMING DIAGRAM

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


Sample Tick (360 Hz)
          ____
_________|    |_____________________________________________...
         |<2.78 ms>|
         Sample N   Sample N+1


ECG Sample Out [11:0]
_________XXXXXXXXXXXX_______________________________________...
         |  Valid   |
         | Sample N |


VGA Horizontal Sync (31.77 μs period)
    ____________________________________________________________________     ____
___|                                                                    |___|
   |<-------------------------- 31.77 μs ---------------------------->|


VGA Vertical Sync (16.68 ms period)
    ______________________________________________________________________
___|                                                                      |___
   |<-------------------------- 16.68 ms ---------------------------->|


Waveform Buffer Update
         ┌─────┐                           ┌─────┐
_________|     |___________________________|     |___________________...
         Update                            Update
         X=0                               X=1
         (every 2.78 ms)


VGA Pixel Drawing (within one frame)
X=0      X=100    X=200    X=300    X=400    X=500    X=639
|--------|--------|--------|--------|--------|--------|
└─────────────── Drawing from Buffer ────────────────┘
         (refreshes 60 times per second)


Clock Domain Summary:
┌──────────────┬───────────┬────────────────────────────┐
│ Domain       │ Frequency │ Purpose                    │
├──────────────┼───────────┼────────────────────────────┤
│ System       │ 50 MHz    │ Main logic, sample gen     │
│ VGA Pixel    │ 25 MHz    │ Pixel clock for display    │
│ Sample Rate  │ 360 Hz    │ ECG data update rate       │
│ VGA Frame    │ 60 Hz     │ Screen refresh             │
└──────────────┴───────────┴────────────────────────────┘
```

---

## 4. MODULE HIERARCHY & SPECIFICATIONS

### 4.1 Top-Level Module: `ecg_system_top`

**Purpose**: Top-level wrapper, instantiates all subsystems

**Port List**:
```vhdl
entity ecg_system_top is
    generic (
        CLK_FREQ        : integer := 50_000_000;  -- 50 MHz
        SAMPLE_RATE     : integer := 360;         -- 360 Hz
        VGA_PIXEL_FREQ  : integer := 25_000_000   -- 25 MHz
    );
    port (
        -- Clock and Reset
        clk_50mhz    : in  std_logic;
        reset_n      : in  std_logic;
        
        -- User Interface
        sw           : in  std_logic_vector(1 downto 0);   -- Waveform select
        btn          : in  std_logic_vector(0 downto 0);   -- Start/pause
        led          : out std_logic_vector(3 downto 0);   -- Status
        
        -- VGA Output
        vga_hsync    : out std_logic;
        vga_vsync    : out std_logic;
        vga_r        : out std_logic_vector(2 downto 0);
        vga_g        : out std_logic_vector(2 downto 0);
        vga_b        : out std_logic_vector(1 downto 0);
        
        -- CNN Interface
        ecg_sample   : out std_logic_vector(11 downto 0);
        sample_tick  : out std_logic;
        sample_valid : out std_logic;
        
        -- Optional: CNN feedback
        cnn_result   : in  std_logic_vector(1 downto 0);
        cnn_valid    : in  std_logic
    );
end ecg_system_top;
```

**Internal Signals**:
```vhdl
-- Clock domain signals
signal clk_25mhz         : std_logic;

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
```

---

### 4.2 Module: `clk_divider`

**Purpose**: Generate 25 MHz pixel clock from 50 MHz system clock

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

**Implementation**: Simple toggle-based divider by 2

---

### 4.3 Module: `user_interface_controller`

**Purpose**: Handle switches, buttons with debouncing, control LEDs

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
        sw              : in  std_logic_vector(1 downto 0);
        btn             : in  std_logic_vector(0 downto 0);
        
        -- Control outputs
        ecg_mode        : out std_logic_vector(1 downto 0);
        playback_enable : out std_logic;
        
        -- Status outputs
        led             : out std_logic_vector(3 downto 0);
        
        -- Optional CNN result input
        cnn_result      : in  std_logic_vector(1 downto 0);
        cnn_valid       : in  std_logic
    );
end user_interface_controller;
```

**Functionality**:
- Debounce button (50 ms)
- Toggle playback_enable on button press
- Pass through switch values to ecg_mode
- Drive LEDs: [1:0]=mode, [2]=playing, [3]=CNN result

---

### 4.4 Module: `sample_rate_controller`

**Purpose**: Generate precise 360 Hz sample tick from 50 MHz clock

**Port List**:
```vhdl
entity sample_rate_controller is
    generic (
        CLK_FREQ    : integer := 50_000_000;
        SAMPLE_RATE : integer := 360
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        enable      : in  std_logic;  -- Playback control
        sample_tick : out std_logic   -- Pulse high for 1 cycle
    );
end sample_rate_controller;
```

**Implementation**:
- Counter from 0 to (CLK_FREQ / SAMPLE_RATE - 1) = 138,888
- sample_tick pulses high when counter = 0
- Only counts when enable = '1'

---

### 4.5 Module: `ecg_memory`

**Purpose**: Store 3 ECG waveforms in Block RAM

**Port List**:
```vhdl
entity ecg_memory is
    generic (
        ADDR_WIDTH  : integer := 9;   -- 512 addresses
        DATA_WIDTH  : integer := 12   -- 12-bit samples
    );
    port (
        clk         : in  std_logic;
        addr        : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
        data_out    : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end ecg_memory;
```

**Memory Map**:
```
Address Range  | Waveform Type
---------------+----------------
0x000 - 0x167  | Normal (360 samples)
0x168 - 0x2CF  | PVC (360 samples)
0x2D0 - 0x437  | AFib (360 samples)
```

**Implementation**: Inferred Block RAM with initialization data

---

### 4.6 Module: `ecg_sample_generator`

**Purpose**: Generate sample stream with address control

**Port List**:
```vhdl
entity ecg_sample_generator is
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        
        -- Control
        sample_tick   : in  std_logic;
        ecg_mode      : in  std_logic_vector(1 downto 0);
        enable        : in  std_logic;
        
        -- Memory interface
        mem_address   : out std_logic_vector(8 downto 0);
        mem_data      : in  std_logic_vector(11 downto 0);
        
        -- Output
        ecg_sample    : out std_logic_vector(11 downto 0);
        sample_valid  : out std_logic
    );
end ecg_sample_generator;
```

**Functionality**:
- Maintain address counter (0-359)
- Compute base address from ecg_mode
- On sample_tick: increment counter, latch new sample
- Output sample and assert sample_valid

---

### 4.7 Module: `vga_timing_generator`

**Purpose**: Generate VGA sync signals and pixel coordinates

**Port List**:
```vhdl
entity vga_timing_generator is
    port (
        clk_pixel   : in  std_logic;  -- 25 MHz
        reset_n     : in  std_logic;
        
        hsync       : out std_logic;
        vsync       : out std_logic;
        display_on  : out std_logic;
        
        pixel_x     : out std_logic_vector(9 downto 0);  -- 0-799
        pixel_y     : out std_logic_vector(9 downto 0)   -- 0-524
    );
end vga_timing_generator;
```

**Timing Parameters** (640×480 @ 60 Hz):
```vhdl
constant H_DISPLAY  : integer := 640;
constant H_FPORCH   : integer := 16;
constant H_SYNC     : integer := 96;
constant H_BPORCH   : integer := 48;
constant H_TOTAL    : integer := 800;

constant V_DISPLAY  : integer := 480;
constant V_FPORCH   : integer := 10;
constant V_SYNC     : integer := 2;
constant V_BPORCH   : integer := 33;
constant V_TOTAL    : integer := 525;
```

---

### 4.8 Module: `ecg_vga_renderer`

**Purpose**: Draw ECG waveform on VGA display

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
        
        -- ECG sample input (system clock domain)
        ecg_sample    : in  std_logic_vector(11 downto 0);
        sample_tick   : in  std_logic;
        
        -- RGB output
        vga_r         : out std_logic_vector(2 downto 0);
        vga_g         : out std_logic_vector(2 downto 0);
        vga_b         : out std_logic_vector(1 downto 0)
    );
end ecg_vga_renderer;
```

**Internal Components**:
1. **Waveform Buffer**: RAM storing 640 samples (12-bit each)
2. **Buffer Writer**: Updates buffer on sample_tick (system clock)
3. **Y-Mapper**: Converts sample to Y coordinate
4. **Pixel Generator**: Outputs RGB based on current pixel position

**Y-Mapping Algorithm**:
```vhdl
-- Center at Y=240, scale down by ~10
signal y_center : integer := 240;
signal y_coord  : integer;

y_coord <= y_center - (to_integer(signed(ecg_sample)) / 10);

-- Draw if pixel_y matches y_coord for current pixel_x
if pixel_y = y_coord then
    rgb <= GREEN;
else
    rgb <= BLACK;
end if;
```

---

### 4.9 Module: `cnn_interface`

**Purpose**: Format output for CNN module

**Port List**:
```vhdl
entity cnn_interface is
    port (
        clk           : in  std_logic;
        reset_n       : in  std_logic;
        
        -- Internal signals
        ecg_sample_in : in  std_logic_vector(11 downto 0);
        sample_tick   : in  std_logic;
        
        -- CNN outputs
        ecg_sample    : out std_logic_vector(11 downto 0);
        sample_tick_out : out std_logic;
        sample_valid  : out std_logic
    );
end cnn_interface;
```

**Functionality**:
- Register ecg_sample on sample_tick
- Pass through sample_tick as 1-cycle pulse
- Assert sample_valid when data is stable

---

## 5. RESOURCE ESTIMATION

### FPGA Resources (Spartan-3E XC3S500E)

| Resource Type    | Usage Estimate | Total Available | Percentage |
|------------------|----------------|-----------------|------------|
| Logic Cells      | ~2,000         | 10,476          | ~19%       |
| Block RAM (18Kb) | 4-5 blocks     | 20 blocks       | ~22%       |
| DCM              | 0-1            | 4               | 0-25%      |
| I/O Pins         | ~25            | 232             | ~11%       |

**Block RAM Breakdown**:
- ECG Memory: 2-3 blocks (for 3×360×12-bit waveforms)
- Waveform Buffer: 1-2 blocks (640×12-bit buffer)

---

## 6. INTEGRATION CHECKLIST

### With CNN Module (Ayoub's Component)
- [ ] Confirm CNN input format: 12-bit signed or unsigned?
- [ ] Agree on sample_tick pulse width (1 cycle @ 50 MHz)
- [ ] Define handshake: simple streaming or ready/valid?
- [ ] Specify GPIO pin assignments
- [ ] Document expected sample rate tolerance

### With VGA Monitor
- [ ] Verify monitor supports 640×480 @ 60Hz
- [ ] Confirm RGB bit depth (3-3-2 vs 1-1-1)
- [ ] Test with color bars pattern first

### With Team
- [ ] Share pin constraints (UCF file)
- [ ] Coordinate GPIO header usage
- [ ] Define test vectors for integration
- [ ] Schedule hardware testing time in lab

---

## 7. DESIGN DECISIONS RATIONALE

### Decision 1: Scrolling vs. Static Display
**Choice**: Scrolling waveform  
**Rationale**:
- More engaging for demonstration
- Simpler memory management (640 samples vs full screen buffer)
- Real-time feel like actual ECG monitor

### Decision 2: 12-bit Sample Width
**Choice**: 12 bits signed  
**Rationale**:
- Matches typical ADC resolution
- Good precision for ECG signals
- Efficient BRAM packing (18-bit blocks)
- Compatible with most CNN implementations

### Decision 3: Simple Streaming Interface
**Choice**: Fixed 360 Hz streaming without backpressure  
**Rationale**:
- CNN processes faster than input rate
- Simplifies timing and synchronization
- Matches real-world ECG data acquisition
- Easy to debug

### Decision 4: Inferred vs. Instantiated BRAM
**Choice**: Inferred BRAM with VHDL arrays  
**Rationale**:
- More portable across FPGA families
- Easier to modify/debug
- ISE synthesizer infers BRAM automatically
- Can switch to instantiated if needed

### Decision 5: 640-sample Waveform Buffer
**Choice**: One sample per horizontal pixel  
**Rationale**:
- 1:1 mapping simplifies rendering logic
- 640 samples ≈ 1.78 seconds of data @ 360 Hz
- Good temporal resolution for visualization
- Fits in one BRAM block

---

## 8. CRITICAL TIMING PATHS

### Path 1: Sample Generation
```
50 MHz Clock → Sample Counter → Compare → Sample Tick → Address Inc → BRAM Read
Critical: Must complete in 20 ns (50 MHz period)
Estimated: ~8 ns (safe)
```

### Path 2: VGA Pixel Generation
```
25 MHz Clock → Pixel Counter → Buffer Read → Y Compare → RGB Mux
Critical: Must complete in 40 ns (25 MHz period)
Estimated: ~12 ns (safe)
```

### Path 3: Cross-Clock Domain (Sample to Display)
```
System Clock (50 MHz) → Waveform Buffer Write
Pixel Clock (25 MHz) → Waveform Buffer Read
Solution: Dual-port RAM or proper synchronization
```

---

## 9. NEXT STEPS (FOR IMPLEMENTATION)

### Phase A: Core Modules (Week 1-2)
1. Implement sample_rate_controller
2. Implement vga_timing_generator
3. Test both in simulation
4. Create testbenches

### Phase B: Data Path (Week 3-4)
5. Implement ecg_memory with sample data
6. Implement ecg_sample_generator
7. Implement cnn_interface
8. Integration test (sim)

### Phase C: Display (Week 5-6)
9. Implement ecg_vga_renderer
10. Implement waveform buffer
11. Test VGA output with test pattern
12. Add ECG waveform rendering

### Phase D: User Interface (Week 7)
13. Implement user_interface_controller
14. Add button debouncing
15. Connect LED outputs

### Phase E: Integration (Week 8)
16. Integrate all modules in top-level
17. Create UCF file with pin constraints
18. Synthesize and verify resource usage
19. Hardware testing on Spartan-3E board

---

**Document Version**: 1.0  
**Created**: November 25, 2025  
**Status**: Architecture Complete - Ready for Implementation
