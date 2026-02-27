--------------------------------------------------------------------------------
-- ECG System Top Level
-- Complete ECG simulation and visualization system
--
-- System Architecture:
--   PC (Python) → UART → FPGA → VGA Display + CNN Module
--
-- Components:
--   1. UART Receiver - Receives ECG data from PC
--   2. VGA Controller - Displays scrolling ECG waveform
--   3. User Interface - Button control and LED status
--   4. CNN Interface - Connects to Ayoub's CNN classifier
--
-- Author: Marly
-- Date: January 21, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ecg_system_top is
    generic (
        CLK_FREQ        : integer := 50_000_000;   -- 50 MHz system clock
        UART_BAUD       : integer := 115200;       -- UART baud rate
        VGA_PIXEL_FREQ  : integer := 25_000_000    -- 25 MHz VGA pixel clock
    );
    port (
        -- Clock and Reset
        clk_50mhz    : in  std_logic;
        reset_n      : in  std_logic;
        
        -- UART Interface (from PC)
        uart_rx      : in  std_logic;
        
        -- User Interface
        btn          : in  std_logic_vector(0 downto 0);  -- Pause button
        led          : out std_logic_vector(3 downto 0);  -- Status LEDs
        
        -- VGA Output
        vga_hsync    : out std_logic;
        vga_vsync    : out std_logic;
        vga_r        : out std_logic_vector(2 downto 0);
        vga_g        : out std_logic_vector(2 downto 0);
        vga_b        : out std_logic_vector(1 downto 0);
        
        -- CNN Interface (connects to Ayoub's module - internal signals)
        cnn_sample   : out std_logic_vector(11 downto 0);
        cnn_valid    : out std_logic;
        cnn_result   : in  std_logic_vector(1 downto 0);
        cnn_result_valid : in  std_logic
    );
end ecg_system_top;

architecture Behavioral of ecg_system_top is
    
    -- Component declarations
    component clk_divider
        port (
            clk_in   : in  std_logic;
            reset_n  : in  std_logic;
            clk_out  : out std_logic
        );
    end component;
    
    component uart_receiver
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
    
    component vga_timing_generator
        port (
            clk_pixel   : in  std_logic;
            reset_n     : in  std_logic;
            hsync       : out std_logic;
            vsync       : out std_logic;
            display_on  : out std_logic;
            pixel_x     : out std_logic_vector(9 downto 0);
            pixel_y     : out std_logic_vector(9 downto 0)
        );
    end component;
    
    component ecg_vga_renderer
        generic (
            WAVEFORM_WIDTH : integer
        );
        port (
            clk_pixel     : in  std_logic;
            clk_system    : in  std_logic;
            reset_n       : in  std_logic;
            pixel_x       : in  std_logic_vector(9 downto 0);
            pixel_y       : in  std_logic_vector(9 downto 0);
            display_on    : in  std_logic;
            ecg_sample    : in  std_logic_vector(11 downto 0);
            sample_valid  : in  std_logic;
            vga_r         : out std_logic_vector(2 downto 0);
            vga_g         : out std_logic_vector(2 downto 0);
            vga_b         : out std_logic_vector(1 downto 0)
        );
    end component;
    
    component user_interface_controller
        generic (
            CLK_FREQ     : integer;
            DEBOUNCE_MS  : integer
        );
        port (
            clk             : in  std_logic;
            reset_n         : in  std_logic;
            btn             : in  std_logic_vector(0 downto 0);
            uart_active     : in  std_logic;
            cnn_result      : in  std_logic_vector(1 downto 0);
            cnn_valid       : in  std_logic;
            system_enable   : out std_logic;
            led             : out std_logic_vector(3 downto 0)
        );
    end component;
    
    component cnn_interface
        port (
            clk             : in  std_logic;
            reset_n         : in  std_logic;
            ecg_sample_in   : in  std_logic_vector(11 downto 0);
            sample_valid_in : in  std_logic;
            cnn_sample      : out std_logic_vector(11 downto 0);
            cnn_valid       : out std_logic;
            cnn_result      : in  std_logic_vector(1 downto 0);
            cnn_result_valid: in  std_logic
        );
    end component;
    
    -- Internal signals
    
    -- Clock signals
    signal clk_25mhz : std_logic;
    
    -- UART signals
    signal ecg_sample_uart   : std_logic_vector(11 downto 0);
    signal sample_valid_uart : std_logic;
    signal uart_error_int    : std_logic;
    signal uart_active_int   : std_logic;
    
    -- VGA timing signals
    signal pixel_x_int     : std_logic_vector(9 downto 0);
    signal pixel_y_int     : std_logic_vector(9 downto 0);
    signal display_on_int  : std_logic;
    
    -- User interface signals
    signal system_enable_int : std_logic;
    
    -- CNN interface internal signals
    signal cnn_sample_int      : std_logic_vector(11 downto 0);
    signal cnn_valid_int       : std_logic;
    
begin
    
    -- Clock Divider: 50 MHz → 25 MHz for VGA
    clk_div_inst : clk_divider
        port map (
            clk_in  => clk_50mhz,
            reset_n => reset_n,
            clk_out => clk_25mhz
        );
    
    -- UART Receiver: Receives ECG samples from PC
    uart_rx_inst : uart_receiver
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => UART_BAUD
        )
        port map (
            clk          => clk_50mhz,
            reset_n      => reset_n,
            uart_rx      => uart_rx,
            ecg_sample   => ecg_sample_uart,
            sample_valid => sample_valid_uart,
            uart_error   => uart_error_int,
            uart_active  => uart_active_int
        );
    
    -- VGA Timing Generator: Generates sync signals and pixel coordinates
    vga_timing_inst : vga_timing_generator
        port map (
            clk_pixel  => clk_25mhz,
            reset_n    => reset_n,
            hsync      => vga_hsync,
            vsync      => vga_vsync,
            display_on => display_on_int,
            pixel_x    => pixel_x_int,
            pixel_y    => pixel_y_int
        );
    
    -- ECG VGA Renderer: Displays scrolling waveform
    vga_renderer_inst : ecg_vga_renderer
        generic map (
            WAVEFORM_WIDTH => 640
        )
        port map (
            clk_pixel    => clk_25mhz,
            clk_system   => clk_50mhz,
            reset_n      => reset_n,
            pixel_x      => pixel_x_int,
            pixel_y      => pixel_y_int,
            display_on   => display_on_int,
            ecg_sample   => ecg_sample_uart,
            sample_valid => sample_valid_uart,
            vga_r        => vga_r,
            vga_g        => vga_g,
            vga_b        => vga_b
        );
    
    -- User Interface Controller: Button and LED control
    ui_ctrl_inst : user_interface_controller
        generic map (
            CLK_FREQ    => CLK_FREQ,
            DEBOUNCE_MS => 50
        )
        port map (
            clk           => clk_50mhz,
            reset_n       => reset_n,
            btn           => btn,
            uart_active   => uart_active_int,
            cnn_result    => cnn_result,
            cnn_valid     => cnn_result_valid,
            system_enable => system_enable_int,
            led           => led
        );
    
    -- CNN Interface: Connects to Ayoub's CNN module
    cnn_if_inst : cnn_interface
        port map (
            clk              => clk_50mhz,
            reset_n          => reset_n,
            ecg_sample_in    => ecg_sample_uart,
            sample_valid_in  => sample_valid_uart,
            cnn_sample       => cnn_sample_int,
            cnn_valid        => cnn_valid_int,
            cnn_result       => cnn_result,
            cnn_result_valid => cnn_result_valid
        );
    
    -- Map CNN interface to top-level ports
    cnn_sample <= cnn_sample_int;
    cnn_valid  <= cnn_valid_int;
    
end Behavioral;
