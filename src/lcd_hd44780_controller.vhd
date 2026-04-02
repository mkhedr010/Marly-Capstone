--------------------------------------------------------------------------------
-- HD44780 LCD Controller (4-bit mode)
-- Controls a 16x2 character LCD display
--
-- Features:
--   - 4-bit interface (uses DB4-DB7 only)
--   - Proper HD44780 initialization sequence
--   - Displays 16-character string on Line 1
--   - Auto-refresh when text changes
--
-- Author: Claude
-- Date: March 27, 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity lcd_hd44780_controller is
    generic (
        CLK_FREQ : integer := 50_000_000  -- 50 MHz clock
    );
    port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;

        -- Text input (16 characters, 8 bits each = 128 bits total)
        display_text : in  std_logic_vector(127 downto 0);
        text_update  : in  std_logic;  -- Pulse to trigger update

        -- LCD interface (4-bit mode)
        lcd_rs       : out std_logic;  -- Register Select (0=cmd, 1=data)
        lcd_rw       : out std_logic;  -- Read/Write (always 0 for write)
        lcd_e        : out std_logic;  -- Enable strobe
        lcd_data     : out std_logic_vector(3 downto 0)  -- 4-bit data (DB4-DB7)
    );
end lcd_hd44780_controller;

architecture Behavioral of lcd_hd44780_controller is

    -- HD44780 Commands
    constant CMD_CLEAR_DISPLAY  : std_logic_vector(7 downto 0) := x"01";
    constant CMD_RETURN_HOME    : std_logic_vector(7 downto 0) := x"02";
    constant CMD_ENTRY_MODE     : std_logic_vector(7 downto 0) := x"06";  -- Increment, no shift
    constant CMD_DISPLAY_ON     : std_logic_vector(7 downto 0) := x"0C";  -- Display ON, cursor OFF
    constant CMD_DISPLAY_OFF    : std_logic_vector(7 downto 0) := x"08";
    constant CMD_FUNCTION_SET_8 : std_logic_vector(7 downto 0) := x"30";  -- 8-bit mode
    constant CMD_FUNCTION_SET_4 : std_logic_vector(7 downto 0) := x"28";  -- 4-bit, 2 lines, 5x8
    constant CMD_SET_DDRAM_ADDR : std_logic_vector(7 downto 0) := x"80";  -- Line 1, column 0

    -- Timing constants (RESTORED - HD44780 datasheet requires these minimum delays!)
    -- "16 black boxes" symptom means initialization timing was too short
    constant DELAY_15MS  : integer := 750_000;   -- 15ms (REQUIRED after power-on)
    constant DELAY_5MS   : integer := 250_000;   -- 5ms
    constant DELAY_100US : integer := 5_000;     -- 100us
    constant DELAY_40US  : integer := 2_000;     -- 40us
    constant DELAY_2MS   : integer := 100_000;   -- 2ms (for clear/home)

    -- State machine
    type state_type is (
        INIT_WAIT,              -- Wait 15ms after power-on
        INIT_FUNCTION_SET_1,    -- First function set (8-bit)
        INIT_DELAY_1,           -- Wait 5ms
        INIT_FUNCTION_SET_2,    -- Second function set (8-bit)
        INIT_DELAY_2,           -- Wait 100us
        INIT_FUNCTION_SET_3,    -- Third function set (4-bit mode)
        INIT_DELAY_3,           -- Wait 40us
        INIT_FUNCTION_SET_4BIT, -- Configure 4-bit, 2-line mode
        INIT_DELAY_4,           -- Wait 40us
        INIT_DISPLAY_OFF,       -- Turn display off
        INIT_DELAY_5,           -- Wait 40us
        INIT_CLEAR_DISPLAY,     -- Clear display
        INIT_DELAY_6,           -- Wait 2ms
        INIT_ENTRY_MODE,        -- Set entry mode
        INIT_DELAY_7,           -- Wait 40us
        INIT_DISPLAY_ON,        -- Turn display on
        INIT_DELAY_8,           -- Wait 40us
        IDLE,                   -- Wait for update request
        SET_DDRAM_ADDR,         -- Set cursor to line 1
        WRITE_CHAR,             -- Write characters
        DELAY_BETWEEN_CHARS,    -- Delay between characters
        DONE                    -- Finish and return to IDLE
    );
    signal state : state_type := INIT_WAIT;

    -- Counters and registers
    signal delay_counter : integer range 0 to DELAY_15MS := 0;
    signal char_index    : integer range 0 to 15 := 0;
    signal byte_to_send  : std_logic_vector(7 downto 0) := (others => '0');
    signal nibble_select : std_logic := '0';  -- 0=high nibble, 1=low nibble

    -- LCD control signals
    signal lcd_rs_int   : std_logic := '0';
    signal lcd_e_int    : std_logic := '0';
    signal lcd_data_int : std_logic_vector(3 downto 0) := (others => '0');

    -- Enable pulse generation
    type enable_state_type is (E_IDLE, E_HIGH, E_LOW);
    signal enable_state : enable_state_type := E_IDLE;
    signal enable_counter : integer range 0 to 100 := 0;

begin

    -- Output assignments
    lcd_rs   <= lcd_rs_int;
    lcd_rw   <= '0';  -- Always write mode
    lcd_e    <= lcd_e_int;
    lcd_data <= lcd_data_int;

    -- Main state machine
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= INIT_WAIT;
            delay_counter <= 0;
            char_index <= 0;
            nibble_select <= '0';
            lcd_rs_int <= '0';
            lcd_e_int <= '0';
            lcd_data_int <= (others => '0');
            enable_state <= E_IDLE;
            enable_counter <= 0;

        elsif rising_edge(clk) then

            -- Enable pulse generator (generates ~1us high, ~1us low)
            case enable_state is
                when E_IDLE =>
                    lcd_e_int <= '0';
                    enable_counter <= 0;

                when E_HIGH =>
                    lcd_e_int <= '1';
                    if enable_counter < 50 then  -- 1us at 50MHz
                        enable_counter <= enable_counter + 1;
                    else
                        enable_state <= E_LOW;
                        enable_counter <= 0;
                    end if;

                when E_LOW =>
                    lcd_e_int <= '0';
                    if enable_counter < 50 then  -- 1us at 50MHz
                        enable_counter <= enable_counter + 1;
                    else
                        enable_state <= E_IDLE;
                        enable_counter <= 0;
                    end if;
            end case;

            -- Main controller state machine
            case state is

                -- Power-on initialization sequence
                when INIT_WAIT =>
                    if delay_counter < DELAY_15MS then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        state <= INIT_FUNCTION_SET_1;
                    end if;

                when INIT_FUNCTION_SET_1 =>
                    if enable_state = E_IDLE and delay_counter = 0 then
                        lcd_rs_int <= '0';
                        lcd_data_int <= CMD_FUNCTION_SET_8(7 downto 4);  -- Send high nibble only
                        enable_state <= E_HIGH;
                        delay_counter <= 1;  -- Mark that we've sent the command
                    elsif enable_state = E_IDLE and delay_counter = 1 then
                        -- Enable pulse completed, move to next state
                        delay_counter <= 0;
                        state <= INIT_DELAY_1;
                    end if;

                when INIT_DELAY_1 =>
                    if delay_counter < DELAY_5MS then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        state <= INIT_FUNCTION_SET_2;
                    end if;

                when INIT_FUNCTION_SET_2 =>
                    if enable_state = E_IDLE and delay_counter = 0 then
                        lcd_rs_int <= '0';
                        lcd_data_int <= CMD_FUNCTION_SET_8(7 downto 4);
                        enable_state <= E_HIGH;
                        delay_counter <= 1;  -- Mark that we've sent the command
                    elsif enable_state = E_IDLE and delay_counter = 1 then
                        -- Enable pulse completed, move to next state
                        delay_counter <= 0;
                        state <= INIT_DELAY_2;
                    end if;

                when INIT_DELAY_2 =>
                    if delay_counter < DELAY_100US then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        state <= INIT_FUNCTION_SET_3;
                    end if;

                when INIT_FUNCTION_SET_3 =>
                    if enable_state = E_IDLE and delay_counter = 0 then
                        lcd_rs_int <= '0';
                        lcd_data_int <= "0010";  -- Switch to 4-bit mode
                        enable_state <= E_HIGH;
                        delay_counter <= 1;  -- Mark that we've sent the command
                    elsif enable_state = E_IDLE and delay_counter = 1 then
                        -- Enable pulse completed, move to next state
                        delay_counter <= 0;
                        state <= INIT_DELAY_3;
                    end if;

                when INIT_DELAY_3 =>
                    if delay_counter < DELAY_40US then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        nibble_select <= '0';
                        byte_to_send <= CMD_FUNCTION_SET_4;
                        state <= INIT_FUNCTION_SET_4BIT;
                    end if;

                when INIT_FUNCTION_SET_4BIT =>
                    if enable_state = E_IDLE then
                        lcd_rs_int <= '0';
                        if nibble_select = '0' then
                            lcd_data_int <= byte_to_send(7 downto 4);
                            nibble_select <= '1';
                            enable_state <= E_HIGH;
                        else
                            lcd_data_int <= byte_to_send(3 downto 0);
                            nibble_select <= '0';
                            enable_state <= E_HIGH;
                            state <= INIT_DELAY_4;
                        end if;
                    end if;

                when INIT_DELAY_4 =>
                    if delay_counter < DELAY_40US then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        nibble_select <= '0';
                        byte_to_send <= CMD_DISPLAY_OFF;
                        state <= INIT_DISPLAY_OFF;
                    end if;

                when INIT_DISPLAY_OFF =>
                    if enable_state = E_IDLE then
                        lcd_rs_int <= '0';
                        if nibble_select = '0' then
                            lcd_data_int <= byte_to_send(7 downto 4);
                            nibble_select <= '1';
                            enable_state <= E_HIGH;
                        else
                            lcd_data_int <= byte_to_send(3 downto 0);
                            nibble_select <= '0';
                            enable_state <= E_HIGH;
                            state <= INIT_DELAY_5;
                        end if;
                    end if;

                when INIT_DELAY_5 =>
                    if delay_counter < DELAY_40US then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        nibble_select <= '0';
                        byte_to_send <= CMD_CLEAR_DISPLAY;
                        state <= INIT_CLEAR_DISPLAY;
                    end if;

                when INIT_CLEAR_DISPLAY =>
                    if enable_state = E_IDLE then
                        lcd_rs_int <= '0';
                        if nibble_select = '0' then
                            lcd_data_int <= byte_to_send(7 downto 4);
                            nibble_select <= '1';
                            enable_state <= E_HIGH;
                        else
                            lcd_data_int <= byte_to_send(3 downto 0);
                            nibble_select <= '0';
                            enable_state <= E_HIGH;
                            state <= INIT_DELAY_6;
                        end if;
                    end if;

                when INIT_DELAY_6 =>
                    if delay_counter < DELAY_2MS then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        nibble_select <= '0';
                        byte_to_send <= CMD_ENTRY_MODE;
                        state <= INIT_ENTRY_MODE;
                    end if;

                when INIT_ENTRY_MODE =>
                    if enable_state = E_IDLE then
                        lcd_rs_int <= '0';
                        if nibble_select = '0' then
                            lcd_data_int <= byte_to_send(7 downto 4);
                            nibble_select <= '1';
                            enable_state <= E_HIGH;
                        else
                            lcd_data_int <= byte_to_send(3 downto 0);
                            nibble_select <= '0';
                            enable_state <= E_HIGH;
                            state <= INIT_DELAY_7;
                        end if;
                    end if;

                when INIT_DELAY_7 =>
                    if delay_counter < DELAY_40US then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        nibble_select <= '0';
                        byte_to_send <= CMD_DISPLAY_ON;
                        state <= INIT_DISPLAY_ON;
                    end if;

                when INIT_DISPLAY_ON =>
                    if enable_state = E_IDLE then
                        lcd_rs_int <= '0';
                        if nibble_select = '0' then
                            lcd_data_int <= byte_to_send(7 downto 4);
                            nibble_select <= '1';
                            enable_state <= E_HIGH;
                        else
                            lcd_data_int <= byte_to_send(3 downto 0);
                            nibble_select <= '0';
                            enable_state <= E_HIGH;
                            state <= INIT_DELAY_8;
                        end if;
                    end if;

                when INIT_DELAY_8 =>
                    if delay_counter < DELAY_40US then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        state <= IDLE;
                    end if;

                -- Operational states
                when IDLE =>
                    if text_update = '1' then
                        char_index <= 0;
                        nibble_select <= '0';
                        byte_to_send <= CMD_SET_DDRAM_ADDR;
                        state <= SET_DDRAM_ADDR;
                    end if;

                when SET_DDRAM_ADDR =>
                    if enable_state = E_IDLE then
                        lcd_rs_int <= '0';
                        if nibble_select = '0' then
                            lcd_data_int <= byte_to_send(7 downto 4);
                            nibble_select <= '1';
                            enable_state <= E_HIGH;
                        else
                            lcd_data_int <= byte_to_send(3 downto 0);
                            nibble_select <= '0';
                            enable_state <= E_HIGH;
                            state <= WRITE_CHAR;
                        end if;
                    end if;

                when WRITE_CHAR =>
                    if enable_state = E_IDLE then
                        if char_index < 16 then
                            -- Extract character from display_text
                            -- Characters are packed: text[127:120] = char[0], text[119:112] = char[1], etc.
                            byte_to_send <= display_text((15 - char_index) * 8 + 7 downto (15 - char_index) * 8);
                            lcd_rs_int <= '1';  -- Data mode

                            if nibble_select = '0' then
                                lcd_data_int <= display_text((15 - char_index) * 8 + 7 downto (15 - char_index) * 8 + 4);
                                nibble_select <= '1';
                                enable_state <= E_HIGH;
                            else
                                lcd_data_int <= display_text((15 - char_index) * 8 + 3 downto (15 - char_index) * 8);
                                nibble_select <= '0';
                                enable_state <= E_HIGH;
                                char_index <= char_index + 1;
                                state <= DELAY_BETWEEN_CHARS;
                            end if;
                        else
                            state <= DONE;
                        end if;
                    end if;

                when DELAY_BETWEEN_CHARS =>
                    if delay_counter < DELAY_40US then
                        delay_counter <= delay_counter + 1;
                    else
                        delay_counter <= 0;
                        state <= WRITE_CHAR;
                    end if;

                when DONE =>
                    state <= IDLE;

            end case;
        end if;
    end process;

end Behavioral;
