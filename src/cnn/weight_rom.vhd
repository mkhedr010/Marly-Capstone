--------------------------------------------------------------------------------
-- Weight ROM Module
-- Simple dual-port ROM that Quartus will infer as M4K blocks
-- Initialized from .mif files
--
-- CRITICAL: No logic on reads - pure synchronous pattern for M4K inference
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity weight_rom is
    generic (
        DATA_WIDTH : integer := 16;
        ADDR_WIDTH : integer := 14;
        INIT_FILE  : string := "weights.mif"
    );
    port (
        clk     : in  std_logic;
        addr_a  : in  integer range 0 to 16383;
        data_a  : out signed(DATA_WIDTH-1 downto 0);
        addr_b  : in  integer range 0 to 16383;
        data_b  : out signed(DATA_WIDTH-1 downto 0)
    );
end weight_rom;

architecture rtl of weight_rom is

    -- ROM storage
    type rom_type is array (0 to 2**ADDR_WIDTH-1) of signed(DATA_WIDTH-1 downto 0);
    signal rom_data : rom_type := (others => (others => '0'));

    -- Quartus attributes for M4K inference and .mif loading
    attribute ram_init_file : string;
    attribute ram_init_file of rom_data : signal is INIT_FILE;

    attribute ramstyle : string;
    attribute ramstyle of rom_data : signal is "M4K";

begin

    -- Port A: Pure synchronous read (NO LOGIC - required for M4K inference)
    process(clk)
    begin
        if rising_edge(clk) then
            data_a <= rom_data(addr_a);
        end if;
    end process;

    -- Port B: Pure synchronous read (NO LOGIC - required for M4K inference)
    process(clk)
    begin
        if rising_edge(clk) then
            data_b <= rom_data(addr_b);
        end if;
    end process;

end rtl;
