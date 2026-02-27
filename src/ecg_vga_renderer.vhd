--------------------------------------------------------------------------------
-- ECG VGA Renderer
-- Displays scrolling ECG waveform on VGA monitor
--
-- Features:
--   - Circular waveform buffer (640 samples = 640 pixels wide)
--   - Updates buffer on sample_valid from UART
--   - Scrolling display (new samples appear on right)
--   - Y-mapping: ecg_value → pixel Y coordinate
--
-- Author: Marly
-- Date: January 21, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ecg_vga_renderer is
    generic (
        WAVEFORM_WIDTH : integer := 640  -- Number of samples in buffer
    );
    port (
        clk_pixel     : in  std_logic;   -- 25 MHz VGA pixel clock
        clk_system    : in  std_logic;   -- 50 MHz system clock
        reset_n       : in  std_logic;
        
        -- VGA timing inputs
        pixel_x       : in  std_logic_vector(9 downto 0);
        pixel_y       : in  std_logic_vector(9 downto 0);
        display_on    : in  std_logic;
        
        -- ECG sample input (from UART)
        ecg_sample    : in  std_logic_vector(11 downto 0);
        sample_valid  : in  std_logic;   -- Pulse when new sample arrives
        
        -- RGB output
        vga_r         : out std_logic_vector(2 downto 0);
        vga_g         : out std_logic_vector(2 downto 0);
        vga_b         : out std_logic_vector(1 downto 0)
    );
end ecg_vga_renderer;

architecture Behavioral of ecg_vga_renderer is
    
    -- Waveform buffer (circular buffer storing last 640 samples)
    type waveform_buffer_type is array (0 to WAVEFORM_WIDTH-1) of signed(11 downto 0);
    signal waveform_buffer : waveform_buffer_type := (others => (others => '0'));
    
    -- Write pointer (advances with each new sample)
    signal write_ptr : integer range 0 to WAVEFORM_WIDTH-1 := 0;
    
    -- VGA read signals
    signal pixel_x_int : integer range 0 to 1023 := 0;
    signal pixel_y_int : integer range 0 to 1023 := 0;
    
    -- Current sample being displayed
    signal current_sample : signed(11 downto 0) := (others => '0');
    signal sample_y : integer range 0 to 511 := 240;
    
    -- RGB signals
    signal rgb_out : std_logic_vector(7 downto 0) := (others => '0');
    
begin
    
    -- Waveform buffer write process (system clock domain)
    process(clk_system, reset_n)
    begin
        if reset_n = '0' then
            write_ptr <= 0;
            waveform_buffer <= (others => (others => '0'));
            
        elsif rising_edge(clk_system) then
            
            -- Write new sample when available
            if sample_valid = '1' then
                waveform_buffer(write_ptr) <= signed(ecg_sample);
                
                -- Advance write pointer (circular)
                if write_ptr = WAVEFORM_WIDTH-1 then
                    write_ptr <= 0;
                else
                    write_ptr <= write_ptr + 1;
                end if;
            end if;
            
        end if;
    end process;
    
    -- Convert pixel coordinates to integers
    pixel_x_int <= to_integer(unsigned(pixel_x));
    pixel_y_int <= to_integer(unsigned(pixel_y));
    
    -- VGA rendering process (pixel clock domain)
    process(clk_pixel, reset_n)
        variable y_position : integer range 0 to 511;
    begin
        if reset_n = '0' then
            rgb_out <= (others => '0');
            current_sample <= (others => '0');
            sample_y <= 240;
            
        elsif rising_edge(clk_pixel) then
            
            -- Default: black background
            rgb_out <= "00000000";  -- All RGB off
            
            if display_on = '1' then
                
                -- Read sample from buffer for current X position
                if pixel_x_int < WAVEFORM_WIDTH then
                    current_sample <= waveform_buffer(pixel_x_int);
                    
                    -- Convert ECG value to Y coordinate
                    -- Y = 240 - (ecg_value / 10)
                    -- Center at Y=240, scale so ±2048 fits in ±200 pixels
                    y_position := 240 - (to_integer(current_sample) / 10);
                    
                    -- Clip to valid range
                    if y_position < 0 then
                        y_position := 0;
                    elsif y_position > 479 then
                        y_position := 479;
                    end if;
                    
                    sample_y <= y_position;
                    
                    -- Draw pixel if current Y matches waveform Y
                    -- Allow ±1 pixel tolerance for visibility
                    if pixel_y_int >= sample_y-1 and pixel_y_int <= sample_y+1 then
                        rgb_out <= "00011100";  -- Green (R=0, G=7, B=0)
                    end if;
                    
                    -- Optional: Draw baseline at Y=240
                    if pixel_y_int = 240 then
                        rgb_out <= "01000100";  -- Dark gray baseline
                    end if;
                end if;
                
            end if;
            
        end if;
    end process;
    
    -- Map 8-bit RGB to output pins (assuming 3-3-2 RGB)
    vga_r <= rgb_out(7 downto 5);  -- 3 bits red
    vga_g <= rgb_out(4 downto 2);  -- 3 bits green
    vga_b <= rgb_out(1 downto 0);  -- 2 bits blue
    
end Behavioral;
