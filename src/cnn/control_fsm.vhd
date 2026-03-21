--------------------------------------------------------------------------------
-- CNN Control Finite State Machine
-- Orchestrates sequential execution of ZolotyhNet layers
--
-- State sequence follows network architecture:
--   Upper Path: Conv1→Pool→Conv2→Pool→Conv3→Pool→Conv4→Pool→Conv5
--   Lower Path: Linear1→Linear2→Linear3
--   Fusion: Add upper + lower
--   Classifier: Linear output layer
--
-- Author: Marly Capstone
-- Date: March 2026
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity control_fsm is
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;

        -- Trigger
        start           : in  std_logic;  -- Start when 128 samples buffered

        -- Layer completion signals
        conv_done       : in  std_logic;
        linear_done     : in  std_logic;
        pool_done       : in  std_logic;

        -- Layer control outputs
        layer_select    : out integer range 0 to 31;
        layer_start     : out std_logic;

        -- CNN completion
        cnn_done        : out std_logic;
        cnn_valid       : out std_logic
    );
end control_fsm;

architecture Behavioral of control_fsm is

    type state_type is (
        IDLE,
        -- Upper path states
        CONV1_UP, POOL1_UP,
        CONV2_UP, POOL2_UP,
        CONV3_UP, POOL3_UP,
        CONV4_UP, POOL4_UP,
        CONV5_UP,
        -- Lower path states
        LINEAR1_DOWN, LINEAR2_DOWN, LINEAR3_DOWN,
        -- Fusion
        ADD_FUSION,
        -- Classifier
        CLASSIFIER,
        -- Output
        OUTPUT_RESULT,
        DONE_STATE
    );

    signal state, next_state : state_type := IDLE;

    -- Layer mapping
    constant LAYER_CONV1    : integer := 0;
    constant LAYER_POOL1    : integer := 1;
    constant LAYER_CONV2    : integer := 2;
    constant LAYER_POOL2    : integer := 3;
    constant LAYER_CONV3    : integer := 4;
    constant LAYER_POOL3    : integer := 5;
    constant LAYER_CONV4    : integer := 6;
    constant LAYER_POOL4    : integer := 7;
    constant LAYER_CONV5    : integer := 8;
    constant LAYER_LINEAR1  : integer := 9;
    constant LAYER_LINEAR2  : integer := 10;
    constant LAYER_LINEAR3  : integer := 11;
    constant LAYER_ADD      : integer := 12;
    constant LAYER_CLASSIFIER : integer := 13;

begin

    -- State register
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;

    -- Next state logic
    process(state, start, conv_done, linear_done, pool_done)
    begin
        -- Defaults
        next_state <= state;
        layer_select <= 0;
        layer_start <= '0';
        cnn_done <= '0';
        cnn_valid <= '0';

        case state is

            when IDLE =>
                if start = '1' then
                    next_state <= CONV1_UP;
                end if;

            -- Upper path: Convolutional chain
            when CONV1_UP =>
                layer_select <= LAYER_CONV1;
                layer_start <= '1';
                if conv_done = '1' then
                    next_state <= POOL1_UP;
                end if;

            when POOL1_UP =>
                layer_select <= LAYER_POOL1;
                layer_start <= '1';
                if pool_done = '1' then
                    next_state <= CONV2_UP;
                end if;

            when CONV2_UP =>
                layer_select <= LAYER_CONV2;
                layer_start <= '1';
                if conv_done = '1' then
                    next_state <= POOL2_UP;
                end if;

            when POOL2_UP =>
                layer_select <= LAYER_POOL2;
                layer_start <= '1';
                if pool_done = '1' then
                    next_state <= CONV3_UP;
                end if;

            when CONV3_UP =>
                layer_select <= LAYER_CONV3;
                layer_start <= '1';
                if conv_done = '1' then
                    next_state <= POOL3_UP;
                end if;

            when POOL3_UP =>
                layer_select <= LAYER_POOL3;
                layer_start <= '1';
                if pool_done = '1' then
                    next_state <= CONV4_UP;
                end if;

            when CONV4_UP =>
                layer_select <= LAYER_CONV4;
                layer_start <= '1';
                if conv_done = '1' then
                    next_state <= POOL4_UP;
                end if;

            when POOL4_UP =>
                layer_select <= LAYER_POOL4;
                layer_start <= '1';
                if pool_done = '1' then
                    next_state <= CONV5_UP;
                end if;

            when CONV5_UP =>
                layer_select <= LAYER_CONV5;
                layer_start <= '1';
                if conv_done = '1' then
                    next_state <= LINEAR1_DOWN;
                end if;

            -- Lower path: Fully-connected chain
            when LINEAR1_DOWN =>
                layer_select <= LAYER_LINEAR1;
                layer_start <= '1';
                if linear_done = '1' then
                    next_state <= LINEAR2_DOWN;
                end if;

            when LINEAR2_DOWN =>
                layer_select <= LAYER_LINEAR2;
                layer_start <= '1';
                if linear_done = '1' then
                    next_state <= LINEAR3_DOWN;
                end if;

            when LINEAR3_DOWN =>
                layer_select <= LAYER_LINEAR3;
                layer_start <= '1';
                if linear_done = '1' then
                    next_state <= ADD_FUSION;
                end if;

            -- Fusion: Element-wise addition
            when ADD_FUSION =>
                layer_select <= LAYER_ADD;
                layer_start <= '1';
                next_state <= CLASSIFIER;  -- Simple add, 1 cycle

            -- Classifier
            when CLASSIFIER =>
                layer_select <= LAYER_CLASSIFIER;
                layer_start <= '1';
                if linear_done = '1' then
                    next_state <= OUTPUT_RESULT;
                end if;

            -- Output result
            when OUTPUT_RESULT =>
                cnn_valid <= '1';
                next_state <= DONE_STATE;

            when DONE_STATE =>
                cnn_done <= '1';
                next_state <= IDLE;

            when others =>
                next_state <= IDLE;

        end case;
    end process;

end Behavioral;
