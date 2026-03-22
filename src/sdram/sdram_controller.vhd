--------------------------------------------------------------------------------
-- SDRAM Controller for DE2 Board
-- Chip: ISSI IS42S16400 (4M x 16-bit x 4 banks = 8MB)
--
-- Features:
--   - Auto initialization on reset
--   - Read/Write operations
--   - Auto-refresh (64ms period)
--   - Burst mode support
--   - 100 MHz operation
--
-- Author: Marly Capstone
-- Date: March 2026
-- Based on: Terasic DE2 SDRAM examples
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdram_controller is
    generic (
        CLK_FREQ_MHZ    : integer := 100;  -- 100 MHz
        CAS_LATENCY     : integer := 2;    -- CAS latency (2 or 3)
        BURST_LENGTH    : integer := 1     -- Burst length (1, 2, 4, 8)
    );
    port (
        -- Clock and reset
        clk             : in  std_logic;  -- 100 MHz SDRAM clock
        reset_n         : in  std_logic;

        -- FPGA-side interface
        addr            : in  std_logic_vector(22 downto 0);  -- Full 8MB address
        data_in         : in  std_logic_vector(15 downto 0);
        data_out        : out std_logic_vector(15 downto 0);
        read_req        : in  std_logic;
        write_req       : in  std_logic;
        data_valid      : out std_logic;
        busy            : out std_logic;
        init_done       : out std_logic;

        -- SDRAM chip interface (connect to DE2 pins)
        sdram_addr      : out std_logic_vector(11 downto 0);
        sdram_ba        : out std_logic_vector(1 downto 0);  -- Bank address
        sdram_dq        : inout std_logic_vector(15 downto 0);
        sdram_clk       : out std_logic;
        sdram_cke       : out std_logic;  -- Clock enable
        sdram_cs_n      : out std_logic;  -- Chip select
        sdram_ras_n     : out std_logic;  -- Row address strobe
        sdram_cas_n     : out std_logic;  -- Column address strobe
        sdram_we_n      : out std_logic;  -- Write enable
        sdram_dqm       : out std_logic_vector(1 downto 0)  -- Data mask
    );
end sdram_controller;

architecture Behavioral of sdram_controller is

    --------------------------------------------------------------------------------
    -- SDRAM Commands (encoded as {CS_N, RAS_N, CAS_N, WE_N})
    --------------------------------------------------------------------------------
    constant CMD_NOP        : std_logic_vector(3 downto 0) := "0111";
    constant CMD_ACTIVE     : std_logic_vector(3 downto 0) := "0011";
    constant CMD_READ       : std_logic_vector(3 downto 0) := "0101";
    constant CMD_WRITE      : std_logic_vector(3 downto 0) := "0100";
    constant CMD_PRECHARGE  : std_logic_vector(3 downto 0) := "0010";
    constant CMD_REFRESH    : std_logic_vector(3 downto 0) := "0001";
    constant CMD_LOAD_MODE  : std_logic_vector(3 downto 0) := "0000";

    --------------------------------------------------------------------------------
    -- Timing Parameters (in clock cycles at 100 MHz)
    --------------------------------------------------------------------------------
    constant INIT_WAIT      : integer := 20000;  -- 200us initialization delay
    constant REFRESH_PERIOD : integer := 780;    -- 7.8us (64ms/8192 rows)
    constant tRP            : integer := 2;      -- Precharge command period
    constant tRCD           : integer := 2;      -- RAS to CAS delay
    constant tRC            : integer := 7;      -- Row cycle time
    constant tMRD           : integer := 2;      -- Mode register set time

    --------------------------------------------------------------------------------
    -- State Machine
    --------------------------------------------------------------------------------
    type state_type is (
        INIT_WAIT_200US,
        INIT_PRECHARGE,
        INIT_REFRESH1,
        INIT_REFRESH2,
        INIT_LOAD_MODE,
        IDLE,
        REFRESH,
        READ_ACTIVATE,
        READ_WAIT_RCD,
        READ_CAS,
        READ_WAIT_DATA,
        READ_COMPLETE,
        WRITE_ACTIVATE,
        WRITE_WAIT_RCD,
        WRITE_CAS,
        WRITE_COMPLETE,
        PRECHARGE_WAIT
    );

    signal state, next_state : state_type := INIT_WAIT_200US;

    --------------------------------------------------------------------------------
    -- Internal Signals
    --------------------------------------------------------------------------------

    -- Timing counters
    signal init_counter     : integer range 0 to 65535 := 0;
    signal refresh_counter  : integer range 0 to 1023 := 0;
    signal cmd_counter      : integer range 0 to 15 := 0;

    -- Address decomposition
    signal row_addr         : std_logic_vector(11 downto 0);
    signal col_addr         : std_logic_vector(8 downto 0);
    signal bank_addr        : std_logic_vector(1 downto 0);

    -- Data path
    signal data_out_reg     : std_logic_vector(15 downto 0);
    signal data_in_reg      : std_logic_vector(15 downto 0);
    signal dq_out           : std_logic_vector(15 downto 0);
    signal dq_oe            : std_logic := '0';  -- Output enable for DQ

    -- Control signals
    signal cmd              : std_logic_vector(3 downto 0);
    signal init_done_reg    : std_logic := '0';
    signal busy_reg         : std_logic := '1';

begin

    --------------------------------------------------------------------------------
    -- Address Decomposition
    -- addr[22:0] = {bank[1:0], row[11:0], col[8:0]}
    --------------------------------------------------------------------------------
    bank_addr <= addr(22 downto 21);
    row_addr  <= addr(20 downto 9);
    col_addr  <= addr(8 downto 0);

    --------------------------------------------------------------------------------
    -- SDRAM Command Output
    --------------------------------------------------------------------------------
    sdram_cs_n  <= cmd(3);
    sdram_ras_n <= cmd(2);
    sdram_cas_n <= cmd(1);
    sdram_we_n  <= cmd(0);

    --------------------------------------------------------------------------------
    -- SDRAM Pin Assignments
    --------------------------------------------------------------------------------
    sdram_clk  <= clk;
    sdram_cke  <= '1';  -- Always enabled
    sdram_dqm  <= "00"; -- No masking
    sdram_ba   <= bank_addr;

    -- Bidirectional data bus
    sdram_dq <= dq_out when dq_oe = '1' else (others => 'Z');

    --------------------------------------------------------------------------------
    -- Output Assignments
    --------------------------------------------------------------------------------
    data_out   <= data_out_reg;
    busy       <= busy_reg;
    init_done  <= init_done_reg;

    --------------------------------------------------------------------------------
    -- Main State Machine
    --------------------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= INIT_WAIT_200US;
            init_counter <= 0;
            refresh_counter <= 0;
            cmd_counter <= 0;
            init_done_reg <= '0';
            busy_reg <= '1';
            cmd <= CMD_NOP;
            data_valid <= '0';
            dq_oe <= '0';
            data_out_reg <= (others => '0');
            data_in_reg <= (others => '0');

        elsif rising_edge(clk) then

            -- Default: NOP command
            cmd <= CMD_NOP;
            data_valid <= '0';
            dq_oe <= '0';

            -- Refresh counter (always running after init)
            if init_done_reg = '1' and state /= REFRESH then
                if refresh_counter < REFRESH_PERIOD then
                    refresh_counter <= refresh_counter + 1;
                else
                    refresh_counter <= 0;
                    state <= REFRESH;  -- Force refresh
                end if;
            end if;

            case state is

                --------------------------------------------------------------------------------
                -- INITIALIZATION SEQUENCE
                --------------------------------------------------------------------------------

                when INIT_WAIT_200US =>
                    -- Wait 200us for power stabilization
                    busy_reg <= '1';
                    sdram_addr <= (others => '0');

                    if init_counter < INIT_WAIT then
                        init_counter <= init_counter + 1;
                    else
                        init_counter <= 0;
                        state <= INIT_PRECHARGE;
                    end if;

                when INIT_PRECHARGE =>
                    -- Precharge all banks
                    cmd <= CMD_PRECHARGE;
                    sdram_addr(10) <= '1';  -- A10=1 means all banks
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter >= tRP then
                        cmd_counter <= 0;
                        state <= INIT_REFRESH1;
                    end if;

                when INIT_REFRESH1 =>
                    -- First auto-refresh
                    cmd <= CMD_REFRESH;
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter >= tRC then
                        cmd_counter <= 0;
                        state <= INIT_REFRESH2;
                    end if;

                when INIT_REFRESH2 =>
                    -- Second auto-refresh
                    cmd <= CMD_REFRESH;
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter >= tRC then
                        cmd_counter <= 0;
                        state <= INIT_LOAD_MODE;
                    end if;

                when INIT_LOAD_MODE =>
                    -- Load mode register
                    -- Mode: Burst=1, CAS=2, Sequential, Burst length=1
                    cmd <= CMD_LOAD_MODE;
                    sdram_addr <= "000000100000";  -- Mode register value
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter >= tMRD then
                        cmd_counter <= 0;
                        init_done_reg <= '1';
                        busy_reg <= '0';
                        state <= IDLE;
                    end if;

                --------------------------------------------------------------------------------
                -- IDLE STATE
                --------------------------------------------------------------------------------

                when IDLE =>
                    busy_reg <= '0';

                    if read_req = '1' then
                        state <= READ_ACTIVATE;
                        busy_reg <= '1';
                        cmd_counter <= 0;
                        data_in_reg <= (others => '0');
                    elsif write_req = '1' then
                        state <= WRITE_ACTIVATE;
                        busy_reg <= '1';
                        cmd_counter <= 0;
                        data_in_reg <= data_in;
                    end if;

                --------------------------------------------------------------------------------
                -- REFRESH CYCLE
                --------------------------------------------------------------------------------

                when REFRESH =>
                    cmd <= CMD_REFRESH;
                    busy_reg <= '1';
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter >= tRC then
                        cmd_counter <= 0;
                        refresh_counter <= 0;
                        state <= IDLE;
                    end if;

                --------------------------------------------------------------------------------
                -- READ OPERATION
                --------------------------------------------------------------------------------

                when READ_ACTIVATE =>
                    -- Activate row
                    cmd <= CMD_ACTIVE;
                    sdram_addr <= row_addr;
                    state <= READ_WAIT_RCD;
                    cmd_counter <= 0;

                when READ_WAIT_RCD =>
                    -- Wait tRCD (RAS to CAS delay)
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter >= tRCD then
                        state <= READ_CAS;
                        cmd_counter <= 0;
                    end if;

                when READ_CAS =>
                    -- Issue READ command
                    cmd <= CMD_READ;
                    sdram_addr <= "000" & col_addr;
                    sdram_addr(10) <= '0';  -- No auto-precharge
                    state <= READ_WAIT_DATA;
                    cmd_counter <= 0;

                when READ_WAIT_DATA =>
                    -- Wait for CAS latency
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter = CAS_LATENCY then
                        data_out_reg <= sdram_dq;  -- Capture data
                        state <= READ_COMPLETE;
                    end if;

                when READ_COMPLETE =>
                    data_valid <= '1';
                    state <= PRECHARGE_WAIT;
                    cmd_counter <= 0;

                --------------------------------------------------------------------------------
                -- WRITE OPERATION
                --------------------------------------------------------------------------------

                when WRITE_ACTIVATE =>
                    -- Activate row
                    cmd <= CMD_ACTIVE;
                    sdram_addr <= row_addr;
                    state <= WRITE_WAIT_RCD;
                    cmd_counter <= 0;

                when WRITE_WAIT_RCD =>
                    -- Wait tRCD
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter >= tRCD then
                        state <= WRITE_CAS;
                        cmd_counter <= 0;
                    end if;

                when WRITE_CAS =>
                    -- Issue WRITE command
                    cmd <= CMD_WRITE;
                    sdram_addr <= "000" & col_addr;
                    sdram_addr(10) <= '0';  -- No auto-precharge
                    dq_out <= data_in_reg;
                    dq_oe <= '1';
                    state <= WRITE_COMPLETE;

                when WRITE_COMPLETE =>
                    dq_oe <= '0';
                    state <= PRECHARGE_WAIT;
                    cmd_counter <= 0;

                --------------------------------------------------------------------------------
                -- PRECHARGE (close row)
                --------------------------------------------------------------------------------

                when PRECHARGE_WAIT =>
                    cmd <= CMD_PRECHARGE;
                    sdram_addr(10) <= '1';  -- All banks
                    cmd_counter <= cmd_counter + 1;

                    if cmd_counter >= tRP then
                        cmd_counter <= 0;
                        busy_reg <= '0';
                        state <= IDLE;
                    end if;

                when others =>
                    state <= IDLE;

            end case;

        end if;
    end process;

end Behavioral;
