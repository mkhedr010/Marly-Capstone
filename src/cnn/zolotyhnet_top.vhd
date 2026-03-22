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

    type cnn_state_type is (
        IDLE,
        LINEAR1, LINEAR2, LINEAR3, CLASSIFIER,
        ARGMAX, OUTPUT_RESULT
    );

    --------------------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------------------

    signal cnn_state : cnn_state_type := IDLE;

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
    linear0_weight_rom : weight_rom
        generic map (
            DATA_WIDTH => 16,
            ADDR_WIDTH => 13,
            INIT_FILE  => "weights/linear0_weight.mif"
        )
        port map (
            clk    => clk,
            addr_a => linear1_weight_addr,
            data_a => linear0_weight_data,
            addr_b => 0,
            data_b => open
        );

    -- Bias vector: 64 entries → ADDR_WIDTH=6 (2^6=64) → 1 M4K
    linear0_bias_rom : weight_rom
        generic map (
            DATA_WIDTH => 16,
            ADDR_WIDTH => 6,
            INIT_FILE  => "weights/linear0_bias.mif"
        )
        port map (
            clk    => clk,
            addr_a => linear1_bias_addr,
            data_a => linear0_bias_data,
            addr_b => 0,
            data_b => open
        );

    -- LINEAR1: 64→16
    -- Weight matrix: 64×16 = 1,024 entries → ADDR_WIDTH=10 (2^10=1024) → 4 M4K
    linear1_weight_rom : weight_rom
        generic map (
            DATA_WIDTH => 16,
            ADDR_WIDTH => 10,
            INIT_FILE  => "weights/linear1_weight.mif"
        )
        port map (
            clk    => clk,
            addr_a => linear2_weight_addr,
            data_a => linear1_weight_data,
            addr_b => 0,
            data_b => open
        );

    -- Bias vector: 16 entries → ADDR_WIDTH=4 (2^4=16) → 1 M4K
    linear1_bias_rom : weight_rom
        generic map (
            DATA_WIDTH => 16,
            ADDR_WIDTH => 4,
            INIT_FILE  => "weights/linear1_bias.mif"
        )
        port map (
            clk    => clk,
            addr_a => linear2_bias_addr,
            data_a => linear1_bias_data,
            addr_b => 0,
            data_b => open
        );

    -- LINEAR2: 16→8
    -- Weight matrix: 16×8 = 128 entries → ADDR_WIDTH=7 (2^7=128) → 1 M4K
    linear2_weight_rom : weight_rom
        generic map (
            DATA_WIDTH => 16,
            ADDR_WIDTH => 7,
            INIT_FILE  => "weights/linear2_weight.mif"
        )
        port map (
            clk    => clk,
            addr_a => linear3_weight_addr,
            data_a => linear2_weight_data,
            addr_b => 0,
            data_b => open
        );

    -- Bias vector: 8 entries → ADDR_WIDTH=3 (2^3=8) → 1 M4K
    linear2_bias_rom : weight_rom
        generic map (
            DATA_WIDTH => 16,
            ADDR_WIDTH => 3,
            INIT_FILE  => "weights/linear2_bias.mif"
        )
        port map (
            clk    => clk,
            addr_a => linear3_bias_addr,
            data_a => linear2_bias_data,
            addr_b => 0,
            data_b => open
        );

    -- CLASSIFIER: 8→8
    -- Weight matrix: 8×8 = 64 entries → ADDR_WIDTH=6 (2^6=64) → 1 M4K
    classifier_weight_rom : weight_rom
        generic map (
            DATA_WIDTH => 16,
            ADDR_WIDTH => 6,
            INIT_FILE  => "weights/classifier_weight.mif"
        )
        port map (
            clk    => clk,
            addr_a => classifier_weight_addr,
            data_a => classifier_weight_data,
            addr_b => 0,
            data_b => open
        );

    -- Bias vector: 8 entries → ADDR_WIDTH=3 (2^3=8) → 1 M4K
    classifier_bias_rom : weight_rom
        generic map (
            DATA_WIDTH => 16,
            ADDR_WIDTH => 3,
            INIT_FILE  => "weights/classifier_bias.mif"
        )
        port map (
            clk    => clk,
            addr_a => classifier_bias_addr,
            data_a => classifier_bias_data,
            addr_b => 0,
            data_b => open
        );

    -- TOTAL ROM M4K: 32+1+4+1+1+1+1+1 = 42 blocks ✓

    --------------------------------------------------------------------------------
    -- Layer Buffer Instances
    --------------------------------------------------------------------------------

    linear1_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 64)
        port map (
            clk     => clk,
            wr_addr => linear1_output_addr,
            wr_data => linear1_output_data,
            wr_en   => linear1_output_we,
            rd_addr => linear2_input_addr,
            rd_data => linear2_input_data
        );

    linear2_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 16)
        port map (
            clk     => clk,
            wr_addr => linear2_output_addr,
            wr_data => linear2_output_data,
            wr_en   => linear2_output_we,
            rd_addr => linear3_input_addr,
            rd_data => linear3_input_data
        );

    --------------------------------------------------------------------------------
    -- LINEAR Engine Instances
    --------------------------------------------------------------------------------

    linear1_inst : linear_engine
        generic map (
            DATA_WIDTH      => 16,
            INPUT_FEATURES  => 128,
            OUTPUT_FEATURES => 64
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => linear1_start,
            weight_data => linear0_weight_data,
            weight_addr => linear1_weight_addr,
            bias_data   => linear0_bias_data,
            bias_addr   => linear1_bias_addr,
            input_data  => buf_rd_data,
            input_addr  => linear1_input_addr,
            output_data => linear1_output_data,
            output_addr => linear1_output_addr,
            output_we   => linear1_output_we,
            done        => linear1_done
        );

    linear2_inst : linear_engine
        generic map (
            DATA_WIDTH      => 16,
            INPUT_FEATURES  => 64,
            OUTPUT_FEATURES => 16
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => linear2_start,
            weight_data => linear1_weight_data,
            weight_addr => linear2_weight_addr,
            bias_data   => linear1_bias_data,
            bias_addr   => linear2_bias_addr,
            input_data  => linear2_input_data,
            input_addr  => linear2_input_addr,
            output_data => linear2_output_data,
            output_addr => linear2_output_addr,
            output_we   => linear2_output_we,
            done        => linear2_done
        );

    linear3_inst : linear_engine
        generic map (
            DATA_WIDTH      => 16,
            INPUT_FEATURES  => 16,
            OUTPUT_FEATURES => 8
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => linear3_start,
            weight_data => linear2_weight_data,
            weight_addr => linear3_weight_addr,
            bias_data   => linear2_bias_data,
            bias_addr   => linear3_bias_addr,
            input_data  => linear3_input_data,
            input_addr  => linear3_input_addr,
            output_data => linear3_output_data,
            output_addr => linear3_output_addr,
            output_we   => linear3_output_we,
            done        => linear3_done
        );

    classifier_inst : linear_engine
        generic map (
            DATA_WIDTH      => 16,
            INPUT_FEATURES  => 8,
            OUTPUT_FEATURES => 8
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => classifier_start,
            weight_data => classifier_weight_data,
            weight_addr => classifier_weight_addr,
            bias_data   => classifier_bias_data,
            bias_addr   => classifier_bias_addr,
            input_data  => classifier_input_data,
            input_addr  => classifier_input_addr,
            output_data => classifier_output_data,
            output_addr => classifier_output_addr,
            output_we   => classifier_output_we,
            done        => classifier_done
        );

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
    -- Main CNN State Machine
    --------------------------------------------------------------------------------
    process(clk, reset_n)
        variable max_score : signed(15 downto 0);
        variable max_index : integer range 0 to 7;
    begin
        if reset_n = '0' then
            cnn_state    <= IDLE;
            result_valid <= '0';
            layer_counter <= 0;

        elsif rising_edge(clk) then

            result_valid     <= '0';
            linear1_start    <= '0';
            linear2_start    <= '0';
            linear3_start    <= '0';
            classifier_start <= '0';

            case cnn_state is

                when IDLE =>
                    if buffer_ready = '1' then
                        cnn_state     <= LINEAR1;
                        layer_counter <= 0;
                        linear1_start <= '1';
                    end if;

                when LINEAR1 =>
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 10000 or linear1_done = '1' then
                        cnn_state     <= LINEAR2;
                        layer_counter <= 0;
                        linear2_start <= '1';
                    end if;

                when LINEAR2 =>
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 1500 or linear2_done = '1' then
                        cnn_state     <= LINEAR3;
                        layer_counter <= 0;
                        linear3_start <= '1';
                    end if;

                when LINEAR3 =>
                    layer_counter <= layer_counter + 1;
                    -- Collect 8 outputs from LINEAR3
                    if linear3_output_we = '1' and linear3_output_addr < 8 then
                        linear3_final(linear3_output_addr) <= linear3_output_data;
                    end if;

                    if layer_counter > 200 or linear3_done = '1' then
                        cnn_state        <= CLASSIFIER;
                        layer_counter    <= 0;
                        classifier_start <= '1';
                    end if;

                when CLASSIFIER =>
                    layer_counter <= layer_counter + 1;
                    -- Collect 8 class scores
                    if classifier_output_we = '1' and classifier_output_addr < 8 then
                        class_scores(classifier_output_addr) <= classifier_output_data;
                    end if;

                    if layer_counter > 100 or classifier_done = '1' then
                        cnn_state     <= ARGMAX;
                        layer_counter <= 0;
                    end if;

                when ARGMAX =>
                    -- Find argmax
                    max_score := class_scores(0);
                    max_index := 0;

                    for i in 1 to 7 loop
                        if class_scores(i) > max_score then
                            max_score := class_scores(i);
                            max_index := i;
                        end if;
                    end loop;

                    class_result <= std_logic_vector(to_unsigned(max_index, 3));
                    cnn_state    <= OUTPUT_RESULT;

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

    buf_rd_addr          <= linear1_input_addr when cnn_state = LINEAR1 else 0;
    classifier_input_data <= linear3_final(classifier_input_addr)
                             when classifier_input_addr < 8
                             else (others => '0');

end Behavioral;
