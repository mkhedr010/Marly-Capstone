--------------------------------------------------------------------------------
-- Weight ROM with SDRAM Backend
-- Reads CNN weights from external SDRAM instead of on-chip RAM
--
-- Interface is compatible with weight_rom.vhd
-- Just change component instantiation to use this instead
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity weight_rom_sdram is
    generic (
        DATA_WIDTH : integer := 16;
        ADDR_WIDTH : integer := 14;
        BASE_ADDR  : integer := 0;     -- SDRAM base address for this weight file
        SIZE       : integer := 1024   -- Number of weights in this file
    );
    port (
        clk     : in  std_logic;

        -- Same interface as weight_rom (drop-in replacement)
        addr_a  : in  integer range 0 to 16383;
        data_a  : out signed(DATA_WIDTH-1 downto 0);
        addr_b  : in  integer range 0 to 16383;
        data_b  : out signed(DATA_WIDTH-1 downto 0);

        -- SDRAM controller interface (shared bus)
        sdram_addr      : out std_logic_vector(22 downto 0);
        sdram_data_in   : in  std_logic_vector(15 downto 0);
        sdram_read_req  : out std_logic;
        sdram_data_valid: in  std_logic;
        sdram_busy      : in  std_logic
    );
end weight_rom_sdram;

architecture Behavioral of weight_rom_sdram is

    -- State machine for SDRAM reads
    type state_type is (IDLE, REQUEST_A, WAIT_A, REQUEST_B, WAIT_B);
    signal state : state_type := IDLE;

    -- Registered outputs
    signal data_a_reg : signed(15 downto 0);
    signal data_b_reg : signed(15 downto 0);

    -- Address registers
    signal addr_a_reg : integer range 0 to 16383;
    signal addr_b_reg : integer range 0 to 16383;

    signal read_pending : std_logic := '0';

begin

    -- Output assignments
    data_a <= data_a_reg;
    data_b <= data_b_reg;

    process(clk)
    begin
        if rising_edge(clk) then

            sdram_read_req <= '0';  -- Default

            case state is

                when IDLE =>
                    -- Check if address changed (new read needed)
                    if addr_a /= addr_a_reg and addr_a < SIZE then
                        addr_a_reg <= addr_a;
                        state <= REQUEST_A;
                    elsif addr_b /= addr_b_reg and addr_b < SIZE then
                        addr_b_reg <= addr_b;
                        state <= REQUEST_B;
                    end if;

                when REQUEST_A =>
                    if sdram_busy = '0' then
                        -- Issue SDRAM read for port A
                        sdram_addr <= std_logic_vector(to_unsigned(BASE_ADDR + addr_a_reg, 23));
                        sdram_read_req <= '1';
                        state <= WAIT_A;
                    end if;

                when WAIT_A =>
                    if sdram_data_valid = '1' then
                        data_a_reg <= signed(sdram_data_in);
                        state <= IDLE;
                    end if;

                when REQUEST_B =>
                    if sdram_busy = '0' then
                        -- Issue SDRAM read for port B
                        sdram_addr <= std_logic_vector(to_unsigned(BASE_ADDR + addr_b_reg, 23));
                        sdram_read_req <= '1';
                        state <= WAIT_B;
                    end if;

                when WAIT_B =>
                    if sdram_data_valid = '1' then
                        data_b_reg <= signed(sdram_data_in);
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;

            end case;

        end if;
    end process;

end Behavioral;
