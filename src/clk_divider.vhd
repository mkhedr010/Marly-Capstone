--------------------------------------------------------------------------------
-- Clock Divider Module
-- Divides 50 MHz system clock to 25 MHz for VGA pixel clock
--
-- Author: Marly
-- Date: January 21, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity clk_divider is
    port (
        clk_in   : in  std_logic;   -- 50 MHz input
        reset_n  : in  std_logic;
        clk_out  : out std_logic    -- 25 MHz output
    );
end clk_divider;

architecture Behavioral of clk_divider is
    signal clk_out_reg : std_logic := '0';
begin
    
    process(clk_in, reset_n)
    begin
        if reset_n = '0' then
            clk_out_reg <= '0';
        elsif rising_edge(clk_in) then
            -- Toggle every cycle (divide by 2)
            clk_out_reg <= not clk_out_reg;
        end if;
    end process;
    
    clk_out <= clk_out_reg;
    
end Behavioral;
