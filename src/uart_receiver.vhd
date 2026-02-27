--------------------------------------------------------------------------------
-- UART Receiver Module
-- Receives 12-bit ECG samples from PC via UART (115200 baud)
--
-- Data Format: 2 bytes per sample
--   Byte 1: ecg_sample[7:0]  (lower 8 bits)
--   Byte 2: 0000 + ecg_sample[11:8]  (upper 4 bits + padding)
--
-- Author: Marly
-- Date: January 21, 2026
-- Version: 1.0
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_receiver is
    generic (
        CLK_FREQ  : integer := 50_000_000;   -- 50 MHz system clock
        BAUD_RATE : integer := 115200        -- UART baud rate
    );
    port (
        clk          : in  std_logic;
        reset_n      : in  std_logic;
        
        -- UART input
        uart_rx      : in  std_logic;
        
        -- ECG output (12-bit samples)
        ecg_sample   : out std_logic_vector(11 downto 0);
        sample_valid : out std_logic;        -- Pulses high when new sample ready
        
        -- Status/debugging
        uart_error   : out std_logic;        -- Frame error
        uart_active  : out std_logic         -- Currently receiving
    );
end uart_receiver;

architecture Behavioral of uart_receiver is
    
    -- UART timing constants
    constant CLKS_PER_BIT : integer := CLK_FREQ / BAUD_RATE;  -- ~434 for 115200
    constant SAMPLE_POINT : integer := CLKS_PER_BIT / 2;       -- Middle of bit
    
    -- UART receiver state machine
    type uart_state_type is (IDLE, START_BIT, DATA_BITS, STOP_BIT);
    signal uart_state : uart_state_type := IDLE;
    
    -- UART signals
    signal rx_data       : std_logic_vector(7 downto 0) := (others => '0');
    signal bit_index     : integer range 0 to 7 := 0;
    signal clk_count     : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal byte_received : std_logic := '0';
    
    -- Multi-byte assembly
    type byte_state_type is (WAIT_BYTE1, WAIT_BYTE2);
    signal byte_state    : byte_state_type := WAIT_BYTE1;
    signal byte1_data    : std_logic_vector(7 downto 0) := (others => '0');
    signal byte2_data    : std_logic_vector(7 downto 0) := (others => '0');
    
    -- Output signals
    signal ecg_sample_int   : std_logic_vector(11 downto 0) := (others => '0');
    signal sample_valid_int : std_logic := '0';
    signal uart_error_int   : std_logic := '0';
    signal uart_active_int  : std_logic := '0';
    
begin
    
    -- UART Receiver Process
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            uart_state <= IDLE;
            bit_index <= 0;
            clk_count <= 0;
            rx_data <= (others => '0');
            byte_received <= '0';
            uart_error_int <= '0';
            uart_active_int <= '0';
            
        elsif rising_edge(clk) then
            byte_received <= '0';  -- Default: no byte received
            uart_error_int <= '0'; -- Clear error each cycle
            
            case uart_state is
                
                when IDLE =>
                    clk_count <= 0;
                    bit_index <= 0;
                    uart_active_int <= '0';
                    
                    -- Detect start bit (falling edge of RX)
                    if uart_rx = '0' then
                        uart_state <= START_BIT;
                        uart_active_int <= '1';
                    end if;
                    
                when START_BIT =>
                    uart_active_int <= '1';
                    
                    if clk_count < CLKS_PER_BIT-1 then
                        clk_count <= clk_count + 1;
                    else
                        clk_count <= 0;
                        
                        -- Verify start bit is still low at midpoint
                        if uart_rx = '0' then
                            uart_state <= DATA_BITS;
                        else
                            uart_state <= IDLE;  -- False start
                            uart_error_int <= '1';
                        end if;
                    end if;
                    
                when DATA_BITS =>
                    uart_active_int <= '1';
                    
                    if clk_count < CLKS_PER_BIT-1 then
                        clk_count <= clk_count + 1;
                    else
                        clk_count <= 0;
                        
                        -- Sample data bit at midpoint
                        rx_data(bit_index) <= uart_rx;
                        
                        -- Move to next bit or stop bit
                        if bit_index < 7 then
                            bit_index <= bit_index + 1;
                        else
                            bit_index <= 0;
                            uart_state <= STOP_BIT;
                        end if;
                    end if;
                    
                when STOP_BIT =>
                    uart_active_int <= '1';
                    
                    if clk_count < CLKS_PER_BIT-1 then
                        clk_count <= clk_count + 1;
                    else
                        clk_count <= 0;
                        
                        -- Check stop bit is high
                        if uart_rx = '1' then
                            byte_received <= '1';  -- Valid byte received
                        else
                            uart_error_int <= '1'; -- Frame error
                        end if;
                        
                        uart_state <= IDLE;
                    end if;
                    
            end case;
        end if;
    end process;
    
    -- Multi-byte assembly process (2 bytes → 12-bit sample)
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            byte_state <= WAIT_BYTE1;
            byte1_data <= (others => '0');
            byte2_data <= (others => '0');
            sample_valid_int <= '0';
            ecg_sample_int <= (others => '0');
            
        elsif rising_edge(clk) then
            sample_valid_int <= '0';  -- Default: no new sample
            
            if byte_received = '1' then
                
                case byte_state is
                    
                    when WAIT_BYTE1 =>
                        -- Receive first byte (lower 8 bits)
                        byte1_data <= rx_data;
                        byte_state <= WAIT_BYTE2;
                        
                    when WAIT_BYTE2 =>
                        -- Receive second byte (upper 4 bits)
                        byte2_data <= rx_data;
                        
                        -- Assemble 12-bit sample
                        ecg_sample_int <= rx_data(3 downto 0) & byte1_data;
                        
                        -- Signal new sample is ready
                        sample_valid_int <= '1';
                        
                        -- Back to waiting for next sample
                        byte_state <= WAIT_BYTE1;
                        
                end case;
            end if;
        end if;
    end process;
    
    -- Output assignments
    ecg_sample   <= ecg_sample_int;
    sample_valid <= sample_valid_int;
    uart_error   <= uart_error_int;
    uart_active  <= uart_active_int;
    
end Behavioral;
