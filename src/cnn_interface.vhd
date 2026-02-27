--------------------------------------------------------------------------------
-- CNN Interface Module
-- Connects simulation component to Ayoub's CNN classifier module
--
-- This is a simple passthrough that connects internal FPGA signals
-- between your component and the CNN module.
--
-- Author: Marly
-- Date: January 21, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cnn_interface is
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        
        -- From UART receiver / system
        ecg_sample_in   : in  std_logic_vector(11 downto 0);
        sample_valid_in : in  std_logic;
        
        -- To CNN module (Ayoub's)
        cnn_sample      : out std_logic_vector(11 downto 0);
        cnn_valid       : out std_logic;
        
        -- From CNN module
        cnn_result      : in  std_logic_vector(1 downto 0);
        cnn_result_valid: in  std_logic
    );
end cnn_interface;

architecture Behavioral of cnn_interface is
    
    -- Internal buffering (optional - can be simple passthrough)
    signal sample_buffer : std_logic_vector(11 downto 0) := (others => '0');
    signal valid_buffer  : std_logic := '0';
    
begin
    
    -- Simple registered passthrough
    -- (Can add buffering/FIFO if CNN has timing requirements)
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            sample_buffer <= (others => '0');
            valid_buffer <= '0';
            
        elsif rising_edge(clk) then
            
            -- Register inputs to CNN
            sample_buffer <= ecg_sample_in;
            valid_buffer <= sample_valid_in;
            
        end if;
    end process;
    
    -- Output to CNN module
    cnn_sample <= sample_buffer;
    cnn_valid  <= valid_buffer;
    
    -- Note: cnn_result and cnn_result_valid are inputs from CNN
    -- They are passed through to top-level for LED/VGA display
    
end Behavioral;
