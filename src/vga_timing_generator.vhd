--------------------------------------------------------------------------------
-- VGA Timing Generator
-- Generates sync signals and pixel coordinates for 640×480 @ 60Hz VGA
--
-- Timing Specifications:
--   Horizontal: 640 visible + 16 front porch + 96 sync + 48 back porch = 800 total
--   Vertical:   480 visible + 10 front porch + 2 sync + 33 back porch = 525 total
--   Pixel Clock: 25 MHz (from clk_divider)
--
-- Author: Marly
-- Date: January 21, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity vga_timing_generator is
    port (
        clk_pixel   : in  std_logic;   -- 25 MHz pixel clock
        reset_n     : in  std_logic;
        
        hsync       : out std_logic;   -- Horizontal sync
        vsync       : out std_logic;   -- Vertical sync
        display_on  : out std_logic;   -- High when in visible region
        
        pixel_x     : out std_logic_vector(9 downto 0);  -- 0-799
        pixel_y     : out std_logic_vector(9 downto 0)   -- 0-524
    );
end vga_timing_generator;

architecture Behavioral of vga_timing_generator is
    
    -- Horizontal timing constants (640×480 @ 60Hz)
    constant H_DISPLAY   : integer := 640;
    constant H_FPORCH    : integer := 16;
    constant H_SYNC      : integer := 96;
    constant H_BPORCH    : integer := 48;
    constant H_TOTAL     : integer := 800;  -- 640 + 16 + 96 + 48
    
    -- Vertical timing constants
    constant V_DISPLAY   : integer := 480;
    constant V_FPORCH    : integer := 10;
    constant V_SYNC      : integer := 2;
    constant V_BPORCH    : integer := 33;
    constant V_TOTAL     : integer := 525;  -- 480 + 10 + 2 + 33
    
    -- Sync pulse start positions
    constant H_SYNC_START : integer := H_DISPLAY + H_FPORCH;        -- 656
    constant H_SYNC_END   : integer := H_SYNC_START + H_SYNC;       -- 752
    constant V_SYNC_START : integer := V_DISPLAY + V_FPORCH;        -- 490
    constant V_SYNC_END   : integer := V_SYNC_START + V_SYNC;       -- 492
    
    -- Counters
    signal h_count : integer range 0 to H_TOTAL-1 := 0;
    signal v_count : integer range 0 to V_TOTAL-1 := 0;
    
    -- Internal signals
    signal hsync_int      : std_logic := '1';
    signal vsync_int      : std_logic := '1';
    signal display_on_int : std_logic := '0';
    
begin
    
    -- Horizontal and Vertical counter process
    process(clk_pixel, reset_n)
    begin
        if reset_n = '0' then
            h_count <= 0;
            v_count <= 0;
            hsync_int <= '1';
            vsync_int <= '1';
            display_on_int <= '0';
            
        elsif rising_edge(clk_pixel) then
            
            -- Horizontal counter
            if h_count = H_TOTAL-1 then
                h_count <= 0;
                
                -- Vertical counter (increments at end of each line)
                if v_count = V_TOTAL-1 then
                    v_count <= 0;
                else
                    v_count <= v_count + 1;
                end if;
            else
                h_count <= h_count + 1;
            end if;
            
            -- Generate HSYNC (negative polarity)
            if h_count >= H_SYNC_START and h_count < H_SYNC_END then
                hsync_int <= '0';
            else
                hsync_int <= '1';
            end if;
            
            -- Generate VSYNC (negative polarity)
            if v_count >= V_SYNC_START and v_count < V_SYNC_END then
                vsync_int <= '0';
            else
                vsync_int <= '1';
            end if;
            
            -- Display enable signal (high during visible region)
            if h_count < H_DISPLAY and v_count < V_DISPLAY then
                display_on_int <= '1';
            else
                display_on_int <= '0';
            end if;
            
        end if;
    end process;
    
    -- Output assignments
    hsync      <= hsync_int;
    vsync      <= vsync_int;
    display_on <= display_on_int;
    pixel_x    <= std_logic_vector(to_unsigned(h_count, 10));
    pixel_y    <= std_logic_vector(to_unsigned(v_count, 10));
    
end Behavioral;
