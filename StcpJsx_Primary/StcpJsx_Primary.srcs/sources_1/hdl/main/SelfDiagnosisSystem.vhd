library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use mylib.defBCT.all;
use mylib.defSDS.all;
use mylib.defSEM.all;

Library xpm;
use xpm.vcomponents.all;

entity SelfDiagnosisSystem is
  port(
    rst	                : in std_logic;
    clk	                : in std_logic;
    clkIcap             : in std_logic;

    -- Module input --
    VP                  : in std_logic; -- dummy input
    VN                  : in std_logic; -- dummy input

    -- Module output --
    shutdownOverTemp    : out std_logic;
    uncorrectableAlarm  : out std_logic;
--    alarmUserTemp       : out std_logic;
--    aralmUserVccint     : out std_logic;

    -- Local bus --
    addrLocalBus	      : in LocalAddressType;
    dataLocalBusIn	    : in LocalBusInType;
    dataLocalBusOut	    : out LocalBusOutType;
    reLocalBus		      : in std_logic;
    weLocalBus		      : in std_logic;
    readyLocalBus	      : out std_logic
    );
end SelfDiagnosisSystem;

architecture RTL of SelfDiagnosisSystem is
  attribute mark_debug        : string;

  -- System --
  signal sync_reset           : std_logic;
  signal sync_reset_icap      : std_logic;

  -- internal signal declaration --------------------------------------
  -- XADC -------------------------------------------------------------
  signal drp_dout             : std_logic_vector(kWidthDrpDIn -1 downto 0);
  signal reg_drp_enable       : std_logic;
  signal reg_drp_write_enable : std_logic;
  signal drp_ready            : std_logic;

  signal user_temp_alarm      : std_logic;
--  signal user_vccint_alarm    : std_logic;
  signal over_temp            : std_logic;

  component xadc_sys
    port (
      -- DRP --
      di_in         : in std_logic_vector(kWidthDrpDIn-1 downto 0);
      daddr_in      : in std_logic_vector(kWidthDrpAddr-1 downto 0);
      den_in        : in std_logic;
      dwe_in        : in std_logic;
      drdy_out      : out std_logic;
      do_out        : out std_logic_vector(kWidthDrpDOut-1 downto 0);
      dclk_in       : in std_logic;
      reset_in      : in std_logic;

      -- analog input --
      vp_in         : in std_logic;
      vn_in         : in std_logic;

      -- user temp. alarm --
      user_temp_alarm_out   : out std_logic;
      -- over temp. (system shutdown) --
      ot_out                : out std_logic;

      -- channel currently converting --
      channel_out   : out std_logic_vector(kWidthXadcCh-1 downto 0);
      -- End of conversion --
      eoc_out       : out std_logic;
      -- not in use --
      alarm_out     : out std_logic;
      -- End of (a) sequence
      eos_out       : out std_logic;
      -- ADC is running --
      busy_out      : out std_logic
      );
  end component;


  signal reg_drp_dout         : std_logic_vector(kWidthDrpDIn -1 downto 0);
  signal end_xadc_process     : std_logic;

  type XadcProcessType is
    (Idle,
     SetMode, DoRead, DoWrite, WaitRead,
     Finalize, Done
     );
  signal state_xadc : XadcProcessType;

  -- SEM controller ---------------------------------------------------
  signal status_out           : SemStatusType;
  signal rst_counter          : std_logic;
  signal strobe_error         : std_logic;
  signal address_error_injection : std_logic_vector(kWidthErrAddr-1 downto 0);

  -- Local bus --
  signal reg_sds_status       : std_logic_vector(kWidthStatus-1 downto 0);

  signal start_drp            : std_logic;
  signal reg_drp_mode         : std_logic;
  signal reg_drp_din          : std_logic_vector(kWidthDrpDIn -1 downto 0);
  signal reg_drp_addr         : std_logic_vector(kWidthDrpAddr -1 downto 0);

  signal reg_watchdog_alarm       : std_logic;
  signal reg_uncorrectable_alarm  : std_logic;
  signal reg_counter_correction   : std_logic_vector(kWidthCorrection-1 downto 0);
  signal reg_err_strobe           : std_logic;
  signal reg_err_inject_address   : std_logic_vector(kWidthErrAddr-1 downto 0);
  signal reg_rst_counter          : std_logic;

  signal state_lbus	          : BusProcessType;

  -- debug --
  -- attribute mark_debug of drp_dout              : signal is "true";
  -- attribute mark_debug of reg_drp_enable        : signal is "true";
  -- attribute mark_debug of reg_drp_write_enable  : signal is "true";
  -- attribute mark_debug of drp_ready             : signal is "true";
  -- attribute mark_debug of reg_drp_dout          : signal is "true";
  -- attribute mark_debug of end_xadc_process      : signal is "true";
  -- attribute mark_debug of start_drp             : signal is "true";
  -- attribute mark_debug of reg_drp_mode          : signal is "true";
  -- attribute mark_debug of reg_drp_addr          : signal is "true";
  -- attribute mark_debug of addrLocalBus          : signal is "true";
  -- attribute mark_debug of state_lbus           : signal is "true";

-- =============================== body ===============================
begin
  -- Module ports --
  shutdownOverTemp    <= over_temp;
  uncorrectableAlarm  <= reg_uncorrectable_alarm;

  process(clk, sync_reset)
  begin
    if(sync_reset = '1') then
      reg_sds_status  <= (others => '0');
    elsif(clk'event and clk = '1') then
      reg_sds_status  <= "00" &
                         reg_uncorrectable_alarm &
                         reg_watchdog_alarm &
                         "00" &
--                         user_vccint_alarm &
                         user_temp_alarm &
                         over_temp;
    end if;
  end process;

  -- XADC --
  u_xadc : xadc_sys
    port map(
      -- DRP --
      di_in         => reg_drp_din,
      daddr_in      => reg_drp_addr,
      den_in        => reg_drp_enable,
      dwe_in        => reg_drp_write_enable,
      drdy_out      => drp_ready,
      do_out        => drp_dout,
      dclk_in       => clk,
      reset_in      => sync_reset,

      -- analog input --
      vp_in         => VP,
      vn_in         => VN,

      -- user temp. alarm --
      user_temp_alarm_out   => user_temp_alarm,
      -- user vccint alarm --
--      vccint_alarm_out      => user_vccint_alarm,
      -- over temp. (system shutdown) --
      ot_out                => over_temp,

      -- channel currently converting --
      channel_out   => open,
      -- End of conversion --
--      eoc_out       => end_of_conversion,
      eoc_out       => open,
      -- not in use --
      alarm_out     => open,
      -- End of (a) sequence
      eos_out       => open,
      -- ADC is running --
      busy_out      => open
--      busy_out      => busy_xadc
      );

  u_XadcProcess : process(clk, sync_reset)
  begin
    if(sync_reset = '1') then
      state_xadc <= Idle;
    elsif(clk'event and clk = '1') then
      case state_xadc is
        when Idle =>
          reg_drp_enable        <= '0';
          reg_drp_write_enable  <= '0';
          end_xadc_process      <= '0';
          if(start_drp = '1') then
            state_xadc  <= SetMode;
          end if;

        when SetMode =>
          if(reg_drp_mode = kIsRead) then
            state_xadc  <= DoRead;
          else
            state_xadc  <= DoWrite;
          end if;

        when DoRead =>
          reg_drp_enable  <= '1';
          state_xadc      <= WaitRead;

        when DoWrite =>
          reg_drp_enable        <= '1';
          reg_drp_write_enable  <= '1';
          state_xadc            <= Finalize;

        when WaitRead =>
          reg_drp_enable        <= '0';
          if(drp_ready = '1') then
            reg_drp_dout        <= drp_dout;
            state_xadc          <= Finalize;
          end if;

        when Finalize =>
          reg_drp_enable        <= '0';
          reg_drp_write_enable  <= '0';
          end_xadc_process      <= '1';
          state_xadc            <= Done;

        when Done =>
          end_xadc_process  <= '0';
          state_xadc        <= Idle;

        when others =>
          state_xadc        <= Idle;

      end case;
    end if;
  end process;

  -- SEM controller --
  u_CdcWatchdog : xpm_cdc_single
   generic map (
      DEST_SYNC_FF => 4,    INIT_SYNC_FF => 0,
      SIM_ASSERT_CHK => 0,  SRC_INPUT_REG => 1
   )
   port map (
      dest_out => reg_watchdog_alarm, dest_clk => clk,
      src_clk  => clkIcap,            src_in   => status_out.watchdog_alarm
      );

  u_CdcUncorrectable : xpm_cdc_single
   generic map (
      DEST_SYNC_FF => 4,    INIT_SYNC_FF => 0,
      SIM_ASSERT_CHK => 0,  SRC_INPUT_REG => 1
   )
   port map (
      dest_out => reg_uncorrectable_alarm, dest_clk => clk,
      src_clk  => clkIcap, src_in   => status_out.uncorrectable_alarm
      );

  u_CdcCorCounter : xpm_cdc_array_single
   generic map (
      DEST_SYNC_FF => 4,  INIT_SYNC_FF => 0,
      SIM_ASSERT_CHK => 0, SRC_INPUT_REG => 1,
      WIDTH => kWidthCorrection
   )
   port map (
      dest_out => reg_counter_correction,  dest_clk => clk,
      src_clk => clkIcap,  src_in => status_out.counter_correction
      );

  u_CdcErrAddr : xpm_cdc_array_single
   generic map (
      DEST_SYNC_FF => 4,  INIT_SYNC_FF => 0,
      SIM_ASSERT_CHK => 0, SRC_INPUT_REG => 1,
      WIDTH => kWidthErrAddr
   )
   port map (
      dest_out => address_error_injection,  dest_clk => clkIcap,
      src_clk => clk, src_in => reg_err_inject_address
      );

  u_Strobe : xpm_cdc_pulse
   generic map (
      DEST_SYNC_FF => 4, INIT_SYNC_FF => 0,  REG_OUTPUT => 0,
      RST_USED => 1,  SIM_ASSERT_CHK => 0
   )
   port map (
      dest_pulse => strobe_error,  dest_clk => clkIcap,
      dest_rst => sync_reset_icap,
      src_clk => clk,  src_pulse => reg_err_strobe,
      src_rst => sync_reset
      );

  u_RstCounter : xpm_cdc_pulse
   generic map (
      DEST_SYNC_FF => 4, INIT_SYNC_FF => 0,  REG_OUTPUT => 0,
      RST_USED => 1,  SIM_ASSERT_CHK => 0
   )
   port map (
      dest_pulse => rst_counter,  dest_clk => clkIcap,
      dest_rst => sync_reset_icap,
      src_clk => clk,  src_pulse => reg_rst_counter,
      src_rst => sync_reset
   );

  u_SEM : entity mylib.SemImpl
    port map(
      rst	                => sync_reset_icap,
      rstCounter          => reg_rst_counter,
      clkIcap             => clkIcap,

      -- module input --
      strobeErr           => strobe_error,
      addrErrInjection    => address_error_injection,

      -- module output --
      statusOut           => status_out
      );

  -- Local bus process ------------------------------------------------
  u_BusProcess : process(clk, sync_reset)
  begin
    if(sync_reset = '1') then
      start_drp           <= '0';
      reg_drp_mode        <= '0';
      reg_drp_din         <= (others => '0');
      reg_drp_addr        <= (others => '0');
      reg_err_strobe      <= '0';
      reg_err_inject_address  <= (others => '0');
      reg_rst_counter     <= '0';
      state_lbus	        <= Idle;
    elsif(clk'event and clk = '1') then
      case state_lbus is
        when Idle =>
          start_drp       <= '0';
          reg_err_strobe  <= '0';
          reg_rst_counter <= '0';

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
            when kXadcDrpMode(kNonMultiByte'range) =>
              reg_drp_mode    <= dataLocalBusIn(0);
              state_lbus	    <= Done;

            when kXadcDrpAddr(kNonMultiByte'range) =>
              reg_drp_addr    <= dataLocalBusIn(kWidthDrpAddr-1 downto 0);
              state_lbus	    <= Done;

            when kXadcDrpDin(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stByte) then
                reg_drp_din(LocalBusInType'range)	    <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k2ndByte) then
                reg_drp_din(kWidthDrpDIn-1 downto 8)  <= dataLocalBusIn;
              else
                reg_drp_din(LocalBusInType'range)	  <= dataLocalBusIn;
              end if;
              state_lbus	<= Done;

            when kXadcExecute(kNonMultiByte'range) =>
              state_lbus	<= Execute;

            when kSemRstCorCount(kNonMultiByte'range) =>
              reg_rst_counter <= '1';
              state_lbus	    <= Done;

            when kSemErrAddr(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stByte) then
                reg_err_inject_address(7 downto 0)  <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k2ndByte) then
                reg_err_inject_address(8*1 + 7 downto 8*1)  <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k3rdByte) then
                reg_err_inject_address(8*2 + 7 downto 8*2)  <= dataLocalBusIn;
              elsif( addrLocalBus(kMultiByte'range) = k4thByte) then
                reg_err_inject_address(8*3 + 7 downto 8*3)  <= dataLocalBusIn;
              else
                reg_err_inject_address(8*4 + 7 downto 8*4)  <= dataLocalBusIn;
              end if;
              state_lbus  <= Done;

            when kSemErrStrobe(kNonMultiByte'range) =>
              reg_err_strobe  <= '1';
              state_lbus	    <= Done;

            when others =>
              state_lbus	<= Done;
          end case;

        when Read =>
          case addrLocalBus(kNonMultiByte'range) is
            when kSdsStatus(kNonMultiByte'range) =>
              dataLocalBusOut <= reg_sds_status;
              state_lbus	    <= Done;

            when kXadcDrpMode(kNonMultiByte'range) =>
              dataLocalBusOut <= "0000000" & reg_drp_mode;
              state_lbus	    <= Done;

            when kXadcDrpAddr(kNonMultiByte'range) =>
              dataLocalBusOut <= '0' & reg_drp_addr;
              state_lbus	    <= Done;

            when kXadcDrpDout(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stByte) then
                dataLocalBusOut   <= reg_drp_dout(LocalBusOutType'range);
              elsif( addrLocalBus(kMultiByte'range) = k2ndByte) then
                dataLocalBusOut   <= reg_drp_dout(kWidthDrpDout-1 downto 8);
              else
                dataLocalBusOut   <= X"ee";
              end if;
              state_lbus	<= Done;

            when kSemCorCount(kNonMultiByte'range) =>
              if( addrLocalBus(kMultiByte'range) = k1stByte) then
--                dataLocalBusOut   <= status_out.counter_correction(LocalBusOutType'range);
                dataLocalBusOut   <= reg_counter_correction(LocalBusOutType'range);
              elsif( addrLocalBus(kMultiByte'range) = k2ndByte) then
--                dataLocalBusOut   <= status_out.counter_correction(kWidthCorrection-1 downto 8);
                dataLocalBusOut   <= reg_counter_correction(kWidthCorrection-1 downto 8);
              else
                dataLocalBusOut   <= X"ee";
              end if;
              state_lbus	<= Done;

            when others => null;
          end case;

        when Execute =>
          start_drp       <= '1';
          state_lbus      <= Finalize;

        when Finalize =>
          start_drp       <= '0';
          if(end_xadc_process = '1') then
            state_lbus      <= Done;
          end if;

        when Done =>
          readyLocalBus	<= '1';
          if(weLocalBus = '0' and reLocalBus = '0') then
            state_lbus	<= Idle;
          end if;

        -- probably this is error --
        when others =>
          state_lbus	<= Idle;
      end case;
    end if;
  end process u_BusProcess;

  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clk, sync_reset);

  u_reset_gen_icap   : entity mylib.ResetGen
    port map(rst, clkIcap, sync_reset_icap);

end RTL;

