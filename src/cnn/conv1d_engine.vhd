--------------------------------------------------------------------------------
-- 1D Convolution Engine
-- Performs 1D convolution: output[out_ch, x] = sum(input[in_ch, x+k] * weight[out_ch, in_ch, k])
--
-- Time-multiplexed design: Single MAC unit reused for all operations
-- Supports kernel_size = 3, padding = 1
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity conv1d_engine is
    generic (
        DATA_WIDTH    : integer := 16;  -- Q8.8 fixed-point
        IN_CHANNELS   : integer := 1;
        OUT_CHANNELS  : integer := 8;
        INPUT_LENGTH  : integer := 128;
        KERNEL_SIZE   : integer := 3
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        start       : in  std_logic;

        -- Weight ROM interface
        weight_data : in  signed(DATA_WIDTH-1 downto 0);
        weight_addr : out integer range 0 to 8191;

        -- Bias ROM interface
        bias_data   : in  signed(DATA_WIDTH-1 downto 0);
        bias_addr   : out integer range 0 to 255;

        -- Input buffer interface
        input_data  : in  signed(DATA_WIDTH-1 downto 0);
        input_addr  : out integer range 0 to 8191;

        -- Output buffer interface
        output_data : out signed(DATA_WIDTH-1 downto 0);
        output_addr : out integer range 0 to 8191;
        output_we   : out std_logic;

        -- Status
        done        : out std_logic
    );
end conv1d_engine;

architecture Behavioral of conv1d_engine is

    type state_type is (IDLE, LOAD_WEIGHT, LOAD_INPUT, MULTIPLY, ACCUMULATE, ADD_BIAS, WRITE_OUTPUT, NEXT_POS, DONE_STATE);
    signal state : state_type := IDLE;

    -- Loop counters
    signal out_ch : integer range 0 to 255 := 0;
    signal in_ch  : integer range 0 to 255 := 0;
    signal k_pos  : integer range 0 to 15 := 0;
    signal x_pos  : integer range 0 to 8191 := 0;

    -- Computation registers
    signal accumulator : signed(31 downto 0) := (others => '0');  -- 32-bit for MAC
    signal weight_reg  : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal input_reg   : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal bias_reg    : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal product     : signed(31 downto 0) := (others => '0');

    -- Output length after pooling considerations
    constant OUTPUT_LENGTH : integer := INPUT_LENGTH;  -- Same size with padding=1

begin

    process(clk, reset_n)
        variable result : signed(31 downto 0);  -- Move variable declaration here
    begin
        if reset_n = '0' then
            state <= IDLE;
            out_ch <= 0;
            in_ch <= 0;
            k_pos <= 0;
            x_pos <= 0;
            accumulator <= (others => '0');
            done <= '0';
            output_we <= '0';

        elsif rising_edge(clk) then

            -- Default outputs
            output_we <= '0';
            done <= '0';

            case state is

                when IDLE =>
                    if start = '1' then
                        out_ch <= 0;
                        in_ch <= 0;
                        k_pos <= 0;
                        x_pos <= 0;
                        accumulator <= (others => '0');
                        state <= LOAD_WEIGHT;
                    end if;

                when LOAD_WEIGHT =>
                    -- Address weight ROM: weight[out_ch][in_ch][k_pos]
                    weight_addr <= out_ch * IN_CHANNELS * KERNEL_SIZE + in_ch * KERNEL_SIZE + k_pos;
                    state <= LOAD_INPUT;

                when LOAD_INPUT =>
                    -- Register weight from previous cycle
                    weight_reg <= weight_data;

                    -- Address input buffer: input[in_ch][x_pos + k_pos - 1]
                    -- (padding=1 means k_pos=0 reads x_pos-1, handled with boundary checks)
                    if (x_pos + k_pos) >= 1 and (x_pos + k_pos) <= INPUT_LENGTH then
                        input_addr <= in_ch * INPUT_LENGTH + (x_pos + k_pos - 1);
                    else
                        input_addr <= 0;  -- Padding (will use zero)
                    end if;

                    state <= MULTIPLY;

                when MULTIPLY =>
                    -- Register input from previous cycle
                    if (x_pos + k_pos) >= 1 and (x_pos + k_pos) <= INPUT_LENGTH then
                        input_reg <= input_data;
                    else
                        input_reg <= (others => '0');  -- Zero padding
                    end if;

                    -- Multiply: product = weight * input
                    product <= weight_reg * input_reg;

                    state <= ACCUMULATE;

                when ACCUMULATE =>
                    -- Accumulate: acc += product
                    -- Fixed-point: Q8.8 * Q8.8 = Q16.16, shift right by 8 to get Q8.8
                    accumulator <= accumulator + (product(31 downto 8) & "00000000");

                    -- Move to next kernel position
                    if k_pos = KERNEL_SIZE - 1 then
                        k_pos <= 0;
                        -- Next input channel
                        if in_ch = IN_CHANNELS - 1 then
                            in_ch <= 0;
                            state <= ADD_BIAS;  -- Done all channels for this output
                        else
                            in_ch <= in_ch + 1;
                            state <= LOAD_WEIGHT;
                        end if;
                    else
                        k_pos <= k_pos + 1;
                        state <= LOAD_WEIGHT;
                    end if;

                when ADD_BIAS =>
                    -- Load bias for current output channel
                    bias_addr <= out_ch;
                    state <= WRITE_OUTPUT;

                when WRITE_OUTPUT =>
                    -- Register bias
                    bias_reg <= bias_data;

                    -- Add bias and apply ReLU
                    -- output = ReLU(accumulator + bias)
                    result := accumulator + (bias_reg & "00000000");  -- Extend bias to 32-bit

                    -- ReLU: max(0, result)
                    if result(31) = '1' then  -- Negative
                        output_data <= (others => '0');
                    else
                        -- Truncate back to 16-bit Q8.8
                        output_data <= result(23 downto 8);
                    end if;

                    -- Write to output buffer: output[out_ch][x_pos]
                    output_addr <= out_ch * OUTPUT_LENGTH + x_pos;
                    output_we <= '1';

                    accumulator <= (others => '0');  -- Reset accumulator

                    state <= NEXT_POS;

                when NEXT_POS =>
                    -- Move to next position
                    if x_pos = OUTPUT_LENGTH - 1 then
                        x_pos <= 0;
                        -- Next output channel
                        if out_ch = OUT_CHANNELS - 1 then
                            out_ch <= 0;
                            state <= DONE_STATE;
                        else
                            out_ch <= out_ch + 1;
                            state <= LOAD_WEIGHT;
                        end if;
                    else
                        x_pos <= x_pos + 1;
                        state <= LOAD_WEIGHT;
                    end if;

                when DONE_STATE =>
                    done <= '1';
                    state <= IDLE;

                when others =>
                    state <= IDLE;

            end case;

        end if;
    end process;

end Behavioral;
