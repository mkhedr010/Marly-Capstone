--------------------------------------------------------------------------------
-- Layer Buffer - Intermediate Activation Storage
-- Dual-port RAM for storing layer outputs between processing stages
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity layer_buffer is
    generic (
        DATA_WIDTH : integer := 16;
        DEPTH      : integer := 128
    );
    port (
        clk     : in  std_logic;

        -- Write port
        wr_addr : in  integer range 0 to 8191;
        wr_data : in  signed(DATA_WIDTH-1 downto 0);
        wr_en   : in  std_logic;

        -- Read port
        rd_addr : in  integer range 0 to 8191;
        rd_data : out signed(DATA_WIDTH-1 downto 0)
    );
end layer_buffer;

architecture Behavioral of layer_buffer is

    type ram_type is array (0 to DEPTH-1) of signed(DATA_WIDTH-1 downto 0);
    signal ram : ram_type := (others => (others => '0'));

begin

    -- Write process
    process(clk)
    begin
        if rising_edge(clk) then
            if wr_en = '1' and wr_addr < DEPTH then
                ram(wr_addr) <= wr_data;
            end if;
        end if;
    end process;

    -- Read process
    process(clk)
    begin
        if rising_edge(clk) then
            if rd_addr < DEPTH then
                rd_data <= ram(rd_addr);
            else
                rd_data <= (others => '0');
            end if;
        end if;
    end process;

end Behavioral;