--------------------------------------------------------------------------------
-- 1D Max Pooling Module
-- Takes two consecutive values and outputs the maximum
-- Pool size = 2, stride = 2
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity maxpool1d is
    generic (
        DATA_WIDTH : integer := 16  -- Q8.8 fixed-point
    );
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        enable    : in  std_logic;

        -- Input: two consecutive values
        input_0   : in  signed(DATA_WIDTH-1 downto 0);
        input_1   : in  signed(DATA_WIDTH-1 downto 0);

        -- Output: maximum value
        output    : out signed(DATA_WIDTH-1 downto 0);
        valid     : out std_logic
    );
end maxpool1d;

architecture Behavioral of maxpool1d is
begin

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            output <= (others => '0');
            valid <= '0';

        elsif rising_edge(clk) then

            if enable = '1' then
                -- Select maximum of two inputs
                if input_0 > input_1 then
                    output <= input_0;
                else
                    output <= input_1;
                end if;
                valid <= '1';
            else
                valid <= '0';
            end if;

        end if;
    end process;

end Behavioral;
