--------------------------------------------------------------------------------
-- Simple Demo Top-Level
-- Minimal configuration for UART streaming demo with LED indicators
--
-- This is a simplified version for initial testing - just UART RX + LEDs
-- No VGA, no CNN interface yet
--
-- Author: Marly
-- Date: February 26, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity simple_demo_top is
    port (
        -- Clock and Reset
        clk_50mhz : in  std_logic;
        reset_n   : in  std_logic;
        
        -- UART Interface
        uart_rx   : in  std_logic;
        
        -- LED Outputs (4 LEDs)
        led       : out std_logic_vector(3 downto 0)
    );
end simple_demo_top;

architecture Behavioral of simple_demo_top is
    
    -- Component declarations
    component uart_receiver is
        generic (
            CLK_FREQ  : integer;
            BAUD_RATE : integer
        );
        port (
            clk          : in  std_logic;
            reset_n      : in  std_logic;
            uart_rx      : in  std_logic;
            ecg_sample   : out std_logic_vector(11 downto 0);
            sample_valid : out std_logic;
            uart_error   : out std_logic;
            uart_active  : out std_logic
        );
    end component;
    
    component led_indicator is
        generic (
            CLK_FREQ : integer
        );
        port (
            clk          : in  std_logic;
            reset_n      : in  std_logic;
            sample_valid : in  std_logic;
            uart_active  : in  std_logic;
            uart_error   : in  std_logic;
            led_data     : out std_logic;
            led_active   : out std_logic;
            led_error    : out std_logic;
            led_heartbeat: out std_logic
        );
    end component;
    
    -- Constants
    constant CLK_FREQ  : integer := 50_000_000;
    constant BAUD_RATE : integer := 115200;
    
    -- Internal signals
    signal ecg_sample_int   : std_logic_vector(11 downto 0);
    signal sample_valid_int : std_logic;
    signal uart_error_int   : std_logic;
    signal uart_active_int  : std_logic;
    
    signal led_data_int      : std_logic;
    signal led_active_int    : std_logic;
    signal led_error_int     : std_logic;
    signal led_heartbeat_int : std_logic;
    
begin
    
    --------------------------------------------------------------------------------
    -- UART Receiver
    --------------------------------------------------------------------------------
    uart_rx_inst : uart_receiver
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk          => clk_50mhz,
            reset_n      => reset_n,
            uart_rx      => uart_rx,
            ecg_sample   => ecg_sample_int,
            sample_valid => sample_valid_int,
            uart_error   => uart_error_int,
            uart_active  => uart_active_int
        );
    
    --------------------------------------------------------------------------------
    -- LED Indicator
    --------------------------------------------------------------------------------
    led_ind_inst : led_indicator
        generic map (
            CLK_FREQ => CLK_FREQ
        )
        port map (
            clk          => clk_50mhz,
            reset_n      => reset_n,
            sample_valid => sample_valid_int,
            uart_active  => uart_active_int,
            uart_error   => uart_error_int,
            led_data     => led_data_int,
            led_active   => led_active_int,
            led_error    => led_error_int,
            led_heartbeat=> led_heartbeat_int
        );
    
    --------------------------------------------------------------------------------
    -- LED Output Mapping
    -- LED[0]: Data toggle (blinks on each sample)
    -- LED[1]: UART active (on when receiving)
    -- LED[2]: Error (blinks if error)
    -- LED[3]: Heartbeat (system alive)
    --------------------------------------------------------------------------------
    led(0) <= led_data_int;
    led(1) <= led_active_int;
    led(2) <= led_error_int;
    led(3) <= led_heartbeat_int;
    
end Behavioral;
