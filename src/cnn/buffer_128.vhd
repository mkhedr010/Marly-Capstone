--------------------------------------------------------------------------------
-- Input Sample Buffer (128 samples)
-- Dual-port RAM for storing incoming ECG samples
--
-- Port A: Write port (from UART receiver)
-- Port B: Read port (for CNN processing)
--
-- Implements ping-pong buffering for continuous operation
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity buffer_128 is
    generic (
        DATA_WIDTH : integer := 12;  -- ECG sample width
        DEPTH      : integer := 128  -- Buffer depth
    );
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;

        -- Write port (from UART)
        wr_addr : in  integer range 0 to DEPTH-1;
        wr_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        wr_en   : in  std_logic;

        -- Read port (for CNN)
        rd_addr : in  integer range 0 to DEPTH-1;
        rd_data : out signed(15 downto 0)  -- Extended to 16-bit Q8.8 format
    );
end buffer_128;

architecture Behavioral of buffer_128 is

    -- Dual-port RAM
    type ram_type is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram : ram_type := (others => (others => '0'));

    signal rd_data_raw : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

    -- Write process
    process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' then
                ram(wr_addr) <= wr_data;
            end if;
        end if;
    end process;

    -- Read process
    process(clk)
    begin
        if rising_edge(clk) then
            rd_data_raw <= ram(rd_addr);
        end if;
    end process;

    -- Convert 12-bit ECG sample to 16-bit Q8.8 fixed-point
    -- ECG range: -2048 to +2047 (signed 12-bit)
    -- Q8.8 range: -128.0 to +127.996 (signed 16-bit, 8 fractional bits)
    -- Scaling: divide by 16 to fit range
    process(clk)
        variable temp : signed(15 downto 0);
    begin
        if rising_edge(clk) then
            -- Sign-extend 12-bit to 16-bit, then divide by 16 (shift right 4)
            temp := signed(rd_data_raw(11) & rd_data_raw(11) & rd_data_raw(11) & rd_data_raw(11) & rd_data_raw);
            rd_data <= shift_right(temp, 4);  -- Divide by 16 to normalize
        end if;
    end process;

end Behavioral;
