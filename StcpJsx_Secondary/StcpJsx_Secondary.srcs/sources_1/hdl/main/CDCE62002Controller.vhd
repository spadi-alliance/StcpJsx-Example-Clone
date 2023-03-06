library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;
use mylib.defBCT.all;
use mylib.defC6C.all;

library UNISIM;
use UNISIM.VComponents.all;

entity CDCE62002Controller is
  port(
    rst	                : in std_logic;
    clk	                : in std_logic;
    refClkIn            : in std_logic;

    chipReset           : in std_logic;
    clkIndep            : in std_logic;
    chipLock            : in std_logic;

    -- Module output --
    PDB                 : out std_logic;
    REF_CLKP            : out std_logic;
    REF_CLKN            : out std_logic;
    CSB_SPI             : out std_logic;
    SCLK_SPI            : out std_logic;
    MOSI_SPI            : out std_logic;
    MISO_SPI            : in  std_logic;

    -- Local bus --
    addrLocalBus	      : in LocalAddressType;
    dataLocalBusIn	    : in LocalBusInType;
    dataLocalBusOut	    : out LocalBusOutType;
    reLocalBus		      : in std_logic;
    weLocalBus		      : in std_logic;
    readyLocalBus	      : out std_logic
    );
end CDCE62002Controller;

architecture RTL of CDCE62002Controller is
  attribute mark_debug        : string;

  -- System --
  signal sync_reset           : std_logic;

  signal rst_counter          : std_logic_vector(kWidthRstCnt-1 downto 0);
  signal rst_shiftreg         : std_logic_vector(kWidthRstSr-1 downto 0);
  signal sync_lock            : std_logic;
  signal rst_msb_edge         : std_logic;

  -- internal signal declaration --------------------------------------
  -- start-up --
  constant kLengthTimer       : positive:= 16;
  signal timer_counter        : std_logic_vector(kLengthTimer-1 downto 0);
  signal en_ref_clk           : std_logic;
  signal ref_cdce             : std_logic;

  -- GSPI-IF --
  signal busy_cycle           : std_logic;
  signal reg_busy_cycle       : std_logic_vector(1 downto 0);

  signal start_spi_if         : std_logic;
  signal read_phase           : std_logic;
  signal busy_if              : std_logic;
  signal reg_txd_if           : std_logic_vector(kWidthSpi-1 downto 0);
  signal rxd_if               : std_logic_vector(kWidthSpi-1 downto 0);

  signal csb_if               : std_logic;
  signal sclk_if              : std_logic;
  signal mosi_if              : std_logic;
  signal miso_if              : std_logic;

  signal state_spi : SpiIfProcessType;

  -- Local bus --
  signal start_a_cycle      : std_logic;
  signal mode_read          : std_logic;
  signal reg_txd_lbus       : std_logic_vector(kWidthSpi-1 downto 0);
  signal reg_rxd_lbus       : std_logic_vector(kWidthSpi-1 downto 0);

  signal state_lbus	: C6CBusProcessType;

  -- debug --
--  attribute mark_debug of state_spi    : signal is "true";
--  attribute mark_debug of read_phase   : signal is "true";
--  attribute mark_debug of busy_if      : signal is "true";
--  attribute mark_debug of busy_cycle   : signal is "true";
--  attribute mark_debug of reg_txd_if   : signal is "true";
--  attribute mark_debug of rxd_if       : signal is "true";
--  attribute mark_debug of state_lbus   : signal is "true";

-- =============================== body ===============================
begin
  ---------------------------------------------------------------------
  -- CDCE62002 start-up pocess
  ---------------------------------------------------------------------
  -- Auto reset sequence --
  PDB       <= not (chipReset or rst_shiftreg(kWidthRstSr-1));

  u_sync : entity mylib.synchronizer
    port map( clkIndep, chipLock, sync_lock );

  u_rst_cnt : process(sync_lock, clkIndep)
  begin
    if(clkIndep'event and clkIndep = '1') then
      if(sync_lock = '1') then
        rst_counter   <= (others => '0');
      else
        rst_counter   <= std_logic_vector( unsigned(rst_counter) +1);
      end if;
    end if;
  end process;

  u_edge_rst : entity mylib.EdgeDetector
    port map('0', clkIndep, rst_counter(kWidthRstCnt-1), rst_msb_edge);

  u_rst_sr : process(clkIndep)
  begin
    if(clkIndep'event and clkIndep = '1') then
      if(rst_msb_edge = '1') then
        rst_shiftreg  <= (others => '1');
      else
        rst_shiftreg  <= rst_shiftreg(kWidthRstSr-2 downto 0) & '0';
      end if;
    end if;
  end process;

  -- Main --
  ODDR_inst : ODDR
   generic map(
      DDR_CLK_EDGE => "OPPOSITE_EDGE",
      INIT => '0',
      SRTYPE => "SYNC")
   port map (
      Q  => ref_cdce,   -- 1-bit DDR output
      C  => refClkIn,    -- 1-bit clock input
      CE => '1',  -- 1-bit clock enable input
      D1 => '1',  -- 1-bit data input (positive edge)
      D2 => '0',  -- 1-bit data input (negative edge)
      R  => '0',    -- 1-bit reset input
      S  => '0'     -- 1-bit set input
      );

  OBUFDS_inst : OBUFDS
   generic map (
      IOSTANDARD => "LVDS_25", -- Specify the output I/O standard
      SLEW => "FAST")          -- Specify the output slew rate
   port map (
      O  => REF_CLKP,     -- Diff_p output (connect directly to top-level port)
      OB => REF_CLKN,     -- Diff_n output (connect directly to top-level port)
      I  => ref_cdce      -- Buffer input
      );

  ---------------------------------------------------------------------
  -- GSPI-IF controller
  -- CDCE62002 SPI mode is (CPHA, CPOL) = (0, 0).
  ---------------------------------------------------------------------

  CSB_SPI   <= csb_if;
  SCLK_SPI  <= sclk_if;
  MOSI_SPI  <= mosi_if;
  miso_if   <= MISO_SPI;

  u_IfProcess : process(clk, sync_reset)
    variable count : integer range 0 to kLengthInterval;
  begin
    if(sync_reset = '1') then
      count             := kLengthInterval;
      start_spi_if      <= '0';
      busy_cycle        <= '0';
      read_phase        <= '0';
      reg_rxd_lbus      <= (others => '0');
      state_spi         <= Idle;
    elsif(clk'event and clk = '1') then
      case state_spi is
        when Idle =>
          start_spi_if      <= '0';
          read_phase        <= '0';

          if(start_a_cycle = '1') then
            busy_cycle      <= '1';
            reg_txd_if      <= reg_txd_lbus;
            start_spi_if    <= '1';
            state_spi       <= StartIF;
          end if;

        when StartIF =>
          if(busy_if = '1') then
            start_spi_if  <= '0';
            state_spi     <= WaitCommandDone;
          end if;

        when WaitCommandDone =>
          if(busy_if = '0') then
            if(mode_read = '1' and read_phase = '0') then
              count         := kLengthInterval-1;
              read_phase    <= '1';
              state_spi     <= Interval;
            else
              reg_rxd_lbus  <= rxd_if;
              state_spi     <= Finalize;
            end if;
          end if;

        when Interval =>
          count   := count - 1;
          if(count = 0) then
            start_spi_if  <= '1';
            state_spi     <= StartIF;
          end if;

        when Finalize =>
          busy_cycle  <= '0';
          read_phase  <= '0';
          state_spi   <= Idle;

        when others =>
          state_spi        <= Idle;

      end case;
    end if;
  end process;

  u_reg_busy : process(clk)
  begin
    if(clk'event and clk = '1') then
      reg_busy_cycle  <= reg_busy_cycle(0) & busy_cycle;
    end if;
  end process;

  u_GSPI_IF : entity mylib.GeneralSpiMaster
    generic map(
      freqSysClk => kSysClkFreq,
      freqBusClk => kSpiClkFreq,
      widthData  => kWidthSpi,
      cpol       => kCpol,
      cpha       => kCpha
      )
    port map(
      -- System --
      clk       => clk,
      reset     => sync_reset,
      start     => start_spi_if,
      dataWr    => reg_txd_if,
      dataRd    => rxd_if,
      busy      => busy_if,
      errorBit  => open,

      -- SPI port --
      csb       => csb_if,
      sclk      => sclk_if,
      mosi      => mosi_if,
      miso      => miso_if
      );


  ---------------------------------------------------------------------
  -- Local bus process
  ---------------------------------------------------------------------
  u_BusProcess : process(clk, sync_reset)
  begin
    if(sync_reset = '1') then
      start_a_cycle   <= '0';
      mode_read       <= '0';
      reg_txd_lbus    <= (others => '0');
      state_lbus	    <= Init;
    elsif(clk'event and clk = '1') then
      case state_lbus is
        when Init =>
          start_a_cycle   <= '0';
          reg_txd_lbus    <= (others => '0');
          dataLocalBusOut <= x"00";
          readyLocalBus		<= '0';
          state_lbus		  <= Idle;

        when Idle =>
          readyLocalBus	<= '0';
          if(weLocalBus = '1' or reLocalBus = '1') then
            state_lbus	<= Connect;
          end if;

        when Connect =>
          if(weLocalBus = '1') then
            state_lbus	<= Write;
          else
            state_lbus	<= Read;
          end if;

        when Write =>
          case addrLocalBus(kNonMultiByte'range) is
            when kTxd(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                reg_txd_lbus(7 downto 0)	  <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                reg_txd_lbus(15 downto 8)	  <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                reg_txd_lbus(23 downto 16)	<= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                reg_txd_lbus(31 downto 24)	<= dataLocalBusIn;
              else
                reg_txd_lbus(31 downto 24)	<= dataLocalBusIn;
              end if;
              state_lbus	 <= Done;

            when kExecWrite(kNonMultiByte'range) =>
              state_lbus	 <= ExecuteWrite;

            when others =>
              state_lbus	<= Done;
          end case;

        when Read =>
          case addrLocalBus(kNonMultiByte'range) is
            when kRxd(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                dataLocalBusOut   <= reg_rxd_lbus(7 downto 0);
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                dataLocalBusOut   <= reg_rxd_lbus(15 downto 8);
              elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                dataLocalBusOut   <= reg_rxd_lbus(23 downto 16);
              elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                dataLocalBusOut   <= reg_rxd_lbus(31 downto 24);
              else
                dataLocalBusOut   <= reg_rxd_lbus(31 downto 24);
              end if;
              state_lbus	 <= Done;

            when kExecRead(kNonMultiByte'range) =>
              dataLocalBusOut   <= x"00";
              state_lbus	      <= ExecuteRead;

            when others => null;
          end case;

        when ExecuteWrite =>
          start_a_cycle   <= '1';
          mode_read       <= '0';
          state_lbus      <= WaitDone;

        when ExecuteRead =>
          start_a_cycle   <= '1';
          mode_read       <= '1';
          state_lbus      <= WaitDone;

        when WaitDone =>
          start_a_cycle   <= '0';
          if(reg_busy_cycle = "10") then
            state_lbus        <= Finalize;
          end if;

        when Finalize =>
          mode_read       <= '0';
          state_lbus      <= Done;

        when Done =>
          readyLocalBus	<= '1';
          if(weLocalBus = '0' and reLocalBus = '0') then
            state_lbus	<= Idle;
          end if;

        -- probably this is error --
        when others =>
          state_lbus	<= Init;
      end case;
    end if;
  end process u_BusProcess;

  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clk, sync_reset);

end RTL;

