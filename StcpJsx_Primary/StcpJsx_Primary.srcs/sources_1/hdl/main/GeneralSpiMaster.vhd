---------------------------------------------------------------------
-- General spi master module
-- (CPHA, CPOL) = (0, 0) or (1, 1) modes are supported, that is,
-- latch data at the rising edge and shift data at the falling edge.
--
-- (CPHA, CPOL) = (1, 0) or (0, 1) are NOT suppoerted.
---------------------------------------------------------------------


LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY GeneralSpiMaster IS
  GENERIC(
    freqSysClk : integer := 50_000_000; --input clock speed from user logic in Hz
    freqBusClk : integer := 400_000;    --speed the i2c bus (scl) will run at in Hz
    widthData  : integer := 32;         --Data width per cycle
    cpol       : std_logic := '0';      --SPI clock polarity
    cpha       : std_logic := '0'       --SPI clock phase
    );
  PORT(
    -- System --
    clk       : in     std_logic;                    --system clock
    reset     : in     std_logic;                    --active high reset
    start     : in     std_logic;                    --run spi cycle
    dataWr    : in     std_logic_vector(widthData-1 DOWNTO 0); --data to write to slave
    dataRd    : out    std_logic_vector(widthData-1 DOWNTO 0); --data read from slave
    busy      : out    std_logic;                    --indicates transition in progress
    errorBit  : out    std_logic;                    --indicate setting unsupported (cpol, cpha)

    -- SPI port --
    csb       : out    std_logic;
    sclk      : out    std_logic;                    --SPI clock
    mosi      : out    std_logic;                    --Master-out-slave-in
    miso      : in     std_logic);                   --Master-in-slave-out
END GeneralSpiMaster;

ARCHITECTURE logic OF GeneralSpiMaster IS
  attribute mark_debug  : string;

  CONSTANT divider  :  integer := (freqSysClk/freqBusClk)/4; --number of clocks in 1/4 cycle of sck
  TYPE machine IS(ready, startSeq, command, stopSeq, finalize); --needed states
  signal state         : machine;                        --state machine
  signal data_clk      : std_logic;                      --data clock for sda
  signal data_clk_prev : std_logic;                      --data clock during previous system clock
  signal sck_clk       : std_logic;                      --constantly running internal sck
  signal sck_ena       : std_logic := '0';               --enables internal sck to output
  signal mosi_int      : std_logic := '0';               --internal sda
  signal data_tx       : std_logic_vector(widthData-1 DOWNTO 0);   --latched in data to write to slave
  signal data_rx       : std_logic_vector(widthData-1 DOWNTO 0);   --data received from slave
  signal bit_cnt       : integer RANGE 0 TO widthData-1 := widthData-1;      --tracks bit number in transaction

  signal spi_mode      : std_logic_vector(1 downto 0);

  -- debug --
  -- attribute mark_debug of state   : signal is "true";
  -- attribute mark_debug of data_clk: signal is "true";
  -- attribute mark_debug of sck_clk : signal is "true";
  -- attribute mark_debug of sck_ena : signal is "true";
  -- attribute mark_debug of mosi_int: signal is "true";
  -- attribute mark_debug of csb     : signal is "true";
  -- attribute mark_debug of data_tx : signal is "true";
  -- attribute mark_debug of data_rx : signal is "true";

BEGIN

  spi_mode  <= cpha & cpol;
  errorBit  <= '1' when(spi_mode = "01" or spi_mode = "10") else '0';

  --generate the timing for the bus clock (sck_clk) and the data clock (data_clk)
  PROCESS(clk, reset)
    VARIABLE count  :  integer RANGE 0 TO divider*4;  --timing for clock generation
  BEGIN
    IF(reset = '1') THEN                --reset asserted
      count := 0;
    ELSIF(clk'EVENT AND clk = '1') THEN
      data_clk_prev <= data_clk;          --store previous value of data clock
      IF(count = divider*4-1) THEN        --end of timing cycle
        count := 0;                       --reset timer
      ELSE
        count := count + 1;               --continue clock generation timing
      END IF;
      CASE count IS
        WHEN 0 TO divider-1 =>            --first 1/4 cycle of clocking
          sck_clk   <= '0';
          data_clk  <= '0';
        WHEN divider TO divider*2-1 =>    --second 1/4 cycle of clocking
          sck_clk   <= '0';
          data_clk  <= '1';
        WHEN divider*2 TO divider*3-1 =>  --third 1/4 cycle of clocking
          sck_clk   <= '1';
          data_clk  <= '1';
        WHEN OTHERS =>                    --last 1/4 cycle of clocking
          sck_clk   <= '1';
          data_clk  <= '0';
      END CASE;
    END IF;
  END PROCESS;

  --state machine and writing to sda during sck low (data_clk rising edge)
  PROCESS(clk, reset)
  BEGIN
    IF(reset = '1') THEN                     --reset asserted
      state     <= ready;                    --return to initial state
      csb       <= '1';                      --chip select bar
      busy      <= '1';                      --indicate not available
      sck_ena   <= '0';                      --sets sck high impedance
      mosi_int  <= '0';                      --sets sda high impedance
      bit_cnt   <= widthData-1;              --restarts data bit counter
      dataRd    <= (others => '0');          --clear data read port
    ELSIF(clk'EVENT AND clk = '1') THEN
      IF(data_clk = '1' AND data_clk_prev = '0') THEN  --data clock rising edge
        CASE state IS
          WHEN ready =>                      --idle state
            IF(start = '1') THEN             --transaction requested
              busy    <= '1';                --flag busy
              data_tx <= dataWr;             --collect requested data to write
              csb     <= '0';                --enable slave chip
              state   <= startSeq;           --go to start bit
            ELSE                             --remain idle
              busy    <= '0';                --unflag busy
              state   <= ready;              --remain idle
            END IF;
          WHEN startSeq =>                   --start bit of transaction
            busy      <= '1';                --resume busy if continuous mode
            mosi_int  <= data_tx(bit_cnt);   --set first address bit to bus
            if(spi_mode = "00") then
              sck_ena   <= '1';              --enable sck output
            end if;
            state     <= command;            --go to command
          WHEN command =>                    --address and command byte of transaction
            IF(bit_cnt = 0) THEN             --command transmit finished
--              mosi_int <= '1';             --release sda for slave acknowledge
              bit_cnt <= widthData-1;        --reset bit counter for "byte" states
              if(spi_mode = "00") then
                sck_ena   <= '0';            --enable sck output
              end if;
              state   <= stopSeq;             --go to slave acknowledge (command)
            ELSE                              --next clock cycle of command state
              bit_cnt <= bit_cnt - 1;         --keep track of transaction bits
              mosi_int <= data_tx(bit_cnt-1); --write address/command bit to bus
              state   <= command;             --continue with command
            END IF;
          WHEN stopSeq =>                    --stop bit of transaction
            csb       <= '1';                --disable slave
            dataRd    <= data_rx;            --latch rx-data
            state     <= finalize;           --go to finalize state
          when finalize =>
            busy      <= '0';                --unflag busy
            state     <= ready;              --go to idle state
        END CASE;
      ELSIF(data_clk = '0' AND data_clk_prev = '1') THEN  --data clock falling edge
        CASE state IS
          WHEN startSeq =>
            IF(sck_ena = '0' and spi_mode = "11") THEN  --starting new transaction
              sck_ena <= '1';                           --enable sck output
            END IF;
          WHEN command =>                               --receiving slave data
            data_rx(bit_cnt) <= miso;                   --receive current slave data bit
          WHEN stopSeq =>
            if(spi_mode = "11") then
              sck_ena <= '0';                           --disable sck
            end if;
          WHEN OTHERS =>
            NULL;
        END CASE;
      END IF;
    END IF;
  END PROCESS;

  --set sck and mosi outputs
  sclk <= '1' WHEN (sck_ena = '1' AND sck_clk = '1') ELSE '0';
  mosi <= mosi_int;

END logic;
