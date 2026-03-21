--------------------------------------------------------------------------------
-- ZolotyhNet Top-Level Module
-- Complete CNN implementation for ECG classification
--
-- Input: 128 ECG samples (12-bit) streamed from UART
-- Output: 8-class classification result
--
-- Architecture: Dual-path (Conv upper + Linear lower) with fusion
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity zolotyhnet_top is
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;

        -- Input interface (from UART via cnn_interface)
        ecg_sample      : in  std_logic_vector(11 downto 0);
        sample_valid    : in  std_logic;

        -- Output interface
        class_result    : out std_logic_vector(2 downto 0);  -- 0-7 classes
        result_valid    : out std_logic
    );
end zolotyhnet_top;

architecture Behavioral of zolotyhnet_top is

    -- Component declarations
    component buffer_128
        port (
            clk     : in  std_logic;
            reset_n : in  std_logic;
            wr_addr : in  integer range 0 to 127;
            wr_data : in  std_logic_vector(11 downto 0);
            wr_en   : in  std_logic;
            rd_addr : in  integer range 0 to 127;
            rd_data : out signed(15 downto 0)
        );
    end component;

    component control_fsm
        port (
            clk          : in  std_logic;
            reset_n      : in  std_logic;
            start        : in  std_logic;
            conv_done    : in  std_logic;
            linear_done  : in  std_logic;
            pool_done    : in  std_logic;
            layer_select : out integer range 0 to 31;
            layer_start  : out std_logic;
            cnn_done     : out std_logic;
            cnn_valid    : out std_logic
        );
    end component;

    -- Signals
    signal sample_count : integer range 0 to 127 := 0;
    signal buffer_full  : std_logic := '0';
    signal processing   : std_logic := '0';

    -- Control FSM signals
    signal fsm_start       : std_logic := '0';
    signal fsm_conv_done   : std_logic := '0';
    signal fsm_linear_done : std_logic := '0';
    signal fsm_pool_done   : std_logic := '0';
    signal fsm_layer       : integer range 0 to 31 := 0;
    signal fsm_layer_start : std_logic := '0';
    signal fsm_cnn_done    : std_logic := '0';
    signal fsm_cnn_valid   : std_logic := '0';

    -- Buffer signals
    signal buf_wr_addr : integer range 0 to 127 := 0;
    signal buf_rd_addr : integer range 0 to 127 := 0;
    signal buf_rd_data : signed(15 downto 0);

    -- Intermediate result storage (simplified - will expand in full implementation)
    type result_array is array (0 to 7) of signed(15 downto 0);
    signal final_output : result_array := (others => (others => '0'));

begin

    --------------------------------------------------------------------------------
    -- Input Sample Buffering
    --------------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            sample_count <= 0;
            buffer_full <= '0';
            buf_wr_addr <= 0;

        elsif rising_edge(clk) then

            -- Accumulate 128 samples
            if sample_valid = '1' and processing = '0' then
                buf_wr_addr <= sample_count;

                if sample_count = 127 then
                    sample_count <= 0;
                    buffer_full <= '1';  -- Trigger CNN processing
                else
                    sample_count <= sample_count + 1;
                end if;
            end if;

            -- Clear buffer_full after processing starts
            if fsm_start = '1' then
                buffer_full <= '0';
            end if;

        end if;
    end process;

    --------------------------------------------------------------------------------
    -- CNN Processing Control
    --------------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            processing <= '0';
            fsm_start <= '0';

        elsif rising_edge(clk) then

            fsm_start <= '0';  -- Pulse

            if buffer_full = '1' and processing = '0' then
                processing <= '1';
                fsm_start <= '1';  -- Start CNN
            end if;

            if fsm_cnn_done = '1' then
                processing <= '0';
            end if;

        end if;
    end process;

    --------------------------------------------------------------------------------
    -- Output Classification Result
    --------------------------------------------------------------------------------
    process(clk, reset_n)
        variable max_idx : integer range 0 to 7 := 0;
        variable max_val : signed(15 downto 0) := (others => '0');
    begin
        if reset_n = '0' then
            class_result <= (others => '0');
            result_valid <= '0';

        elsif rising_edge(clk) then

            result_valid <= '0';

            if fsm_cnn_valid = '1' then
                -- Find argmax of 8 output classes
                max_val := final_output(0);
                max_idx := 0;

                for i in 1 to 7 loop
                    if final_output(i) > max_val then
                        max_val := final_output(i);
                        max_idx := i;
                    end if;
                end loop;

                class_result <= std_logic_vector(to_unsigned(max_idx, 3));
                result_valid <= '1';
            end if;

        end if;
    end process;

    --------------------------------------------------------------------------------
    -- Component Instantiations
    --------------------------------------------------------------------------------

    -- Input buffer
    buf_inst : buffer_128
        port map (
            clk     => clk,
            reset_n => reset_n,
            wr_addr => buf_wr_addr,
            wr_data => ecg_sample,
            wr_en   => sample_valid,
            rd_addr => buf_rd_addr,
            rd_data => buf_rd_data
        );

    -- Control FSM
    fsm_inst : control_fsm
        port map (
            clk          => clk,
            reset_n      => reset_n,
            start        => fsm_start,
            conv_done    => fsm_conv_done,
            linear_done  => fsm_linear_done,
            pool_done    => fsm_pool_done,
            layer_select => fsm_layer,
            layer_start  => fsm_layer_start,
            cnn_done     => fsm_cnn_done,
            cnn_valid    => fsm_cnn_valid
        );

    --------------------------------------------------------------------------------
    -- PLACEHOLDER: Full layer instantiations
    -- TODO: Add conv1d_engine, linear_engine, weight_rom instances
    -- This is simplified version for now - will expand in full implementation
    --------------------------------------------------------------------------------

    -- Temporary: Simulate processing with delay counter
    process(clk, reset_n)
        variable delay_counter : integer range 0 to 100000 := 0;
    begin
        if reset_n = '0' then
            delay_counter := 0;
            fsm_conv_done <= '0';
            fsm_linear_done <= '0';
            fsm_pool_done <= '0';
            final_output <= (others => (others => '0'));

        elsif rising_edge(clk) then

            fsm_conv_done <= '0';
            fsm_linear_done <= '0';
            fsm_pool_done <= '0';

            if fsm_layer_start = '1' then
                delay_counter := 0;
            elsif delay_counter < 1000 then
                delay_counter := delay_counter + 1;
            else
                -- Layer complete
                if fsm_layer <= 8 then
                    -- Conv or pool layer
                    if fsm_layer = 1 or fsm_layer = 3 or fsm_layer = 5 or fsm_layer = 7 then
                        fsm_pool_done <= '1';  -- Pool layers
                    else
                        fsm_conv_done <= '1';  -- Conv layers
                    end if;
                else
                    -- Linear layers
                    fsm_linear_done <= '1';
                end if;

                delay_counter := 0;
            end if;

            -- Dummy classification: class 0 (Normal) for now
            if fsm_cnn_valid = '1' then
                final_output(0) <= to_signed(1000, 16);  -- Highest score
                final_output(1 to 7) <= (others => to_signed(0, 16));
            end if;

        end if;
    end process;

end Behavioral;
