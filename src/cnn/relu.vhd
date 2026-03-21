--------------------------------------------------------------------------------
-- ReLU Activation Function
-- Rectified Linear Unit: output = max(0, input)
--
-- For fixed-point Q8.8 format
-- If input is negative (MSB = 1), output = 0
-- Otherwise, output = input
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity relu is
    generic (
        DATA_WIDTH : integer := 16  -- Q8.8 fixed-point
    );
    port (
        input  : in  signed(DATA_WIDTH-1 downto 0);
        output : out signed(DATA_WIDTH-1 downto 0)
    );
end relu;

architecture Behavioral of relu is
begin

    -- ReLU: output = max(0, input)
    output <= input when input(DATA_WIDTH-1) = '0' else (others => '0');

end Behavioral;
