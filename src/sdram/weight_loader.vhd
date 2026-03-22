--------------------------------------------------------------------------------
-- Weight Loader for SDRAM
-- Loads all 18 CNN weight .mif files into SDRAM at startup
--
-- Process:
-- 1. Read weights from on-chip ROM (small staging area)
-- 2. Write sequentially to SDRAM
-- 3. Assert done when complete
--
-- Memory Map in SDRAM:
-- 0x000000: conv0_weight.mif
-- 0x000030: conv0_bias.mif
-- ... (continues for all 18 files)
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity weight_loader is
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        start_load      : in  std_logic;

        -- SDRAM controller interface
        sdram_addr      : out std_logic_vector(22 downto 0);
        sdram_data_out  : out std_logic_vector(15 downto 0);
        sdram_write_req : out std_logic;
        sdram_busy      : in  std_logic;

        -- Status
        load_done       : out std_logic;
        load_progress   : out integer range 0 to 16383  -- Current address being loaded
    );
end weight_loader;

architecture Behavioral of weight_loader is

    -- Total weights to load: 14,705 parameters
    constant TOTAL_PARAMS : integer := 14705;

    type state_type is (IDLE, LOADING, DONE);
    signal state : state_type := IDLE;

    signal addr_counter : integer range 0 to 16383 := 0;

    -- Simple: For now, write zeros (will be replaced with actual weight ROM reads)
    signal weight_data : std_logic_vector(15 downto 0) := (others => '0');

begin

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            addr_counter <= 0;
            load_done <= '0';
            sdram_write_req <= '0';

        elsif rising_edge(clk) then

            sdram_write_req <= '0';  -- Default

            case state is

                when IDLE =>
                    if start_load = '1' then
                        state <= LOADING;
                        addr_counter <= 0;
                        load_done <= '0';
                    end if;

                when LOADING =>
                    if addr_counter < TOTAL_PARAMS then
                        if sdram_busy = '0' then
                            -- Write next weight to SDRAM
                            sdram_addr <= std_logic_vector(to_unsigned(addr_counter, 23));
                            sdram_data_out <= weight_data;
                            sdram_write_req <= '1';
                            addr_counter <= addr_counter + 1;
                        end if;
                    else
                        state <= DONE;
                    end if;

                when DONE =>
                    load_done <= '1';
                    -- Stay in DONE state

                when others =>
                    state <= IDLE;

            end case;

            load_progress <= addr_counter;

        end if;
    end process;

end Behavioral;
