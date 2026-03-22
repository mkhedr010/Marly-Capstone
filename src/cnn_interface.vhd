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

        -- To CNN module (for debugging/monitoring)
        cnn_sample      : out std_logic_vector(11 downto 0);
        cnn_valid       : out std_logic;

        -- From CNN module (now generated internally)
        cnn_result      : out std_logic_vector(1 downto 0);
        cnn_result_valid: out std_logic;

        -- SDRAM interface (pass-through to zolotyhnet)
        sdram_addr      : out std_logic_vector(22 downto 0);
        sdram_data_in   : in  std_logic_vector(15 downto 0);
        sdram_data_out  : out std_logic_vector(15 downto 0);
        sdram_read_req  : out std_logic;
        sdram_write_req : out std_logic;
        sdram_data_valid: in  std_logic;
        sdram_busy      : in  std_logic
    );
end cnn_interface;

architecture Behavioral of cnn_interface is

    -- Component declaration for ZolotyhNet CNN
    component zolotyhnet_top
        port (
            clk             : in  std_logic;
            reset_n         : in  std_logic;
            ecg_sample      : in  std_logic_vector(11 downto 0);
            sample_valid    : in  std_logic;
            class_result    : out std_logic_vector(2 downto 0);
            result_valid    : out std_logic;
            sdram_addr      : out std_logic_vector(22 downto 0);
            sdram_data_in   : in  std_logic_vector(15 downto 0);
            sdram_data_out  : out std_logic_vector(15 downto 0);
            sdram_read_req  : out std_logic;
            sdram_write_req : out std_logic;
            sdram_data_valid: in  std_logic;
            sdram_busy      : in  std_logic
        );
    end component;

    -- Internal signals
    signal class_result_int : std_logic_vector(2 downto 0);
    signal result_valid_int : std_logic;

begin

    --------------------------------------------------------------------------------
    -- Instantiate ZolotyhNet CNN
    --------------------------------------------------------------------------------
    cnn_inst : zolotyhnet_top
        port map (
            clk          => clk,
            reset_n      => reset_n,
            ecg_sample   => ecg_sample_in,
            sample_valid => sample_valid_in,
            class_result => class_result_int,
            result_valid => result_valid_int,
            sdram_addr      => sdram_addr,
            sdram_data_in   => sdram_data_in,
            sdram_data_out  => sdram_data_out,
            sdram_read_req  => sdram_read_req,
            sdram_write_req => sdram_write_req,
            sdram_data_valid => sdram_data_valid,
            sdram_busy => sdram_busy
        );

    --------------------------------------------------------------------------------
    -- Map CNN outputs to top-level interface
    --------------------------------------------------------------------------------

    -- Passthrough ECG sample for debugging/monitoring
    cnn_sample <= ecg_sample_in;
    cnn_valid  <= sample_valid_in;

    -- Map 3-bit classification (0-7) to 2-bit display format
    -- cnn_result[1:0] encoding:
    --   00 = Normal (class 0)
    --   01 = PVC/Abnormal (classes 1-3)
    --   10 = AFib/Other (classes 4-6)
    --   11 = Unknown (class 7)
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            cnn_result <= "00";
            cnn_result_valid <= '0';

        elsif rising_edge(clk) then

            cnn_result_valid <= result_valid_int;

            if result_valid_int = '1' then
                case class_result_int is
                    when "000" =>
                        cnn_result <= "00";  -- Normal
                    when "001" | "010" | "011" =>
                        cnn_result <= "01";  -- PVC/Abnormal
                    when "100" | "101" | "110" =>
                        cnn_result <= "10";  -- AFib/Other abnormal
                    when "111" =>
                        cnn_result <= "11";  -- Unknown
                    when others =>
                        cnn_result <= "11";
                end case;
            end if;

        end if;
    end process;

end Behavioral;
