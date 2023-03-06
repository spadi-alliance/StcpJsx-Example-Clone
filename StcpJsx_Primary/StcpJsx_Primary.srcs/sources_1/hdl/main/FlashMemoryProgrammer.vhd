library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use mylib.defBCT.all;
use mylib.defFMP.all;
use mylib.defSPI_IF.all;

Library xpm;
use xpm.vcomponents.all;

entity FlashMemoryProgrammer is
  port(
    rst	                : in std_logic;
    clk	                : in std_logic;
    clkSpi              : in std_logic;

    -- Module output --
    CS_SPI              : out std_logic;
--    SCLK_SPI            : out std_logic;
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
end FlashMemoryProgrammer;

architecture RTL of FlashMemoryProgrammer is
  attribute mark_debug        : string;

  -- System --
  signal sync_reset           : std_logic;
  signal sync_reset_spi       : std_logic;

  -- internal signal declaration --------------------------------------

  -- SPI flash memory --
  signal regspi_ctrl          : std_logic_vector(kWidthCtrl-1 downto 0);
  signal regspi_mode          : ModeType;

  signal chip_select          : std_logic;

  signal i_register           : std_logic_vector(kWidthIndexReg-1 downto 0);

  signal length_inst          : std_logic_vector(kWidthInst-1 downto 0);
  signal regspi_length_inst   : std_logic_vector(length_inst'range);

  signal length_read          : std_logic_vector(kWidthRead-1 downto 0);
  signal regspi_length_read   : std_logic_vector(length_read'range);

  signal length_write         : std_logic_vector(kWidthWrite-1 downto 0);
  signal regspi_length_write  : std_logic_vector(length_write'range);

  signal start_a_cycle        : std_logic;
  signal busy_cycle           : std_logic;

  signal start_spi_if         : std_logic;
  signal busy_spi_if          : std_logic;
  signal busy_spi_if_prev     : std_logic;
  signal edge_busy_spi_if     : std_logic_vector(1 downto 0);
  signal din_spi_if           : std_logic_vector(kWidthDataPerCycle-1 downto 0);
  signal dout_spi_if          : std_logic_vector(kWidthDataPerCycle-1 downto 0);
  signal regspi_dout_spi      : std_logic_vector(kWidthDataPerCycle-1 downto 0);

  type RegisterArray is array(integer range kNumArray-1 downto 0)
    of std_logic_vector(din_spi_if'range);
  signal regspi_din_spi       : RegisterArray;

  type ProgramProcessType is
    (Idle, SetChipSelect,
     DoInstruction, WaitInst,
     ReadData, WaitRead,
     WriteData, WaitWrite,
     Finalize
     );
  signal state_prog : ProgramProcessType;

  -- cdc --
  signal we_rd_fifo           : std_logic;
  signal re_rd_fifo           : std_logic;
  signal dout_rd_fifo         : std_logic_vector(dout_spi_if'range);
  signal rcount_rd_fifo       : std_logic_vector(length_read'range);
  signal rvalid_rd_fifo       : std_logic;
  signal empty_rd_fifo        : std_logic;

  component fmp_rd_fifo
    port (
      rst             : in std_logic;
      wr_clk          : in std_logic;
      rd_clk          : in std_logic;
      din             : in std_logic_vector(dout_spi_if'range);
      wr_en           : in std_logic;
      rd_en           : in std_logic;
      dout            : out std_logic_vector(dout_spi_if'range);
      full            : out std_logic;
      empty           : out std_logic;
      valid           : out std_logic;
      rd_data_count   : out std_logic_vector(length_read'range);
      wr_rst_busy     : out std_logic;
      rd_rst_busy     : out std_logic
      );
  end component;

  signal we_wd_fifo           : std_logic;
  signal re_wd_fifo           : std_logic;
  signal din_wd_fifo          : std_logic_vector(din_spi_if'range);
  signal dout_wd_fifo         : std_logic_vector(din_spi_if'range);
  signal wcount_wd_fifo       : std_logic_vector(length_write'range);
  signal rvalid_wd_fifo       : std_logic;
  signal empty_wd_fifo        : std_logic;

  component fmp_wd_fifo
    port (
      rst             : in std_logic;
      wr_clk          : in std_logic;
      rd_clk          : in std_logic;
      din             : in std_logic_vector(din_spi_if'range);
      wr_en           : in std_logic;
      rd_en           : in std_logic;
      dout            : out std_logic_vector(din_spi_if'range);
      full            : out std_logic;
      empty           : out std_logic;
      valid           : out std_logic;
      wr_data_count   : out std_logic_vector(length_write'range);
      wr_rst_busy     : out std_logic;
      rd_rst_busy     : out std_logic
      );
  end component;

  -- Local bus --
  signal reg_ctrl           : std_logic_vector(kWidthCtrl-1 downto 0);
  signal reg_start_a_cycle  : std_logic;
  signal reg_busy_cycle     : std_logic;
  signal edge_busy_cycle    : std_logic_vector(1 downto 0);
  signal reg_length_inst    : std_logic_vector(length_inst'range);
  signal reg_length_read    : std_logic_vector(length_read'range);
  signal reg_length_write   : std_logic_vector(length_write'range);
  signal reg_din_spi        : RegisterArray;
  signal reg_status         : std_logic_vector(kWidthStatus-1 downto 0);

  type FMPBusProcessType is (
    Init, Idle, Connect,
    Write, Read,
    ReadFIFO,
    Execute, Finalize,
    Done
    );

  signal state_lbus	: FMPBusProcessType;

  -- debug --
  -- attribute mark_debug of i_register    : signal is "true";
  -- attribute mark_debug of length_inst   : signal is "true";
  -- attribute mark_debug of length_read   : signal is "true";
  -- attribute mark_debug of length_write  : signal is "true";
  -- attribute mark_debug of start_a_cycle : signal is "true";
  -- attribute mark_debug of busy_cycle    : signal is "true";
  -- attribute mark_debug of start_spi_if  : signal is "true";
  -- attribute mark_debug of busy_spi_if   : signal is "true";
  -- attribute mark_debug of din_spi_if    : signal is "true";
  -- attribute mark_debug of dout_spi_if   : signal is "true";
  -- attribute mark_debug of state_prog    : signal is "true";

--  attribute mark_debug of state_lbus     : signal is "true";
--  attribute mark_debug of we_wd_fifo     : signal is "true";
--  attribute mark_debug of din_wd_fifo    : signal is "true";
--  attribute mark_debug of wcount_wd_fifo : signal is "true";
--  attribute mark_debug of edge_busy_cycl : signal is "true";

-- =============================== body ===============================
begin

  ---------------------------------------------------------------------
  -- SPI clock domain
  ---------------------------------------------------------------------
  CS_SPI  <= chip_select;

  u_ProgramProcess : process(clkSpi, sync_reset_spi)
  begin
    if(sync_reset_spi = '1') then
      start_spi_if      <= '0';
      chip_select       <= '1';
      we_rd_fifo        <= '0';
      re_wd_fifo        <= '0';
      state_prog        <= Idle;
    elsif(clkSpi'event and clkSpi = '1') then
      case state_prog is
        when Idle =>
          start_spi_if      <= '0';
          busy_cycle        <= '0';
          chip_select       <= '1';
          we_rd_fifo        <= '0';
          re_wd_fifo        <= '0';
          i_register        <= kIndexInst;
          if(start_a_cycle = '1') then
            busy_cycle      <= '1';
            state_prog      <= SetChipSelect;
          end if;

        when SetChipSelect =>
          length_inst       <= regspi_length_inst;
          if(regspi_ctrl(kIndexDummyMode) = '0') then
            chip_select       <= '0';
          end if;
          state_prog        <= DoInstruction;

        when DoInstruction =>
          length_inst       <= length_inst -1;
          start_spi_if      <= '1';
          state_prog        <= WaitInst;

        when WaitInst =>
          start_spi_if      <= '0';
          if(edge_busy_spi_if = "10") then
            if(length_inst = 0) then
              case regspi_mode is
                when kIsReadMode =>
                  length_read   <= regspi_length_read;
                  i_register    <= kIndexRead;
                  state_prog    <= ReadData;
                when kIsWriteMode =>
                  re_wd_fifo    <= '1';
                  length_write  <= regspi_length_write;
                  i_register    <= kIndexWrite;
                  state_prog    <= WriteData;
                when kIsInstMode =>
                  state_prog    <= Finalize;
                when others =>
                  state_prog    <= Finalize;
              end case;
            else
              i_register    <= i_register + 1;
              state_prog    <= DoInstruction;
            end if;
          end if;

        when ReadData =>
          length_read       <= length_read -1;
          start_spi_if      <= '1';
          we_rd_fifo        <= '0';
          state_prog        <= WaitRead;

        when WaitRead =>
          start_spi_if      <= '0';
          if(edge_busy_spi_if = "10") then
            regspi_dout_spi <= dout_spi_if;
            we_rd_fifo      <= '1';
            if(length_read = 0) then
              state_prog    <= Finalize;
            else
              state_prog    <= ReadData;
            end if;
          end if;

        when WriteData =>
          length_write      <= length_write -1;
          start_spi_if      <= '1';
          re_wd_fifo        <= '0';
          state_prog        <= WaitWrite;

        when WaitWrite =>
          start_spi_if      <= '0';
          if(edge_busy_spi_if = "10") then
            if(length_write = 0) then
              state_prog    <= Finalize;
            else
              re_wd_fifo    <= '1';
              state_prog    <= WriteData;
            end if;
          end if;

        when Finalize =>
          busy_cycle        <= '0';
          chip_select       <= '1';
          we_rd_fifo        <= '0';
          re_wd_fifo        <= '1';
          i_register        <= kIndexInst;
          state_prog        <= Idle;

        when others =>
          state_prog        <= Idle;

      end case;

    end if;

  end process;

  din_spi_if  <= regspi_din_spi(conv_integer(i_register));

  edge_busy_spi_if  <= busy_spi_if_prev & busy_spi_if;
  process(clkSpi, sync_reset_spi)
  begin
    if(sync_reset_spi = '1') then
      busy_spi_if_prev  <= '0';
    elsif(clkSpi'event and clkSpi = '1') then
      busy_spi_if_prev  <= busy_spi_if;
    end if;
  end process;


  -- SPI interface --
  u_SPI_IF : entity mylib.SPI_IF
    port map(
      clk         => clkSpi,
      rst         => sync_reset_spi,

      dIn         => din_spi_if,
      dOut        => dout_spi_if,
      start       => start_spi_if,
      busy        => busy_spi_if,

--      sclkSpi     => SCLK_SPI,
      mosiSpi     => MOSI_SPI,
      misoSpi     => MISO_SPI
      );

  -- Reset sequence --
  u_reset_gen_spi   : entity mylib.ResetGen
    port map(rst, clkSpi, sync_reset_spi);


  ---------------------------------------------------------------------
  -- Clock domain crossing
  ---------------------------------------------------------------------
  u_cdc_start : xpm_cdc_pulse
    generic map ( DEST_SYNC_FF => 4, REG_OUTPUT => 1, RST_USED => 1, SIM_ASSERT_CHK => 0 )
    port map (
      src_clk  => clk,    src_rst => sync_reset,     src_pulse  => reg_start_a_cycle,
      dest_clk => clkSpi, dest_rst=> sync_reset_spi, dest_pulse => start_a_cycle
      );

  u_cdc_buty : xpm_cdc_pulse
    generic map ( DEST_SYNC_FF => 4, REG_OUTPUT => 1, RST_USED => 1, SIM_ASSERT_CHK => 0 )
    port map (
      src_clk  => clkSpi, src_rst => sync_reset_spi, src_pulse  => busy_cycle,
      dest_clk => clk,    dest_rst=> sync_reset,     dest_pulse => reg_busy_cycle
      );

  reg_status          <= "0000000" & reg_busy_cycle;
  regspi_din_spi      <= dout_wd_fifo & reg_din_spi(kNumArray-2 downto 0);

  regspi_mode   <= regspi_ctrl(kIsReadMode'range);
  process(sync_reset_spi, clkSpi)
  begin
    if(sync_reset_spi = '1') then
      regspi_ctrl         <= (others => '0');
      regspi_length_inst  <= (others => '0');
      regspi_length_read  <= (others => '0');
      regspi_length_write <= (others => '0');
    elsif(clkSpi'event and clkSpi = '1') then
      regspi_ctrl         <= reg_ctrl;
      regspi_length_inst  <= reg_length_inst;
      regspi_length_read  <= reg_length_read;
      regspi_length_write <= reg_length_write;
    end if;
  end process;


  -- read buffer --
  u_RD_FIFO : fmp_rd_fifo
    port map(
      rst             => sync_reset,
      wr_clk          => clkSpi,
      rd_clk          => clk,
      din             => regspi_dout_spi,
      wr_en           => we_rd_fifo,
      rd_en           => re_rd_fifo,
      dout            => dout_rd_fifo,
      full            => open,
      empty           => empty_rd_fifo,
      valid           => rvalid_rd_fifo,
      rd_data_count   => rcount_rd_fifo,
      wr_rst_busy     => open,
      rd_rst_busy     => open
      );

  -- write buffer --
  u_WD_FIFO : fmp_wd_fifo
    port map(
      rst             => sync_reset,
      wr_clk          => clk,
      rd_clk          => clkSpi,
      din             => din_wd_fifo,
      wr_en           => we_wd_fifo,
      rd_en           => re_wd_fifo,
      dout            => dout_wd_fifo,
      full            => open,
      empty           => open,
      valid           => open,
      wr_data_count   => wcount_wd_fifo,
      wr_rst_busy     => open,
      rd_rst_busy     => open
      );


  ---------------------------------------------------------------------
  -- System clock domain
  ---------------------------------------------------------------------

  -- Local bus process ------------------------------------------------
  u_BusProcess : process(clk, sync_reset)
  begin
    if(sync_reset = '1') then
      reg_start_a_cycle   <= '0';
      reg_length_inst     <= (others => '0');
      reg_length_read     <= (others => '0');
      reg_length_write    <= (others => '0');
      re_rd_fifo          <= '0';
      we_wd_fifo          <= '0';
      reg_ctrl            <= (others => '0');
      state_lbus	        <= Init;
    elsif(clk'event and clk = '1') then
      case state_lbus is
        when Init =>
          reg_start_a_cycle   <= '0';
          reg_length_inst     <= (others => '0');
          reg_length_read     <= (others => '0');
          reg_length_write    <= (others => '0');
          re_rd_fifo          <= '0';
          we_wd_fifo          <= '0';
          reg_ctrl            <= (others => '0');
          dataLocalBusOut     <= x"00";
          readyLocalBus		    <= '0';
          state_lbus		      <= Idle;

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
            when kCtrl(kNonMultiByte'range) =>
              reg_ctrl    <= dataLocalBusIn;
              state_lbus	<= Done;

            when kRegister(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                reg_din_spi(conv_integer(kIndexInst))	  <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                reg_din_spi(conv_integer(kIndexAddr3))	<= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                reg_din_spi(conv_integer(kIndexAddr2))	<= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                reg_din_spi(conv_integer(kIndexAddr1))	<= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                reg_din_spi(conv_integer(kIndexAddr0))	<= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                reg_din_spi(conv_integer(kIndexDummy))  <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                reg_din_spi(conv_integer(kIndexRead))	  <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                reg_din_spi(conv_integer(kIndexWrite))	<= dataLocalBusIn;
              else
                reg_din_spi(conv_integer(kIndexWrite))	<= dataLocalBusIn;
              end if;
              state_lbus	<= Done;

            when kInstLength(kNonMultiByte'range) =>
              reg_length_inst   <= dataLocalBusIn(reg_length_inst'range);
              state_lbus	<= Done;

            when kReadLength(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                reg_length_read(7 downto 0) <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                reg_length_read(kWidthRead-1 downto 8) <= dataLocalBusIn(kWidthRead-1-8 downto 0);
              else
              end if;
              state_lbus	<= Done;

            when kWriteLength(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                reg_length_write(7 downto 0) <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                reg_length_write(kWidthWrite-1 downto 8) <= dataLocalBusIn(kWidthWrite-1-8 downto 0);
              else
              end if;
              state_lbus	<= Done;

            when kWriteFIFO(kNonMultiByte'range) =>
              din_wd_fifo   <= dataLocalBusIn;
              we_wd_fifo    <= '1';
              state_lbus    <= Done;

            when kExecute(kNonMultiByte'range) =>
              state_lbus	<= Execute;

            when others =>
              state_lbus	<= Done;
          end case;

        when Read =>
          case addrLocalBus(kNonMultiByte'range) is
            when kStatus(kNonMultiByte'range) =>
              dataLocalBusOut <= reg_status;
              state_lbus	    <= Done;

            when kCtrl(kNonMultiByte'range) =>
              dataLocalBusOut <= reg_ctrl;
              state_lbus	    <= Done;

            when kRegister(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexInst));
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexAddr3));
              elsif( addrLocalBus(kMultiByte'range) = k3rdbyte) then
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexAddr2));
              elsif( addrLocalBus(kMultiByte'range) = k4thbyte) then
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexAddr1));
              elsif( addrLocalBus(kMultiByte'range) = k5thbyte) then
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexAddr0));
              elsif( addrLocalBus(kMultiByte'range) = k6thbyte) then
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexDummy));
              elsif( addrLocalBus(kMultiByte'range) = k7thbyte) then
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexRead));
              elsif( addrLocalBus(kMultiByte'range) = k8thbyte) then
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexWrite));
              else
                dataLocalBusOut <= reg_din_spi(conv_integer(kIndexWrite));
              end if;
              state_lbus	<= Done;

            when kInstLength(kNonMultiByte'range) =>
              dataLocalBusOut(reg_length_inst'range) <= reg_length_inst;
              state_lbus	<= Done;

            when kReadLength(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                dataLocalBusOut  <= reg_length_read(7 downto 0);
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                dataLocalBusOut  <= kZeroVector(7 downto kWidthRead-8) & reg_length_read(kWidthRead-1 downto 8);
              else
              end if;
              state_lbus	<= Done;

            when kWriteLength(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                dataLocalBusOut   <= reg_length_read(7 downto 0);
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                dataLocalBusOut  <= kZeroVector(7 downto kWidthWrite-8) & reg_length_read(kWidthWrite-1 downto 8);
              else
              end if;
              state_lbus	<= Done;

            when kReadCountFIFO(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                dataLocalBusOut   <= rcount_rd_fifo(7 downto 0);
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                dataLocalBusOut  <= kZeroVector(7 downto kWidthRead-8) & rcount_rd_fifo(kWidthRead-1 downto 8);
              else
              end if;
              state_lbus	<= Done;

            when kWriteCountFIFO(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stbyte) then
                dataLocalBusOut   <= wcount_wd_fifo(7 downto 0);
              elsif( addrLocalBus(kMultiByte'range) = k2ndbyte) then
                dataLocalBusOut  <= kZeroVector(7 downto kWidthWrite-8) & wcount_wd_fifo(kWidthWrite-1 downto 8);
              else
              end if;
              state_lbus	<= Done;

            when kReadFIFO(kNonMultiByte'range) =>
              if(empty_rd_fifo = '1') then
                dataLocalBusOut   <= X"ee";
                state_lbus        <= Done;
              else
                re_rd_fifo        <= '1';
                state_lbus	      <= ReadFIFO;
              end if;

            when others => null;
          end case;

        when ReadFIFO =>
          re_rd_fifo <= '0';
          if(rvalid_rd_fifo = '1') then
            dataLocalBusOut   <= dout_rd_fifo;
            state_lbus        <= Done;
          end if;

        when Execute =>
          if(reg_busy_cycle = '0') then
            reg_start_a_cycle   <= '1';
            state_lbus          <= Finalize;
          end if;

        when Finalize =>
          reg_start_a_cycle <= '0';
          state_lbus        <= Done;

        when Done =>
          we_wd_fifo    <= '0';
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

