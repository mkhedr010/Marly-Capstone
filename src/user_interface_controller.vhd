--------------------------------------------------------------------------------
-- User Interface Controller
-- Handles button input (with debouncing) and LED status display
--
-- Features:
--   - Button debouncing (50 ms)
--   - Pause/resume toggle
--   - LED status indicators
--
-- LED Mapping:
--   LED[0]: UART receiving data
--   LED[1]: VGA displaying (always on when system running)
--   LED[2]: System paused
--   LED[3]: CNN classification result
--
-- Author: Marly
-- Date: January 21, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity user_interface_controller is
    generic (
        CLK_FREQ     : integer := 50_000_000;  -- 50 MHz
        DEBOUNCE_MS  : integer := 50           -- 50 ms debounce time
    );
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        
        -- Physical inputs
        btn             : in  std_logic_vector(0 downto 0);  -- Button for pause
        
        -- Status inputs
        uart_active     : in  std_logic;   -- UART receiving data
        cnn_result      : in  std_logic_vector(1 downto 0);  -- CNN classification
        cnn_valid       : in  std_logic;   -- CNN result valid
        
        -- Control outputs
        system_enable   : out std_logic;   -- System pause control
        
        -- LED outputs
        led             : out std_logic_vector(3 downto 0)
    );
end user_interface_controller;

architecture Behavioral of user_interface_controller is
    
    -- Debounce constants
    constant DEBOUNCE_TIME : integer := (CLK_FREQ / 1000) * DEBOUNCE_MS;  -- Clock cycles for debounce
    
    -- Button debouncing
    signal btn_stable    : std_logic := '0';
    signal btn_prev      : std_logic := '0';
    signal btn_edge      : std_logic := '0';
    signal btn_counter   : integer range 0 to DEBOUNCE_TIME := 0;
    
    -- System state
    signal paused        : std_logic := '0';  -- System pause state
    signal system_enable_int : std_logic := '1';
    
    -- LED signals
    signal led_int       : std_logic_vector(3 downto 0) := (others => '0');
    
begin
    
    -- Button debouncing process
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            btn_stable <= '0';
            btn_prev <= '0';
            btn_edge <= '0';
            btn_counter <= 0;
            
        elsif rising_edge(clk) then
            btn_edge <= '0';  -- Default: no edge
            
            -- Debounce logic
            if btn(0) /= btn_stable then
                -- Button state changed, start debounce counter
                if btn_counter < DEBOUNCE_TIME then
                    btn_counter <= btn_counter + 1;
                else
                    -- Debounce time elapsed, accept new state
                    btn_stable <= btn(0);
                    btn_counter <= 0;
                end if;
            else
                -- Button stable, reset counter
                btn_counter <= 0;
            end if;
            
            -- Edge detection (rising edge of stable button)
            btn_prev <= btn_stable;
            if btn_stable = '1' and btn_prev = '0' then
                btn_edge <= '1';
            end if;
            
        end if;
    end process;
    
    -- Pause/resume control
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            paused <= '0';
            system_enable_int <= '1';
            
        elsif rising_edge(clk) then
            
            -- Toggle pause on button press
            if btn_edge = '1' then
                paused <= not paused;
            end if;
            
            -- Update system enable (active low pause)
            system_enable_int <= not paused;
            
        end if;
    end process;
    
    -- LED control
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            led_int <= (others => '0');
            
        elsif rising_edge(clk) then
            
            -- LED[0]: UART active (blinks when receiving)
            led_int(0) <= uart_active;
            
            -- LED[1]: VGA active (always on when system running)
            led_int(1) <= system_enable_int;
            
            -- LED[2]: System paused
            led_int(2) <= paused;
            
            -- LED[3]: CNN result indicator
            -- Blink pattern based on classification result
            if cnn_valid = '1' then
                case cnn_result is
                    when "00" =>  -- Normal
                        led_int(3) <= '0';
                    when "01" =>  -- PVC/Ventricular
                        led_int(3) <= '1';
                    when "10" =>  -- AFib
                        led_int(3) <= '1';
                    when others =>
                        led_int(3) <= '0';
                end case;
            else
                led_int(3) <= '0';
            end if;
            
        end if;
    end process;
    
    -- Output assignments
    system_enable <= system_enable_int;
    led <= led_int;
    
end Behavioral;
