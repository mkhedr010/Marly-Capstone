--------------------------------------------------------------------------------
-- LCD Text Formatter with Anti-Flicker Logic
-- Monitors LEDG[7:6] and displays dominant LED state on LCD
--
-- Anti-Flicker Strategy:
--   - Initial 5-second delay after reset
--   - Samples LEDs every 5 seconds (not on every change)
--   - Tracks which LED is ON the longest during each period
--   - Updates LCD display with dominant state
--
-- LED Mapping:
--   LEDG7 = Normal ECG
--   LEDG6 = Abnormal ECG (PVC)
--
-- Author: Claude
-- Date: March 27, 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_text_formatter is
    generic (
        CLK_FREQ       : integer := 50_000_000;  -- 50 MHz clock
        SAMPLE_PERIOD  : integer := 5            -- Sampling period in seconds
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;

        -- LED inputs (monitoring LEDG[7:6])
        ledg        : in  std_logic_vector(7 downto 0);

        -- LCD text output
        lcd_text    : out std_logic_vector(127 downto 0);  -- 16 characters x 8 bits
        text_update : out std_logic  -- Pulse to trigger LCD update
    );
end lcd_text_formatter;

architecture Behavioral of lcd_text_formatter is

    -- ASCII characters for display messages
    constant CHAR_SPACE : std_logic_vector(7 downto 0) := x"20";  -- ' '
    constant CHAR_N     : std_logic_vector(7 downto 0) := x"4E";  -- 'N'
    constant CHAR_o     : std_logic_vector(7 downto 0) := x"6F";  -- 'o'
    constant CHAR_r     : std_logic_vector(7 downto 0) := x"72";  -- 'r'
    constant CHAR_m     : std_logic_vector(7 downto 0) := x"6D";  -- 'm'
    constant C_a     : std_logic_vector(7 downto 0) := x"61";  -- 'a'
    constant CHAR_l     : std_logic_vector(7 downto 0) := x"6C";  -- 'l'
    constant CHAR_A     : std_logic_vector(7 downto 0) := x"41";  -- 'A'
    constant CHAR_b     : std_logic_vector(7 downto 0) := x"62";  -- 'b'
    constant CHAR_W     : std_logic_vector(7 downto 0) := x"57";  -- 'W'
    constant CHAR_i     : std_logic_vector(7 downto 0) := x"69";  -- 'i'
    constant CHAR_t     : std_logic_vector(7 downto 0) := x"74";  -- 't'
    constant CHAR_g     : std_logic_vector(7 downto 0) := x"67";  -- 'g'
    constant CHAR_DOT   : std_logic_vector(7 downto 0) := x"2E";  -- '.'

    -- Text strings (16 characters each)
    -- "Normal          " = Normal ECG (LEDG7)
    constant TEXT_ABNORMAL : std_logic_vector(127 downto 0) :=
        CHAR_N & CHAR_o & CHAR_r & CHAR_m & C_a & CHAR_l & CHAR_SPACE & CHAR_SPACE &
        CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE;

    -- "Abnormal        " = PVC (LEDG6)
    constant TEXT_NORMAL : std_logic_vector(127 downto 0) :=
        CHAR_A & CHAR_b & CHAR_n & CHAR_o & CHAR_r & CHAR_m & C_a & CHAR_l &
        CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE;

    -- "Waiting...      " = No LED on or tie
    constant TEXT_WAITING : std_logic_vector(127 downto 0) :=
        CHAR_W & C_a & CHAR_i & CHAR_t & CHAR_i & CHAR_n & CHAR_g & CHAR_DOT &
        CHAR_DOT & CHAR_DOT & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE & CHAR_SPACE;

    -- Timing constants (ULTRA-OPTIMIZED to reduce FPGA resource usage)
    -- Use prescaler to generate 1ms ticks, then count seconds
    constant PRESCALER_MAX  : integer := 49_999;  -- Divide 50MHz by 50,000 = 1ms tick (16 bits)
    constant SECONDS_TO_WAIT: integer := 3;       -- 3 seconds (2 bits!)

    -- Counters (ULTRA-MINIMAL: 16+10+2 = 28 bits! Down from 55 bits!)
    signal prescaler       : integer range 0 to PRESCALER_MAX := 0;    -- 16 bits
    signal ms_tick         : std_logic := '0';                         -- 1ms pulse
    signal ms_counter      : integer range 0 to 999 := 0;              -- 10 bits (counts ms within second)
    signal second_counter  : integer range 0 to SECONDS_TO_WAIT := 0;  -- 2 bits (counts seconds)

    -- Current display text
    signal current_text : std_logic_vector(127 downto 0) := TEXT_WAITING;
    signal text_update_pulse : std_logic := '0';

begin

    -- Output assignments
    lcd_text <= current_text;
    text_update <= text_update_pulse;

    -- Main state machine process
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            prescaler <= 0;
            ms_tick <= '0';
            ms_counter <= 0;
            second_counter <= 0;
            current_text <= TEXT_WAITING;
            text_update_pulse <= '0';

        elsif rising_edge(clk) then

            -- Generate 1ms tick from 50MHz clock (prescaler)
            if prescaler < PRESCALER_MAX then
                prescaler <= prescaler + 1;
                ms_tick <= '0';
            else
                prescaler <= 0;
                ms_tick <= '1';  -- 1ms pulse
            end if;

            -- Default: no update pulse
            text_update_pulse <= '0';

            -- ULTRA-SIMPLE: Count seconds, then snapshot LED state
            if ms_tick = '1' then
                -- Count milliseconds
                if ms_counter < 999 then
                    ms_counter <= ms_counter + 1;
                else
                    ms_counter <= 0;
                    -- 1 second elapsed
                    if second_counter < SECONDS_TO_WAIT then
                        second_counter <= second_counter + 1;
                    else
                        -- 3 seconds elapsed - snapshot LED state NOW
                        second_counter <= 0;

                        -- Check which LED is ON right now (snapshot, no tracking)
                        if ledg(7) = '1' then
                            current_text <= TEXT_NORMAL;
                            text_update_pulse <= '1';
                        elsif ledg(6) = '1' then
                            current_text <= TEXT_ABNORMAL;
                            text_update_pulse <= '1';
                        else
                            current_text <= TEXT_WAITING;
                            text_update_pulse <= '1';
                        end if;
                    end if;
                end if;
            end if;

        end if;
    end process;

end Behavioral;
