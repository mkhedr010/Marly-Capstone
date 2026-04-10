--------------------------------------------------------------------------------
-- ECG CNN Inference Timing Demo
--
-- Clock: 1 MHz  (1 clock cycle = 1 µs)
-- Each output goes HIGH during its matching time window.
-- Run simulation for 2350 µs to see all CNN inference phases.
--
-- Signal timing (µs from CNN start):
--   cnn_active       : 0 → 2207
--   conv1_active     : 0 → 307    (307 µs,  1→8 ch, len=128)
--   conv2_active     : 307 → 614  (307 µs,  8→16 ch, len=64)
--   conv3_active     : 614 → 921  (307 µs, 16→32 ch, len=32)
--   conv4_active     : 921 → 1075 (154 µs, 32→32 ch, len=16)
--   conv5_active     : 1075→ 1077 (  2 µs, 32→1  ch, len=8 )
--   linear1_active   : 1077→ 2060 (983 µs, 128→64)
--   linear2_3_active : 2060→ 2198 (138 µs, 64→16→8)
--   fusion_cls_act   : 2198→ 2206 (  8 µs, fuse + classifier)
--   argmax_active    : 2206→ 2207 (  1 µs)
--   result_valid     : 2207→ 2227 ( 20 µs, LCD/LED hold)
--
-- Author: Marly Barsoum — Capstone 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ecg_timing_demo is
    port (
        clk              : in  std_logic;   -- 1 MHz input (1 cycle = 1 µs)
        reset_n          : in  std_logic;   -- active-low reset, tie HIGH

        -- ── Output waveforms ─────────────────────────────────────────────────
        cnn_active       : out std_logic;   -- HIGH for full CNN computation
        conv1_active     : out std_logic;   -- Conv1: 1→8  ch, 128 samples
        conv2_active     : out std_logic;   -- Conv2: 8→16 ch,  64 samples
        conv3_active     : out std_logic;   -- Conv3: 16→32 ch, 32 samples
        conv4_active     : out std_logic;   -- Conv4: 32→32 ch, 16 samples
        conv5_active     : out std_logic;   -- Conv5: 32→1  ch,  8 samples
        linear1_active   : out std_logic;   -- Linear1: 128→64
        linear2_3_active : out std_logic;   -- Linear2+3: 64→16→8
        fusion_cls_act   : out std_logic;   -- Fusion + Classifier (8→8)
        argmax_active    : out std_logic;   -- Argmax: find max class
        result_valid     : out std_logic    -- Hold result for LCD/LED (~20 µs)
    );
end ecg_timing_demo;

architecture Behavioral of ecg_timing_demo is

    -- ── Counter: 1 count = 1 µs at 1 MHz ──────────────────────────────────
    signal counter : integer range 0 to 2350 := 0;

    -- ── Timing boundaries (µs) ────────────────────────────────────────────
    -- Conv layers (upper path)
    constant T_CONV1_END    : integer := 307;    -- Conv1 ends
    constant T_CONV2_END    : integer := 614;    -- Conv2 ends
    constant T_CONV3_END    : integer := 921;    -- Conv3 ends
    constant T_CONV4_END    : integer := 1075;   -- Conv4 ends
    constant T_CONV5_END    : integer := 1077;   -- Conv5 ends (only 2 µs)
    -- Linear layers (lower path)
    constant T_LINEAR1_END  : integer := 2060;   -- Linear1 ends
    constant T_LINEAR23_END : integer := 2198;   -- Linear2+3 end
    -- Fusion, classifier, argmax
    constant T_FUSION_END   : integer := 2206;   -- Fusion+Classifier ends
    constant T_ARGMAX_END   : integer := 2207;   -- Argmax ends (1 µs)
    -- CNN done; output hold
    constant T_CNN_END      : integer := 2207;   -- CNN computation done
    constant T_VALID_END    : integer := 2227;   -- result_valid hold ends
    -- Stop counting
    constant T_STOP         : integer := 2300;

begin

    -- ── Counter process ───────────────────────────────────────────────────
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            counter <= 0;
        elsif rising_edge(clk) then
            if counter < T_STOP then
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- ── Output signal assignments (combinational) ─────────────────────────

    -- Entire CNN computation window
    cnn_active       <= '1' when counter < T_CNN_END else '0';

    -- Conv1: 0 → 307 µs
    conv1_active     <= '1' when counter < T_CONV1_END else '0';

    -- Conv2: 307 → 614 µs
    conv2_active     <= '1' when (counter >= T_CONV1_END  and counter < T_CONV2_END)  else '0';

    -- Conv3: 614 → 921 µs
    conv3_active     <= '1' when (counter >= T_CONV2_END  and counter < T_CONV3_END)  else '0';

    -- Conv4: 921 → 1075 µs
    conv4_active     <= '1' when (counter >= T_CONV3_END  and counter < T_CONV4_END)  else '0';

    -- Conv5: 1075 → 1077 µs  (only 2 µs — narrow pulse)
    conv5_active     <= '1' when (counter >= T_CONV4_END  and counter < T_CONV5_END)  else '0';

    -- Linear1: 1077 → 2060 µs  (dominant layer — 983 µs)
    linear1_active   <= '1' when (counter >= T_CONV5_END  and counter < T_LINEAR1_END) else '0';

    -- Linear2+3: 2060 → 2198 µs
    linear2_3_active <= '1' when (counter >= T_LINEAR1_END  and counter < T_LINEAR23_END) else '0';

    -- Fusion + Classifier: 2198 → 2206 µs
    fusion_cls_act   <= '1' when (counter >= T_LINEAR23_END and counter < T_FUSION_END)  else '0';

    -- Argmax: 2206 → 2207 µs  (1 µs — very narrow)
    argmax_active    <= '1' when (counter >= T_FUSION_END   and counter < T_ARGMAX_END)  else '0';

    -- Result valid hold: 2207 → 2227 µs
    result_valid     <= '1' when (counter >= T_ARGMAX_END   and counter < T_VALID_END)   else '0';

end Behavioral;
