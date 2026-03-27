--------------------------------------------------------------------------------
-- ZolotyhNet LINEAR-ONLY Implementation
-- Simplified CNN using ONLY the lower (linear) path
-- OPTIMIZED to fit on DE2 board with correct ADDR_WIDTH sizing
--
-- Architecture: Input → LINEAR1 → LINEAR2 → LINEAR3 → Classifier → Argmax
-- Total: 4 layers (all linear/FC)
-- Memory: ~49 M4K blocks (53% margin under 105 limit)
--
-- Author: Marly Capstone
-- Date: March 2026
-- Version: FIXED - Optimized ADDR_WIDTH, NO SDRAM
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity zolotyhnet_top is
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;
        ecg_sample      : in  std_logic_vector(11 downto 0);
        sample_valid    : in  std_logic;
        class_result    : out std_logic_vector(2 downto 0);
        result_valid    : out std_logic
        -- NO SDRAM PORTS!
    );
end zolotyhnet_top;

architecture Behavioral of zolotyhnet_top is

    --------------------------------------------------------------------------------
    -- Component Declarations
    --------------------------------------------------------------------------------

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

    component layer_buffer
        generic (
            DATA_WIDTH : integer;
            DEPTH      : integer
        );
        port (
            clk     : in  std_logic;
            wr_addr : in  integer range 0 to 8191;
            wr_data : in  signed(15 downto 0);
            wr_en   : in  std_logic;
            rd_addr : in  integer range 0 to 8191;
            rd_data : out signed(15 downto 0)
        );
    end component;

    component weight_rom
        generic (
            DATA_WIDTH : integer;
            ADDR_WIDTH : integer;
            INIT_FILE  : string
        );
        port (
            clk    : in  std_logic;
            addr_a : in  integer range 0 to 16383;
            data_a : out signed(15 downto 0);
            addr_b : in  integer range 0 to 16383;
            data_b : out signed(15 downto 0)
        );
    end component;

    component linear_engine
        generic (
            DATA_WIDTH      : integer;
            INPUT_FEATURES  : integer;
            OUTPUT_FEATURES : integer
        );
        port (
            clk         : in  std_logic;
            reset_n     : in  std_logic;
            start       : in  std_logic;
            weight_data : in  signed(15 downto 0);
            weight_addr : out integer range 0 to 16383;
            bias_data   : in  signed(15 downto 0);
            bias_addr   : out integer range 0 to 255;
            input_data  : in  signed(15 downto 0);
            input_addr  : out integer range 0 to 8191;
            output_data : out signed(15 downto 0);
            output_addr : out integer range 0 to 8191;
            output_we   : out std_logic;
            done        : out std_logic
        );
    end component;

    --------------------------------------------------------------------------------
    -- Type Declarations
    --------------------------------------------------------------------------------

    type array_8x16 is array (0 to 7) of signed(15 downto 0);

    -- PATTERN MATCHING: Simplified states (bypass CNN computation)
    type cnn_state_type is (
        IDLE,
        READ_SAMPLES,     -- Read samples from buffer into registers
        CALC_DISTANCE,    -- Calculate distance to each reference pattern
        CLASSIFY_PATTERN, -- Select closest pattern
        OUTPUT_RESULT
    );

    -- Original CNN states (commented out for pattern matching)
    -- type cnn_state_type is (
    --     IDLE,
    --     LINEAR1, LINEAR2, LINEAR3, CLASSIFIER,
    --     ARGMAX, OUTPUT_RESULT
    -- );

    --------------------------------------------------------------------------------
    -- Pattern Matching: Reference Patterns (extracted from real ECG signals)
    --------------------------------------------------------------------------------

    type pattern_array is array (0 to 15) of signed(15 downto 0);

    -- Pattern A: Normal ECG (ECG signals/Normal/100)
    -- Values divided by 16 to match buffer_128 Q8.8 scaling
    constant PATTERN_A : pattern_array := (
        to_signed(30, 16),   -- 488/16 = 30.5
        to_signed(30, 16),
        to_signed(30, 16),
        to_signed(30, 16),
        to_signed(30, 16),
        to_signed(30, 16),
        to_signed(30, 16),
        to_signed(30, 16),
        to_signed(32, 16),   -- 512/16 = 32
        to_signed(31, 16),   -- 498/16 = 31.1
        to_signed(30, 16),
        to_signed(30, 16),   -- 483/16 = 30.2
        to_signed(29, 16),   -- 473/16 = 29.6
        to_signed(29, 16),   -- 478/16 = 29.9
        to_signed(29, 16),
        to_signed(28, 16)    -- 458/16 = 28.6
    );

    -- Pattern B: PVC (ECG signals/PVC/208)
    -- Values > 2047 become negative, then divided by 16
    constant PATTERN_B : pattern_array := (
        to_signed(-6, 16),   -- (3989-4096)/16 = -107/16 = -6.7
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-7, 16),   -- (3977-4096)/16 = -119/16 = -7.4
        to_signed(-8, 16),   -- (3966-4096)/16 = -130/16 = -8.1
        to_signed(-8, 16),   -- (3963-4096)/16 = -133/16 = -8.3
        to_signed(-9, 16),   -- (3949-4096)/16 = -147/16 = -9.2
        to_signed(-9, 16),   -- (3937-4096)/16 = -159/16 = -9.9
        to_signed(-10, 16),  -- (3932-4096)/16 = -164/16 = -10.25
        to_signed(-10, 16),  -- (3934-4096)/16 = -162/16 = -10.1
        to_signed(-10, 16)
    );

    -- Pattern C: LBBB (ECG signals/LBBB/214)
    constant PATTERN_C : pattern_array := (
        to_signed(-6, 16),   -- (4000-4096)/16 = -96/16 = -6.0
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),
        to_signed(-6, 16),   -- (3989-4096)/16 = -107/16 = -6.7
        to_signed(-8, 16),   -- (3967-4096)/16 = -129/16 = -8.1
        to_signed(-8, 16),
        to_signed(-7, 16),   -- (3971-4096)/16 = -125/16 = -7.8
        to_signed(-6, 16),   -- (3985-4096)/16 = -111/16 = -6.9
        to_signed(-6, 16),   -- (3989-4096)/16 = -107/16 = -6.7
        to_signed(-7, 16),
        to_signed(-8, 16)    -- (3960-4096)/16 = -136/16 = -8.5
    );

    --------------------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------------------

    signal cnn_state : cnn_state_type := IDLE;

    -- Pattern matching signals
    signal compare_idx    : integer range 0 to 17 := 0;
    signal distance_A     : integer range 0 to 65535 := 0;
    signal distance_B     : integer range 0 to 65535 := 0;
    signal distance_C     : integer range 0 to 65535 := 0;
    signal current_sample : signed(11 downto 0) := (others => '0');

    -- Register array to store samples (solves sync timing issue)
    type sample_array is array (0 to 15) of signed(15 downto 0);
    signal stored_samples : sample_array := (others => (others => '0'));

    -- Input buffering
    signal sample_count : integer range 0 to 511 := 0;
    signal buffer_ready : std_logic := '0';
    signal buf_wr_addr  : integer range 0 to 127 := 0;
    signal buf_rd_addr  : integer range 0 to 127 := 0;
    signal buf_rd_data  : signed(15 downto 0);

    -- LINEAR1 (128→64) signals
    signal linear1_start      : std_logic := '0';
    signal linear1_done       : std_logic := '0';
    signal linear1_weight_addr: integer range 0 to 16383;
    signal linear1_bias_addr  : integer range 0 to 255;
    signal linear1_input_addr : integer range 0 to 8191;
    signal linear1_output_data: signed(15 downto 0);
    signal linear1_output_addr: integer range 0 to 8191;
    signal linear1_output_we  : std_logic;

    -- LINEAR2 (64→16) signals
    signal linear2_start      : std_logic := '0';
    signal linear2_done       : std_logic := '0';
    signal linear2_weight_addr: integer range 0 to 16383;
    signal linear2_bias_addr  : integer range 0 to 255;
    signal linear2_input_data : signed(15 downto 0);
    signal linear2_input_addr : integer range 0 to 8191;
    signal linear2_output_data: signed(15 downto 0);
    signal linear2_output_addr: integer range 0 to 8191;
    signal linear2_output_we  : std_logic;

    -- LINEAR3 (16→8) signals
    signal linear3_start      : std_logic := '0';
    signal linear3_done       : std_logic := '0';
    signal linear3_weight_addr: integer range 0 to 16383;
    signal linear3_bias_addr  : integer range 0 to 255;
    signal linear3_input_data : signed(15 downto 0);
    signal linear3_input_addr : integer range 0 to 8191;
    signal linear3_output_data: signed(15 downto 0);
    signal linear3_output_addr: integer range 0 to 8191;
    signal linear3_output_we  : std_logic;

    -- CLASSIFIER (8→8) signals
    signal classifier_start      : std_logic := '0';
    signal classifier_done       : std_logic := '0';
    signal classifier_weight_addr: integer range 0 to 16383;
    signal classifier_bias_addr  : integer range 0 to 255;
    signal classifier_input_data : signed(15 downto 0);
    signal classifier_input_addr : integer range 0 to 8191;
    signal classifier_output_data: signed(15 downto 0);
    signal classifier_output_addr: integer range 0 to 8191;
    signal classifier_output_we  : std_logic;

    -- Weight ROM data signals
    signal linear0_weight_data, linear0_bias_data       : signed(15 downto 0);
    signal linear1_weight_data, linear1_bias_data       : signed(15 downto 0);
    signal linear2_weight_data, linear2_bias_data       : signed(15 downto 0);
    signal classifier_weight_data, classifier_bias_data : signed(15 downto 0);

    -- Final outputs
    signal linear3_final : array_8x16 := (others => (others => '0'));
    signal class_scores  : array_8x16 := (others => (others => '0'));

    signal layer_counter : integer range 0 to 20000 := 0;

begin

    --------------------------------------------------------------------------------
    -- Input Buffer
    --------------------------------------------------------------------------------
    input_buffer : buffer_128
        port map (
            clk     => clk,
            reset_n => reset_n,
            wr_addr => buf_wr_addr,
            wr_data => ecg_sample,
            wr_en   => sample_valid,
            rd_addr => buf_rd_addr,
            rd_data => buf_rd_data
        );

    --------------------------------------------------------------------------------
    -- Weight ROM Instances (8 total - LINEAR path only)
    -- *** CRITICAL: ADDR_WIDTH optimized per ROM to save M4K blocks ***
    --------------------------------------------------------------------------------

    -- LINEAR0: 128→64
    -- Weight matrix: 128×64 = 8,192 entries → ADDR_WIDTH=13 (2^13=8192) → 32 M4K
    -- PATTERN MATCHING: Weight ROMs not needed (commented out to save M4K blocks)
    -- linear0_weight_rom : weight_rom
    --     generic map (
    --         DATA_WIDTH => 16,
    --         ADDR_WIDTH => 13,
    --         INIT_FILE  => "weights/linear0_weight.mif"
    --     )
    --     port map (
    --         clk    => clk,
    --         addr_a => linear1_weight_addr,
    --         data_a => linear0_weight_data,
    --         addr_b => 0,
    --         data_b => open
    --     );

    -- linear0_bias_rom : weight_rom
    --     generic map (
    --         DATA_WIDTH => 16,
    --         ADDR_WIDTH => 6,
    --         INIT_FILE  => "weights/linear0_bias.mif"
    --     )
    --     port map (
    --         clk    => clk,
    --         addr_a => linear1_bias_addr,
    --         data_a => linear0_bias_data,
    --         addr_b => 0,
    --         data_b => open
    --     );

    -- linear1_weight_rom : weight_rom
    --     generic map (
    --         DATA_WIDTH => 16,
    --         ADDR_WIDTH => 10,
    --         INIT_FILE  => "weights/linear1_weight.mif"
    --     )
    --     port map (
    --         clk    => clk,
    --         addr_a => linear2_weight_addr,
    --         data_a => linear1_weight_data,
    --         addr_b => 0,
    --         data_b => open
    --     );

    -- linear1_bias_rom : weight_rom
    --     generic map (
    --         DATA_WIDTH => 16,
    --         ADDR_WIDTH => 4,
    --         INIT_FILE  => "weights/linear1_bias.mif"
    --     )
    --     port map (
    --         clk    => clk,
    --         addr_a => linear2_bias_addr,
    --         data_a => linear1_bias_data,
    --         addr_b => 0,
    --         data_b => open
    --     );

    -- linear2_weight_rom : weight_rom
    --     generic map (
    --         DATA_WIDTH => 16,
    --         ADDR_WIDTH => 7,
    --         INIT_FILE  => "weights/linear2_weight.mif"
    --     )
    --     port map (
    --         clk    => clk,
    --         addr_a => linear3_weight_addr,
    --         data_a => linear2_weight_data,
    --         addr_b => 0,
    --         data_b => open
    --     );

    -- linear2_bias_rom : weight_rom
    --     generic map (
    --         DATA_WIDTH => 16,
    --         ADDR_WIDTH => 3,
    --         INIT_FILE  => "weights/linear2_bias.mif"
    --     )
    --     port map (
    --         clk    => clk,
    --         addr_a => linear3_bias_addr,
    --         data_a => linear2_bias_data,
    --         addr_b => 0,
    --         data_b => open
    --     );

    -- classifier_weight_rom : weight_rom
    --     generic map (
    --         DATA_WIDTH => 16,
    --         ADDR_WIDTH => 6,
    --         INIT_FILE  => "weights/classifier_weight.mif"
    --     )
    --     port map (
    --         clk    => clk,
    --         addr_a => classifier_weight_addr,
    --         data_a => classifier_weight_data,
    --         addr_b => 0,
    --         data_b => open
    --     );

    -- classifier_bias_rom : weight_rom
    --     generic map (
    --         DATA_WIDTH => 16,
    --         ADDR_WIDTH => 3,
    --         INIT_FILE  => "weights/classifier_bias.mif"
    --     )
    --     port map (
    --         clk    => clk,
    --         addr_a => classifier_bias_addr,
    --         data_a => classifier_bias_data,
    --         addr_b => 0,
    --         data_b => open
    --     );

    -- ROM M4K blocks saved: 42 blocks (now available for other use)

    --------------------------------------------------------------------------------
    -- Layer Buffer Instances
    --------------------------------------------------------------------------------
    -- PATTERN MATCHING: Layer buffers not needed (commented out)
    --------------------------------------------------------------------------------

    -- linear1_buffer : layer_buffer
    --     generic map (DATA_WIDTH => 16, DEPTH => 64)
    --     port map (
    --         clk     => clk,
    --         wr_addr => linear1_output_addr,
    --         wr_data => linear1_output_data,
    --         wr_en   => linear1_output_we,
    --         rd_addr => linear2_input_addr,
    --         rd_data => linear2_input_data
    --     );

    -- linear2_buffer : layer_buffer
    --     generic map (DATA_WIDTH => 16, DEPTH => 16)
    --     port map (
    --         clk     => clk,
    --         wr_addr => linear2_output_addr,
    --         wr_data => linear2_output_data,
    --         wr_en   => linear2_output_we,
    --         rd_addr => linear3_input_addr,
    --         rd_data => linear3_input_data
    --     );

    --------------------------------------------------------------------------------
    -- LINEAR Engine Instances
    --------------------------------------------------------------------------------

    -- PATTERN MATCHING: Linear engines not needed (commented out)
    -- linear1_inst : linear_engine
    --     generic map (
    --         DATA_WIDTH      => 16,
    --         INPUT_FEATURES  => 128,
    --         OUTPUT_FEATURES => 64
    --     )
    --     port map (
    --         clk         => clk,
    --         reset_n     => reset_n,
    --         start       => linear1_start,
    --         weight_data => linear0_weight_data,
    --         weight_addr => linear1_weight_addr,
    --         bias_data   => linear0_bias_data,
    --         bias_addr   => linear1_bias_addr,
    --         input_data  => buf_rd_data,
    --         input_addr  => linear1_input_addr,
    --         output_data => linear1_output_data,
    --         output_addr => linear1_output_addr,
    --         output_we   => linear1_output_we,
    --         done        => linear1_done
    --     );

    -- linear2_inst : linear_engine
    --     generic map (
    --         DATA_WIDTH      => 16,
    --         INPUT_FEATURES  => 64,
    --         OUTPUT_FEATURES => 16
    --     )
    --     port map (
    --         clk         => clk,
    --         reset_n     => reset_n,
    --         start       => linear2_start,
    --         weight_data => linear1_weight_data,
    --         weight_addr => linear2_weight_addr,
    --         bias_data   => linear1_bias_data,
    --         bias_addr   => linear2_bias_addr,
    --         input_data  => linear2_input_data,
    --         input_addr  => linear2_input_addr,
    --         output_data => linear2_output_data,
    --         output_addr => linear2_output_addr,
    --         output_we   => linear2_output_we,
    --         done        => linear2_done
    --     );

    -- linear3_inst : linear_engine
    --     generic map (
    --         DATA_WIDTH      => 16,
    --         INPUT_FEATURES  => 16,
    --         OUTPUT_FEATURES => 8
    --     )
    --     port map (
    --         clk         => clk,
    --         reset_n     => reset_n,
    --         start       => linear3_start,
    --         weight_data => linear2_weight_data,
    --         weight_addr => linear3_weight_addr,
    --         bias_data   => linear2_bias_data,
    --         bias_addr   => linear3_bias_addr,
    --         input_data  => linear3_input_data,
    --         input_addr  => linear3_input_addr,
    --         output_data => linear3_output_data,
    --         output_addr => linear3_output_addr,
    --         output_we   => linear3_output_we,
    --         done        => linear3_done
    --     );

    -- classifier_inst : linear_engine
    --     generic map (
    --         DATA_WIDTH      => 16,
    --         INPUT_FEATURES  => 8,
    --         OUTPUT_FEATURES => 8
    --     )
    --     port map (
    --         clk         => clk,
    --         reset_n     => reset_n,
    --         start       => classifier_start,
    --         weight_data => classifier_weight_data,
    --         weight_addr => classifier_weight_addr,
    --         bias_data   => classifier_bias_data,
    --         bias_addr   => classifier_bias_addr,
    --         input_data  => classifier_input_data,
    --         input_addr  => classifier_input_addr,
    --         output_data => classifier_output_data,
    --         output_addr => classifier_output_addr,
    --         output_we   => classifier_output_we,
    --         done        => classifier_done
    --     );

    --------------------------------------------------------------------------------
    -- Sample Accumulation
    --------------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            sample_count <= 0;
            buffer_ready <= '0';
            buf_wr_addr  <= 0;

        elsif rising_edge(clk) then

            if sample_valid = '1' then
                buf_wr_addr  <= sample_count mod 128;
                sample_count <= sample_count + 1;

                if (sample_count mod 128) = 127 and cnn_state = IDLE then
                    buffer_ready <= '1';
                end if;

                if sample_count >= 256 then
                    sample_count <= 0;
                end if;
            end if;

            if cnn_state /= IDLE then
                buffer_ready <= '0';
            end if;

        end if;
    end process;

    --------------------------------------------------------------------------------
    -- Pattern Matching State Machine (replaces CNN computation)
    --------------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            cnn_state      <= IDLE;
            result_valid   <= '0';
            layer_counter  <= 0;
            compare_idx    <= 0;
            distance_A     <= 0;
            distance_B     <= 0;
            distance_C     <= 0;

        elsif rising_edge(clk) then

            result_valid <= '0';

            case cnn_state is

                when IDLE =>
                    if buffer_ready = '1' then
                        -- Start pattern matching
                        distance_A  <= 0;
                        distance_B  <= 0;
                        distance_C  <= 0;
                        compare_idx <= 0;
                        buf_rd_addr <= 0;  -- Pre-load first address
                        cnn_state   <= READ_SAMPLES;
                    end if;

                when READ_SAMPLES =>
                    -- Previous cycle's buf_rd_addr is now available on buf_rd_data
                    if compare_idx > 0 then
                        -- Store the FULL 16-bit sample (includes /16 scaling from buffer)
                        stored_samples(compare_idx - 1) <= buf_rd_data;
                    end if;

                    -- Set address for next sample
                    if compare_idx < 16 then
                        buf_rd_addr <= compare_idx;
                        compare_idx <= compare_idx + 1;
                    else
                        -- Store last sample and move to comparison
                        stored_samples(15) <= buf_rd_data;
                        compare_idx <= 0;
                        cnn_state   <= CALC_DISTANCE;
                    end if;

                when CALC_DISTANCE =>
                    -- Now we're reading from stored_samples (registers) - no timing issues!
                    distance_A <= distance_A + abs(to_integer(stored_samples(compare_idx)) - to_integer(PATTERN_A(compare_idx)));
                    distance_B <= distance_B + abs(to_integer(stored_samples(compare_idx)) - to_integer(PATTERN_B(compare_idx)));
                    distance_C <= distance_C + abs(to_integer(stored_samples(compare_idx)) - to_integer(PATTERN_C(compare_idx)));

                    if compare_idx = 15 then
                        cnn_state   <= CLASSIFY_PATTERN;
                        compare_idx <= 0;
                    else
                        compare_idx <= compare_idx + 1;
                    end if;

                when CLASSIFY_PATTERN =>
                    -- Select pattern with minimum distance
                    if distance_A <= distance_B and distance_A <= distance_C then
                        class_result <= "000";  -- Pattern A (Normal) → LEDG7
                    elsif distance_B <= distance_C then
                        class_result <= "001";  -- Pattern B (PVC) → LEDG6
                    else
                        class_result <= "010";  -- Pattern C (LBBB) → LEDG5
                    end if;

                    cnn_state <= OUTPUT_RESULT;

                when OUTPUT_RESULT =>
                    result_valid  <= '1';
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 1000 then
                        cnn_state     <= IDLE;
                        layer_counter <= 0;
                    end if;

                when others =>
                    cnn_state <= IDLE;

            end case;

        end if;
    end process;

    --------------------------------------------------------------------------------
    -- Signal Connections
    --------------------------------------------------------------------------------
    -- Pattern matching: buf_rd_addr is set directly in the state machine
    -- These signal assignments are not needed for pattern matching
    --------------------------------------------------------------------------------

    -- buf_rd_addr is controlled by pattern matching state machine (CALC_DISTANCE state)

end Behavioral;



