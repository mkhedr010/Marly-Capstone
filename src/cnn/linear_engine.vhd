--------------------------------------------------------------------------------
-- Linear (Fully-Connected) Layer Engine
-- Performs matrix-vector multiplication: output[j] = sum(input[i] * weight[j][i]) + bias[j]
--
-- Time-multiplexed design: Single MAC unit reused
-- Includes ReLU activation
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity linear_engine is
    generic (
        DATA_WIDTH     : integer := 16;  -- Q8.8 fixed-point
        INPUT_FEATURES : integer := 128;
        OUTPUT_FEATURES: integer := 64
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        start       : in  std_logic;

        -- Weight ROM interface
        weight_data : in  signed(DATA_WIDTH-1 downto 0);
        weight_addr : out integer range 0 to 16383;

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
end linear_engine;

architecture Behavioral of linear_engine is

    type state_type is (IDLE, LOAD_WEIGHT, LOAD_INPUT, MULTIPLY, ACCUMULATE, ADD_BIAS, APPLY_RELU, WRITE_OUTPUT, NEXT_OUTPUT, DONE_STATE);
    signal state : state_type := IDLE;

    -- Loop counters
    signal out_idx : integer range 0 to 8191 := 0;  -- Output feature index
    signal in_idx  : integer range 0 to 8191 := 0;  -- Input feature index

    -- Computation registers
    signal accumulator : signed(31 downto 0) := (others => '0');  -- 32-bit accumulator
    signal weight_reg  : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal input_reg   : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal bias_reg    : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal product     : signed(31 downto 0) := (others => '0');
    signal result      : signed(DATA_WIDTH-1 downto 0) := (others => '0');

begin

    process(clk, reset_n)
        variable temp_result : signed(31 downto 0);
    begin
        if reset_n = '0' then
            state <= IDLE;
            out_idx <= 0;
            in_idx <= 0;
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
                        out_idx <= 0;
                        in_idx <= 0;
                        accumulator <= (others => '0');
                        state <= LOAD_WEIGHT;
                    end if;

                when LOAD_WEIGHT =>
                    -- Address weight ROM: weight[out_idx][in_idx]
                    weight_addr <= out_idx * INPUT_FEATURES + in_idx;
                    state <= LOAD_INPUT;

                when LOAD_INPUT =>
                    -- Register weight from ROM
                    weight_reg <= weight_data;

                    -- Address input buffer: input[in_idx]
                    input_addr <= in_idx;
                    state <= MULTIPLY;

                when MULTIPLY =>
                    -- Register input from buffer
                    input_reg <= input_data;

                    -- Multiply: product = weight * input
                    product <= weight_reg * input_reg;

                    state <= ACCUMULATE;

                when ACCUMULATE =>
                    -- Accumulate: acc += product
                    -- Q8.8 * Q8.8 = Q16.16, shift right by 8 to get Q8.8
                    accumulator <= accumulator + (product(31 downto 8) & "00000000");

                    -- Move to next input feature
                    if in_idx = INPUT_FEATURES - 1 then
                        in_idx <= 0;
                        state <= ADD_BIAS;
                    else
                        in_idx <= in_idx + 1;
                        state <= LOAD_WEIGHT;
                    end if;

                when ADD_BIAS =>
                    -- Load bias for current output feature
                    bias_addr <= out_idx;
                    state <= APPLY_RELU;

                when APPLY_RELU =>
                    -- Register bias
                    bias_reg <= bias_data;

                    -- Add bias: result = accumulator + bias
                    temp_result := accumulator + (bias_reg & "00000000");

                    -- Apply ReLU: output = max(0, result)
                    if temp_result(31) = '1' then  -- Negative
                        result <= (others => '0');
                    else
                        -- Truncate to 16-bit Q8.8
                        result <= temp_result(23 downto 8);
                    end if;

                    state <= WRITE_OUTPUT;

                when WRITE_OUTPUT =>
                    -- Write result to output buffer
                    output_data <= result;
                    output_addr <= out_idx;
                    output_we <= '1';

                    -- Reset accumulator for next output
                    accumulator <= (others => '0');

                    state <= NEXT_OUTPUT;

                when NEXT_OUTPUT =>
                    -- Move to next output feature
                    if out_idx = OUTPUT_FEATURES - 1 then
                        out_idx <= 0;
                        state <= DONE_STATE;
                    else
                        out_idx <= out_idx + 1;
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
