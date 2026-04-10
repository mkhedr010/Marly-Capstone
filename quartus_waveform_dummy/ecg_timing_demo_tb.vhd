--------------------------------------------------------------------------------
-- ECG Timing Waveform Testbench
-- Generates the exact timing waveform for the Gantt diagram in the report
--
-- HOW TO USE:
--   1. Open this project in Quartus Prime
--   2. Assignments > Settings > Simulation > NativeLink > Set testbench to: ecg_timing_demo_tb
--   3. Tools > Run Simulation Tool > RTL Simulation
--   4. In ModelSim: run 358 ms
--   5. View > Zoom > Fit
--   6. Take screenshot
--
-- SIGNALS in the waveform (add all from tb):
--   uart_accumulate   : HIGH during UART reception phase
--   cnn_active        : HIGH during all CNN computation
--   conv1_active      : HIGH during Conv1 layer
--   conv2_active      : HIGH during Conv2 layer
--   conv3_active      : HIGH during Conv3 layer
--   conv4_active      : HIGH during Conv4 layer
--   conv5_active      : HIGH during Conv5 layer
--   linear1_active    : HIGH during Linear1 layer
--   linear2_3_active  : HIGH during Linear2 + Linear3 layers
--   fusion_cls_active : HIGH during Fusion + Classifier layer
--   argmax_active     : HIGH during Argmax
--   result_valid      : HIGH during output hold period
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ecg_timing_demo_tb is
    -- Testbench has no ports (standard)
end ecg_timing_demo_tb;

architecture Behavioral of ecg_timing_demo_tb is

    ----------------------------------------------------------------------------
    -- Component declaration
    ----------------------------------------------------------------------------
    component ecg_timing_demo is
        port (
            uart_accumulate     : in  std_logic;
            cnn_active          : in  std_logic;
            conv1_active        : in  std_logic;
            conv2_active        : in  std_logic;
            conv3_active        : in  std_logic;
            conv4_active        : in  std_logic;
            conv5_active        : in  std_logic;
            linear1_active      : in  std_logic;
            linear2_3_active    : in  std_logic;
            fusion_cls_active   : in  std_logic;
            argmax_active       : in  std_logic;
            result_valid        : in  std_logic
        );
    end component;

    ----------------------------------------------------------------------------
    -- Internal signals (these are what you add to the waveform viewer)
    ----------------------------------------------------------------------------

    -- ── Group 1: UART accumulation ─────────────────────────────────────────
    signal uart_accumulate     : std_logic := '0';

    -- ── Group 2: CNN computation ───────────────────────────────────────────
    signal cnn_active          : std_logic := '0';

    -- ── Group 3: Individual CNN layers ────────────────────────────────────
    signal conv1_active        : std_logic := '0';
    signal conv2_active        : std_logic := '0';
    signal conv3_active        : std_logic := '0';
    signal conv4_active        : std_logic := '0';
    signal conv5_active        : std_logic := '0';
    signal linear1_active      : std_logic := '0';
    signal linear2_3_active    : std_logic := '0';
    signal fusion_cls_active   : std_logic := '0';
    signal argmax_active       : std_logic := '0';

    -- ── Group 4: Classification output ────────────────────────────────────
    signal result_valid        : std_logic := '0';

begin

    ----------------------------------------------------------------------------
    -- DUT instantiation
    ----------------------------------------------------------------------------
    DUT : ecg_timing_demo
        port map (
            uart_accumulate     => uart_accumulate,
            cnn_active          => cnn_active,
            conv1_active        => conv1_active,
            conv2_active        => conv2_active,
            conv3_active        => conv3_active,
            conv4_active        => conv4_active,
            conv5_active        => conv5_active,
            linear1_active      => linear1_active,
            linear2_3_active    => linear2_3_active,
            fusion_cls_active   => fusion_cls_active,
            argmax_active       => argmax_active,
            result_valid        => result_valid
        );

    ----------------------------------------------------------------------------
    -- Stimulus process — drives all signals with exact system timing
    ----------------------------------------------------------------------------
    stimulus : process
    begin

        -- ── Initialize all signals LOW ─────────────────────────────────────
        uart_accumulate     <= '0';
        cnn_active          <= '0';
        conv1_active        <= '0';
        conv2_active        <= '0';
        conv3_active        <= '0';
        conv4_active        <= '0';
        conv5_active        <= '0';
        linear1_active      <= '0';
        linear2_3_active    <= '0';
        fusion_cls_active   <= '0';
        argmax_active       <= '0';
        result_valid        <= '0';
        wait for 1 us;   -- small initial delay for clean waveform start

        -- ── PHASE 1: UART Accumulation (0 → 355 ms) ───────────────────────
        -- 128 samples at 360 Hz = 355.556 ms → rounded to 355 ms
        uart_accumulate <= '1';
        wait for 355 ms;
        uart_accumulate <= '0';

        -- ── PHASE 2: CNN Computation begins ───────────────────────────────
        cnn_active <= '1';

        -- Conv1: 1→8 channels, 128 samples, kernel=3
        -- Cycles: 8 * 128 * 15 states = 15,360 → 307.2 µs @ 50 MHz
        conv1_active <= '1';
        wait for 307 us;
        conv1_active <= '0';

        -- Conv2: 8→16 channels, 64 samples
        -- Cycles: 16 * 64 * 15 = 15,360 → 307.2 µs @ 50 MHz
        conv2_active <= '1';
        wait for 307 us;
        conv2_active <= '0';

        -- Conv3: 16→32 channels, 32 samples
        -- Cycles: 32 * 32 * 15 = 15,360 → 307.2 µs @ 50 MHz
        conv3_active <= '1';
        wait for 307 us;
        conv3_active <= '0';

        -- Conv4: 32→32 channels, 16 samples
        -- Cycles: 32 * 16 * 15 = 7,680 → 153.6 µs @ 50 MHz
        conv4_active <= '1';
        wait for 154 us;
        conv4_active <= '0';

        -- Conv5: 32→1 channels, 8 samples
        -- Cycles: 1 * 8 * 15 = 120 → 2.4 µs @ 50 MHz
        conv5_active <= '1';
        wait for 2 us;
        conv5_active <= '0';

        -- Linear1: 128 → 64 (largest layer)
        -- Cycles: 64 * 128 * 6 = 49,152 → 983.0 µs @ 50 MHz
        linear1_active <= '1';
        wait for 983 us;
        linear1_active <= '0';

        -- Linear2 + Linear3 combined: 64→16 then 16→8
        -- Linear2: 16*64*6 = 6,144 → 122.9 µs
        -- Linear3:  8*16*6 =   768 →  15.4 µs
        -- Total: ~138 µs
        linear2_3_active <= '1';
        wait for 138 us;
        linear2_3_active <= '0';

        -- Fusion (element-wise add) + Classifier (Linear 8→8)
        -- Fusion: 8 cycles = 0.16 µs
        -- Classifier: 8*8*6 = 384 cycles = 7.68 µs
        -- Total: ~8 µs
        fusion_cls_active <= '1';
        wait for 8 us;
        fusion_cls_active <= '0';

        -- Argmax: scan 8 class scores → 8 cycles = 0.16 µs
        -- (shown as 1 µs for visibility at this zoom level)
        argmax_active <= '1';
        wait for 1 us;
        argmax_active <= '0';

        -- CNN computation done
        cnn_active <= '0';

        -- ── PHASE 3: Output hold ───────────────────────────────────────────
        -- result_valid held HIGH for 1000 cycles = 20 µs
        -- LCD and LEDs register the classification result during this window
        result_valid <= '1';
        wait for 20 us;
        result_valid <= '0';

        -- ── End of one complete classification window ──────────────────────
        wait for 100 us;  -- trailing gap for clean waveform end

        -- Stop simulation
        wait;

    end process;

end Behavioral;
