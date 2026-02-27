--------------------------------------------------------------------------------
-- LED Indicator Module
-- Blinks LED to show UART data reception activity
--
-- LED blinks/toggles when sample_valid pulses (data received)
--
-- Author: Marly
-- Date: February 26, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity led_indicator is
    generic (
        CLK_FREQ : integer := 50_000_000  -- 50 MHz
    );
    port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;
        
        -- Input signals
        sample_valid : in  std_logic;    -- Pulse from UART receiver
        uart_active  : in  std_logic;    -- UART receiving status
        uart_error   : in  std_logic;    -- UART error flag
        
        -- LED outputs
        led_data     : out std_logic;    -- Toggles on each sample
        led_active   : out std_logic;    -- On when UART active
        led_error    : out std_logic;    -- Blinks on error
        led_heartbeat: out std_logic     -- Heartbeat (system alive)
    );
end led_indicator;

architecture Behavioral of led_indicator is
    
    -- LED toggle for data reception
    signal led_data_reg : std_logic := '0';
    
    -- Heartbeat counter (blinks at ~1 Hz)
    constant HEARTBEAT_PERIOD : integer := CLK_FREQ / 2;  -- 0.5s = 1Hz blink
    signal heartbeat_counter  : integer range 0 to HEARTBEAT_PERIOD-1 := 0;
    signal led_heartbeat_reg  : std_logic := '0';
    
    -- Error blink counter (fast blink at ~5 Hz)
    constant ERROR_PERIOD : integer := CLK_FREQ / 10;  -- 0.1s = 5Hz blink
    signal error_counter  : integer range 0 to ERROR_PERIOD-1 := 0;
    signal led_error_reg  : std_logic := '0';
    signal error_latched  : std_logic := '0';
    
    -- Sample valid edge detection
    signal sample_valid_prev : std_logic := '0';
    
begin
    
    -- Main LED control process
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            led_data_reg <= '0';
            led_heartbeat_reg <= '0';
            led_error_reg <= '0';
            heartbeat_counter <= 0;
            error_counter <= 0;
            sample_valid_prev <= '0';
            error_latched <= '0';
            
        elsif rising_edge(clk) then
            
            -- Edge detection for sample_valid
            sample_valid_prev <= sample_valid;
            
            -- Toggle LED on rising edge of sample_valid (new sample received)
            if sample_valid = '1' and sample_valid_prev = '0' then
                led_data_reg <= not led_data_reg;
            end if;
            
            -- Heartbeat LED (toggles every 0.5s)
            if heartbeat_counter < HEARTBEAT_PERIOD-1 then
                heartbeat_counter <= heartbeat_counter + 1;
            else
                heartbeat_counter <= 0;
                led_heartbeat_reg <= not led_heartbeat_reg;
            end if;
            
            -- Error LED (latch error and blink fast)
            if uart_error = '1' then
                error_latched <= '1';
            end if
;            
            if error_latched = '1' then
                if error_counter < ERROR_PERIOD-1 then
                    error_counter <= error_counter + 1;
                else
                    error_counter <= 0;
                    led_error_reg <= not led_error_reg;
                end if;
            end if;
            
        end if;
    end process;
    
    -- Output assignments
    led_data      <= led_data_reg;
    led_active    <= uart_active;
    led_error     <= led_error_reg;
    led_heartbeat <= led_heartbeat_reg;
    
end Behavioral;
