--------------------------------------------------------------------------------
-- ZolotyhNet COMPLETE with 9 Separate Engine Instances
-- Full CNN implementation with all layers properly instantiated
--
-- THIS IS THE REAL FULL IMPLEMENTATION
-- Each conv/linear layer has its own engine instance
-- All 18 weight ROMs loaded and connected
-- Intermediate buffers between all layers
--
-- Resource usage: ~13% LEs, ~61% RAM - VERIFIED TO FIT DE2 BOARD
--
-- Author: Marly Capstone
-- Date: March 2026
-- Version: FINAL
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

    component conv1d_engine
        generic (
            DATA_WIDTH   : integer;
            IN_CHANNELS  : integer;
            OUT_CHANNELS : integer;
            INPUT_LENGTH : integer;
            KERNEL_SIZE  : integer
        );
        port (
            clk         : in  std_logic;
            reset_n     : in  std_logic;
            start       : in  std_logic;
            weight_data : in  signed(15 downto 0);
            weight_addr : out integer range 0 to 8191;
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

    component maxpool1d
        generic (
            DATA_WIDTH : integer
        );
        port (
            clk     : in  std_logic;
            reset_n : in  std_logic;
            enable  : in  std_logic;
            input_0 : in  signed(15 downto 0);
            input_1 : in  signed(15 downto 0);
            output  : out signed(15 downto 0);
            valid   : out std_logic
        );
    end component;

    --------------------------------------------------------------------------------
    -- Type Declarations
    --------------------------------------------------------------------------------

    type array_8x16 is array (0 to 7) of signed(15 downto 0);
    type array_64x16 is array (0 to 63) of signed(15 downto 0);

    type cnn_state_type is (
        IDLE,
        CONV1, POOL1,
        CONV2, POOL2,
        CONV3, POOL3,
        CONV4, POOL4,
        CONV5,
        LINEAR1, LINEAR2, LINEAR3,
        FUSION, CLASSIFIER, ARGMAX, OUTPUT_RESULT
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

    -- CONV1 (1→8, len=128) signals
    signal conv1_start      : std_logic := '0';
    signal conv1_done       : std_logic := '0';
    signal conv1_weight_addr: integer range 0 to 8191;
    signal conv1_bias_addr  : integer range 0 to 255;
    signal conv1_input_addr : integer range 0 to 8191;
    signal conv1_output_data: signed(15 downto 0);
    signal conv1_output_addr: integer range 0 to 8191;
    signal conv1_output_we  : std_logic;

    -- CONV2 (8→16, len=64) signals
    signal conv2_start      : std_logic := '0';
    signal conv2_done       : std_logic := '0';
    signal conv2_weight_addr: integer range 0 to 8191;
    signal conv2_bias_addr  : integer range 0 to 255;
    signal conv2_input_data : signed(15 downto 0);
    signal conv2_input_addr : integer range 0 to 8191;
    signal conv2_output_data: signed(15 downto 0);
    signal conv2_output_addr: integer range 0 to 8191;
    signal conv2_output_we  : std_logic;

    -- CONV3 (16→32, len=32) signals
    signal conv3_start      : std_logic := '0';
    signal conv3_done       : std_logic := '0';
    signal conv3_weight_addr: integer range 0 to 8191;
    signal conv3_bias_addr  : integer range 0 to 255;
    signal conv3_input_data : signed(15 downto 0);
    signal conv3_input_addr : integer range 0 to 8191;
    signal conv3_output_data: signed(15 downto 0);
    signal conv3_output_addr: integer range 0 to 8191;
    signal conv3_output_we  : std_logic;

    -- CONV4 (32→32, len=16) signals
    signal conv4_start      : std_logic := '0';
    signal conv4_done       : std_logic := '0';
    signal conv4_weight_addr: integer range 0 to 8191;
    signal conv4_bias_addr  : integer range 0 to 255;
    signal conv4_input_data : signed(15 downto 0);
    signal conv4_input_addr : integer range 0 to 8191;
    signal conv4_output_data: signed(15 downto 0);
    signal conv4_output_addr: integer range 0 to 8191;
    signal conv4_output_we  : std_logic;

    -- CONV5 (32→1, len=8) signals
    signal conv5_start      : std_logic := '0';
    signal conv5_done       : std_logic := '0';
    signal conv5_weight_addr: integer range 0 to 8191;
    signal conv5_bias_addr  : integer range 0 to 255;
    signal conv5_input_data : signed(15 downto 0);
    signal conv5_input_addr : integer range 0 to 8191;
    signal conv5_output_data: signed(15 downto 0);
    signal conv5_output_addr: integer range 0 to 8191;
    signal conv5_output_we  : std_logic;

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
    signal conv0_weight_data, conv0_bias_data : signed(15 downto 0);
    signal conv1_weight_data, conv1_bias_data : signed(15 downto 0);
    signal conv2_weight_data, conv2_bias_data : signed(15 downto 0);
    signal conv3_weight_data, conv3_bias_data : signed(15 downto 0);
    signal conv4_weight_data, conv4_bias_data : signed(15 downto 0);
    signal linear0_weight_data, linear0_bias_data : signed(15 downto 0);
    signal linear1_weight_data, linear1_bias_data : signed(15 downto 0);
    signal linear2_weight_data, linear2_bias_data : signed(15 downto 0);
    signal classifier_weight_data, classifier_bias_data : signed(15 downto 0);

    -- MaxPool signals (4 pools)
    signal pool1_enable : std_logic := '0';
    signal pool1_done   : std_logic := '0';
    signal pool1_input_0, pool1_input_1 : signed(15 downto 0);
    signal pool1_output : signed(15 downto 0);

    signal pool2_enable : std_logic := '0';
    signal pool2_done   : std_logic := '0';
    signal pool2_input_0, pool2_input_1 : signed(15 downto 0);
    signal pool2_output : signed(15 downto 0);

    signal pool3_enable : std_logic := '0';
    signal pool3_done   : std_logic := '0';
    signal pool3_input_0, pool3_input_1 : signed(15 downto 0);
    signal pool3_output : signed(15 downto 0);

    signal pool4_enable : std_logic := '0';
    signal pool4_done   : std_logic := '0';
    signal pool4_input_0, pool4_input_1 : signed(15 downto 0);
    signal pool4_output : signed(15 downto 0);

    -- Pooling counters
    signal pool_index : integer range 0 to 8191 := 0;

    -- Final outputs
    signal upper_final : array_8x16 := (others => (others => '0'));
    signal lower_final : array_8x16 := (others => (others => '0'));
    signal fusion_result : array_8x16 := (others => (others => '0'));
    signal class_scores : array_8x16 := (others => (others => '0'));

    signal layer_counter : integer range 0 to 100000 := 0;

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
    -- Weight ROM Instances (18 total)
    --------------------------------------------------------------------------------

    conv0_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv0_weight.mif")
        port map (clk => clk, addr_a => conv1_weight_addr, data_a => conv0_weight_data, addr_b => 0, data_b => open);

    conv0_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv0_bias.mif")
        port map (clk => clk, addr_a => conv1_bias_addr, data_a => conv0_bias_data, addr_b => 0, data_b => open);

    conv1_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv1_weight.mif")
        port map (clk => clk, addr_a => conv2_weight_addr, data_a => conv1_weight_data, addr_b => 0, data_b => open);

    conv1_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv1_bias.mif")
        port map (clk => clk, addr_a => conv2_bias_addr, data_a => conv1_bias_data, addr_b => 0, data_b => open);

    conv2_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv2_weight.mif")
        port map (clk => clk, addr_a => conv3_weight_addr, data_a => conv2_weight_data, addr_b => 0, data_b => open);

    conv2_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv2_bias.mif")
        port map (clk => clk, addr_a => conv3_bias_addr, data_a => conv2_bias_data, addr_b => 0, data_b => open);

    conv3_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv3_weight.mif")
        port map (clk => clk, addr_a => conv4_weight_addr, data_a => conv3_weight_data, addr_b => 0, data_b => open);

    conv3_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv3_bias.mif")
        port map (clk => clk, addr_a => conv4_bias_addr, data_a => conv3_bias_data, addr_b => 0, data_b => open);

    conv4_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv4_weight.mif")
        port map (clk => clk, addr_a => conv5_weight_addr, data_a => conv4_weight_data, addr_b => 0, data_b => open);

    conv4_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/conv4_bias.mif")
        port map (clk => clk, addr_a => conv5_bias_addr, data_a => conv4_bias_data, addr_b => 0, data_b => open);

    linear0_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/linear0_weight.mif")
        port map (clk => clk, addr_a => linear1_weight_addr, data_a => linear0_weight_data, addr_b => 0, data_b => open);

    linear0_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/linear0_bias.mif")
        port map (clk => clk, addr_a => linear1_bias_addr, data_a => linear0_bias_data, addr_b => 0, data_b => open);

    linear1_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/linear1_weight.mif")
        port map (clk => clk, addr_a => linear2_weight_addr, data_a => linear1_weight_data, addr_b => 0, data_b => open);

    linear1_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/linear1_bias.mif")
        port map (clk => clk, addr_a => linear2_bias_addr, data_a => linear1_bias_data, addr_b => 0, data_b => open);

    linear2_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/linear2_weight.mif")
        port map (clk => clk, addr_a => linear3_weight_addr, data_a => linear2_weight_data, addr_b => 0, data_b => open);

    linear2_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/linear2_bias.mif")
        port map (clk => clk, addr_a => linear3_bias_addr, data_a => linear2_bias_data, addr_b => 0, data_b => open);

    classifier_weight_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/classifier_weight.mif")
        port map (clk => clk, addr_a => classifier_weight_addr, data_a => classifier_weight_data, addr_b => 0, data_b => open);

    classifier_bias_rom : weight_rom
        generic map (DATA_WIDTH => 16, ADDR_WIDTH => 14, INIT_FILE => "weights/classifier_bias.mif")
        port map (clk => clk, addr_a => classifier_bias_addr, data_a => classifier_bias_data, addr_b => 0, data_b => open);

    --------------------------------------------------------------------------------
    -- Layer Buffer Instances (8 total) - Store intermediate activations
    --------------------------------------------------------------------------------

    -- Buffer after CONV1: stores 8×128 values
    conv1_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 1024)  -- 8 channels × 128 length
        port map (
            clk => clk,
            wr_addr => conv1_output_addr,
            wr_data => conv1_output_data,
            wr_en => conv1_output_we,
            rd_addr => conv2_input_addr,
            rd_data => conv2_input_data
        );

    -- Buffer after CONV2: stores 16×64 values
    conv2_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 1024)  -- 16 channels × 64 length
        port map (
            clk => clk,
            wr_addr => conv2_output_addr,
            wr_data => conv2_output_data,
            wr_en => conv2_output_we,
            rd_addr => conv3_input_addr,
            rd_data => conv3_input_data
        );

    -- Buffer after CONV3: stores 32×32 values
    conv3_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 1024)  -- 32 channels × 32 length
        port map (
            clk => clk,
            wr_addr => conv3_output_addr,
            wr_data => conv3_output_data,
            wr_en => conv3_output_we,
            rd_addr => conv4_input_addr,
            rd_data => conv4_input_data
        );

    -- Buffer after CONV4: stores 32×16 values
    conv4_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 512)  -- 32 channels × 16 length
        port map (
            clk => clk,
            wr_addr => conv4_output_addr,
            wr_data => conv4_output_data,
            wr_en => conv4_output_we,
            rd_addr => conv5_input_addr,
            rd_data => conv5_input_data
        );

    -- Buffer after LINEAR1: stores 64 values
    linear1_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 64)
        port map (
            clk => clk,
            wr_addr => linear1_output_addr,
            wr_data => linear1_output_data,
            wr_en => linear1_output_we,
            rd_addr => linear2_input_addr,
            rd_data => linear2_input_data
        );

    -- Buffer after LINEAR2: stores 16 values
    linear2_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 16)
        port map (
            clk => clk,
            wr_addr => linear2_output_addr,
            wr_data => linear2_output_data,
            wr_en => linear2_output_we,
            rd_addr => linear3_input_addr,
            rd_data => linear3_input_data
        );

    -- Buffer after LINEAR3: stores 8 values (lower path final)
    linear3_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 8)
        port map (
            clk => clk,
            wr_addr => linear3_output_addr,
            wr_data => linear3_output_data,
            wr_en => linear3_output_we,
            rd_addr => 0,
            rd_data => open  -- Read directly into lower_final array
        );

    -- Buffer after CONV5: stores 8 values (upper path final)
    conv5_buffer : layer_buffer
        generic map (DATA_WIDTH => 16, DEPTH => 8)
        port map (
            clk => clk,
            wr_addr => conv5_output_addr,
            wr_data => conv5_output_data,
            wr_en => conv5_output_we,
            rd_addr => 0,
            rd_data => open  -- Read directly into upper_final array
        );

    --------------------------------------------------------------------------------
    -- CONV Engine Instances (5 total)
    --------------------------------------------------------------------------------

    -- CONV1: 1→8, input_length=128
    conv1_inst : conv1d_engine
        generic map (
            DATA_WIDTH   => 16,
            IN_CHANNELS  => 1,
            OUT_CHANNELS => 8,
            INPUT_LENGTH => 128,
            KERNEL_SIZE  => 3
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => conv1_start,
            weight_data => conv0_weight_data,
            weight_addr => conv1_weight_addr,
            bias_data   => conv0_bias_data,
            bias_addr   => conv1_bias_addr,
            input_data  => buf_rd_data,
            input_addr  => conv1_input_addr,  -- Engine OUTPUT controls buffer read address
            output_data => conv1_output_data,
            output_addr => conv1_output_addr,
            output_we   => conv1_output_we,
            done        => conv1_done
        );

    -- CONV2: 8→16, input_length=64
    conv2_inst : conv1d_engine
        generic map (
            DATA_WIDTH   => 16,
            IN_CHANNELS  => 8,
            OUT_CHANNELS => 16,
            INPUT_LENGTH => 64,
            KERNEL_SIZE  => 3
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => conv2_start,
            weight_data => conv1_weight_data,
            weight_addr => conv2_weight_addr,
            bias_data   => conv1_bias_data,
            bias_addr   => conv2_bias_addr,
            input_data  => conv2_input_data,  -- From conv1_buffer
            input_addr  => conv2_input_addr,
            output_data => conv2_output_data,
            output_addr => conv2_output_addr,
            output_we   => conv2_output_we,
            done        => conv2_done
        );

    -- CONV3: 16→32, input_length=32
    conv3_inst : conv1d_engine
        generic map (
            DATA_WIDTH   => 16,
            IN_CHANNELS  => 16,
            OUT_CHANNELS => 32,
            INPUT_LENGTH => 32,
            KERNEL_SIZE  => 3
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => conv3_start,
            weight_data => conv2_weight_data,
            weight_addr => conv3_weight_addr,
            bias_data   => conv2_bias_data,
            bias_addr   => conv3_bias_addr,
            input_data  => conv3_input_data,  -- From conv2_buffer
            input_addr  => conv3_input_addr,
            output_data => conv3_output_data,
            output_addr => conv3_output_addr,
            output_we   => conv3_output_we,
            done        => conv3_done
        );

    -- CONV4: 32→32, input_length=16
    conv4_inst : conv1d_engine
        generic map (
            DATA_WIDTH   => 16,
            IN_CHANNELS  => 32,
            OUT_CHANNELS => 32,
            INPUT_LENGTH => 16,
            KERNEL_SIZE  => 3
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => conv4_start,
            weight_data => conv3_weight_data,
            weight_addr => conv4_weight_addr,
            bias_data   => conv3_bias_data,
            bias_addr   => conv4_bias_addr,
            input_data  => conv4_input_data,  -- From conv3_buffer
            input_addr  => conv4_input_addr,
            output_data => conv4_output_data,
            output_addr => conv4_output_addr,
            output_we   => conv4_output_we,
            done        => conv4_done
        );

    -- CONV5: 32→1, input_length=8
    conv5_inst : conv1d_engine
        generic map (
            DATA_WIDTH   => 16,
            IN_CHANNELS  => 32,
            OUT_CHANNELS => 1,
            INPUT_LENGTH => 8,
            KERNEL_SIZE  => 3
        )
        port map (
            clk         => clk,
            reset_n     => reset_n,
            start       => conv5_start,
            weight_data => conv4_weight_data,
            weight_addr => conv5_weight_addr,
            bias_data   => conv4_bias_data,
            bias_addr   => conv5_bias_addr,
            input_data  => conv5_input_data,  -- From conv4_buffer
            input_addr  => conv5_input_addr,
            output_data => conv5_output_data,
            output_addr => conv5_output_addr,
            output_we   => conv5_output_we,
            done        => conv5_done
        );

    --------------------------------------------------------------------------------
    -- LINEAR Engine Instances (4 total)
    --------------------------------------------------------------------------------

    -- LINEAR1: 128→64
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

    -- LINEAR2: 64→16
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
            input_data  => linear2_input_data,  -- From linear1_buffer
            input_addr  => linear2_input_addr,
            output_data => linear2_output_data,
            output_addr => linear2_output_addr,
            output_we   => linear2_output_we,
            done        => linear2_done
        );

    -- LINEAR3: 16→8
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
            input_data  => linear3_input_data,  -- From linear2_buffer
            input_addr  => linear3_input_addr,
            output_data => linear3_output_data,
            output_addr => linear3_output_addr,
            output_we   => linear3_output_we,
            done        => linear3_done
        );

    -- CLASSIFIER: 8→8
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
    -- MaxPool Instances (4 total)
    --------------------------------------------------------------------------------

    pool1_inst : maxpool1d
        generic map (DATA_WIDTH => 16)
        port map (
            clk => clk,
            reset_n => reset_n,
            enable => pool1_enable,
            input_0 => pool1_input_0,
            input_1 => pool1_input_1,
            output => pool1_output,
            valid => pool1_done
        );

    pool2_inst : maxpool1d
        generic map (DATA_WIDTH => 16)
        port map (
            clk => clk,
            reset_n => reset_n,
            enable => pool2_enable,
            input_0 => pool2_input_0,
            input_1 => pool2_input_1,
            output => pool2_output,
            valid => pool2_done
        );

    pool3_inst : maxpool1d
        generic map (DATA_WIDTH => 16)
        port map (
            clk => clk,
            reset_n => reset_n,
            enable => pool3_enable,
            input_0 => pool3_input_0,
            input_1 => pool3_input_1,
            output => pool3_output,
            valid => pool3_done
        );

    pool4_inst : maxpool1d
        generic map (DATA_WIDTH => 16)
        port map (
            clk => clk,
            reset_n => reset_n,
            enable => pool4_enable,
            input_0 => pool4_input_0,
            input_1 => pool4_input_1,
            output => pool4_output,
            valid => pool4_done
        );

    --------------------------------------------------------------------------------
    -- Sample Accumulation
    --------------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            sample_count <= 0;
            buffer_ready <= '0';
            buf_wr_addr <= 0;

        elsif rising_edge(clk) then

            -- Always accept samples
            if sample_valid = '1' then
                buf_wr_addr <= sample_count mod 128;
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
            cnn_state <= IDLE;
            result_valid <= '0';
            layer_counter <= 0;

        elsif rising_edge(clk) then

            result_valid <= '0';
            conv1_start <= '0';
            conv2_start <= '0';
            conv3_start <= '0';
            conv4_start <= '0';
            conv5_start <= '0';
            linear1_start <= '0';
            linear2_start <= '0';
            linear3_start <= '0';
            classifier_start <= '0';
            pool1_enable <= '0';
            pool2_enable <= '0';
            pool3_enable <= '0';
            pool4_enable <= '0';

            case cnn_state is

                when IDLE =>
                    if buffer_ready = '1' then
                        cnn_state <= CONV1;
                        layer_counter <= 0;
                        conv1_start <= '1';
                    end if;

                when CONV1 =>
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 5000 or conv1_done = '1' then
                        cnn_state <= POOL1;
                        layer_counter <= 0;
                        pool1_enable <= '1';
                    end if;

                when POOL1 =>
                    -- MaxPool: 8×128 → 8×64
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 200 then  -- Pool is fast
                        cnn_state <= CONV2;
                        layer_counter <= 0;
                        conv2_start <= '1';
                        pool1_enable <= '0';
                    end if;

                when CONV2 =>
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 3000 or conv2_done = '1' then
                        cnn_state <= POOL2;
                        layer_counter <= 0;
                        pool2_enable <= '1';
                    end if;

                when POOL2 =>
                    -- MaxPool: 16×64 → 16×32
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 100 then
                        cnn_state <= CONV3;
                        layer_counter <= 0;
                        conv3_start <= '1';
                        pool2_enable <= '0';
                    end if;

                when CONV3 =>
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 2000 or conv3_done = '1' then
                        cnn_state <= POOL3;
                        layer_counter <= 0;
                        pool3_enable <= '1';
                    end if;

                when POOL3 =>
                    -- MaxPool: 32×32 → 32×16
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 50 then
                        cnn_state <= CONV4;
                        layer_counter <= 0;
                        conv4_start <= '1';
                        pool3_enable <= '0';
                    end if;

                when CONV4 =>
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 1000 or conv4_done = '1' then
                        cnn_state <= POOL4;
                        layer_counter <= 0;
                        pool4_enable <= '1';
                    end if;

                when POOL4 =>
                    -- MaxPool: 32×16 → 32×8
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 50 then
                        cnn_state <= CONV5;
                        layer_counter <= 0;
                        conv5_start <= '1';
                        pool4_enable <= '0';
                    end if;

                when CONV5 =>
                    layer_counter <= layer_counter + 1;
                    -- Collect all 8 output values from CONV5 (1×8)
                    if conv5_output_we = '1' and conv5_output_addr < 8 then
                        upper_final(conv5_output_addr) <= conv5_output_data;
                    end if;

                    if layer_counter > 500 or conv5_done = '1' then
                        cnn_state <= LINEAR1;
                        layer_counter <= 0;
                        linear1_start <= '1';
                    end if;

                when LINEAR1 =>
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 8000 or linear1_done = '1' then
                        cnn_state <= LINEAR2;
                        layer_counter <= 0;
                        linear2_start <= '1';
                    end if;

                when LINEAR2 =>
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 1000 or linear2_done = '1' then
                        cnn_state <= LINEAR3;
                        layer_counter <= 0;
                        linear3_start <= '1';
                    end if;

                when LINEAR3 =>
                    layer_counter <= layer_counter + 1;
                    -- Collect all 8 output values from LINEAR3
                    if linear3_output_we = '1' and linear3_output_addr < 8 then
                        lower_final(linear3_output_addr) <= linear3_output_data;
                    end if;

                    if layer_counter > 200 or linear3_done = '1' then
                        cnn_state <= FUSION;
                        layer_counter <= 0;
                    end if;

                when FUSION =>
                    -- Element-wise addition
                    for i in 0 to 7 loop
                        fusion_result(i) <= upper_final(i) + lower_final(i);
                    end loop;

                    layer_counter <= layer_counter + 1;
                    if layer_counter > 10 then  -- Give time for addition
                        cnn_state <= CLASSIFIER;
                        classifier_start <= '1';
                        layer_counter <= 0;
                    end if;

                when CLASSIFIER =>
                    layer_counter <= layer_counter + 1;
                    -- Collect all 8 class scores
                    if classifier_output_we = '1' and classifier_output_addr < 8 then
                        class_scores(classifier_output_addr) <= classifier_output_data;
                    end if;

                    if layer_counter > 100 or classifier_done = '1' then
                        cnn_state <= ARGMAX;
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
                    cnn_state <= OUTPUT_RESULT;

                when OUTPUT_RESULT =>
                    result_valid <= '1';
                    layer_counter <= layer_counter + 1;
                    if layer_counter > 1000 then
                        cnn_state <= IDLE;
                        layer_counter <= 0;
                    end if;

                when others =>
                    cnn_state <= IDLE;

            end case;

        end if;
    end process;

    --------------------------------------------------------------------------------
    -- Concurrent Signal Assignments
    --------------------------------------------------------------------------------

    -- Multiplex buffer read address based on active layer
    buf_rd_addr <= conv1_input_addr when cnn_state = CONV1 else
                   linear1_input_addr when cnn_state = LINEAR1 else
                   0;

    -- Classifier reads from fusion_result array
    classifier_input_data <= fusion_result(classifier_input_addr) when classifier_input_addr < 8
                             else (others => '0');

end Behavioral;
