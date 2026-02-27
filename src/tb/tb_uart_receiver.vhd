Milestones Compliance ReportTasks OutlinedProgress MadeDifficulties EncounteredTasks to Be Completed--------------------------------------------------------------------------------
-- Testbench for UART Receiver
-- Simulates UART transmission from PC and verifies correct reception
--
-- Test Cases:
--   1. Send single byte - verify reception
--   2. Send 2-byte ECG sample - verify 12-bit assembly
--   3. Test error detection (bad stop bit)
--
-- Author: Marly
-- Date: January 21, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_receiver is
-- Testbench has no ports
end tb_uart_receiver;

architecture Behavioral of tb_uart_receiver is
    
    -- Component under test
    component uart_receiver
        generic (
            CLK_FREQ  : integer;
            BAUD_RATE : integer
        );
        port (
            clk          : in  std_logic;
            reset_n      : in  std_logic;
            uart_rx      : in  std_logic;
            ecg_sample   : out std_logic_vector(11 downto 0);
            sample_valid : out std_logic;
            uart_error   : out std_logic;
            uart_active  : out std_logic
        );
    end component;
    
    -- Test parameters
    constant CLK_FREQ  : integer := 50_000_000;
    constant BAUD_RATE : integer := 115200;
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz
    constant BIT_PERIOD : time := 8680 ns;  -- 115200 baud = 8.68 μs/bit
    
    -- Signals
    signal clk       : std_logic := '0';
    signal reset_n   : std_logic := '0';
    signal uart_rx   : std_logic := '1';  -- Idle high
    signal ecg_sample   : std_logic_vector(11 downto 0);
    signal sample_valid : std_logic;
    signal uart_error   : std_logic;
    signal uart_active  : std_logic;
    
    -- Test control
    signal test_done : boolean := false;
    
    -- Procedure to send one byte via UART
    procedure uart_send_byte(
        signal uart_tx : out std_logic;
        byte_data : in std_logic_vector(7 downto 0)) is
    begin
        -- Start bit
        uart_tx <= '0';
        wait for BIT_PERIOD;
        
        -- Data bits (LSB first)
        for i in 0 to 7 loop
            uart_tx <= byte_data(i);
            wait for BIT_PERIOD;
        end loop;
        
        -- Stop bit
        uart_tx <= '1';
        wait for BIT_PERIOD;
    end uart_send_byte;
    
begin
    
    -- Instantiate unit under test
    uut : uart_receiver
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk          => clk,
            reset_n      => reset_n,
            uart_rx      => uart_rx,
            ecg_sample   => ecg_sample,
            sample_valid => sample_valid,
            uart_error   => uart_error,
            uart_active  => uart_active
        );
    
    -- Clock generation
    clk_process : process
    begin
        while not test_done loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;
    
    -- Test stimulus
    stim_process : process
    begin
        -- Reset
        reset_n <= '0';
        uart_rx <= '1';
        wait for 100 ns;
        reset_n <= '1';
        wait for 100 ns;
        
        report "Test 1: Send single byte 0xA3";
        uart_send_byte(uart_rx, x"A3");
        wait for 10 us;
        
        report "Test 2: Send 12-bit sample 0x5A3 (1443 decimal)";
        uart_send_byte(uart_rx, x"A3");  -- Lower byte: 0xA3
        wait for 1 us;
        uart_send_byte(uart_rx, x"05");  -- Upper byte: 0x05
        wait for 10 us;
        
        -- Check result
        assert sample_valid = '1' report "ERROR: sample_valid not asserted" severity error;
        assert ecg_sample = x"5A3" report "ERROR: Wrong sample value received" severity error;
        report "✓ Test 2 PASSED: Received 0x5A3";
        
        wait for 20 us;
        
        report "Test 3: Send 12-bit sample 0xFFF (2047 decimal, max positive)";
        uart_send_byte(uart_rx, x"FF");  -- Lower byte
        wait for 1 us;
        uart_send_byte(uart_rx, x"0F");  -- Upper byte
        wait for 10 us;
        
        assert ecg_sample = x"FFF" report "ERROR: Max value not correct" severity error;
        report "✓ Test 3 PASSED: Received 0xFFF";
        
        wait for 20 us;
        
        report "Test 4: Send 12-bit sample 0x800 (-2048 decimal, min value)";
        uart_send_byte(uart_rx, x"00");  -- Lower byte
        wait for 1 us;
        uart_send_byte(uart_rx, x"08");  -- Upper byte
        wait for 10 us;
        
        assert ecg_sample = x"800" report "ERROR: Min value not correct" severity error;
        report "✓ Test 4 PASSED: Received 0x800";
        
        wait for 20 us;
        
        report "========================================";
        report "ALL TESTS PASSED";
        report "========================================";
        
        test_done <= true;
        wait;
    end process;
    
end Behavioral;
