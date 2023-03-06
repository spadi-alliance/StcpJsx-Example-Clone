library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defCDCM.all;

entity CbtLane is
  generic
    (
      -- CDCM-Mod-Pattern --
      kCdcmModWidth    : integer; -- # of time slices of the CDCM signal
      -- CDCM-TX --
      kIoStandardTx    : string;  -- IO standard of OBUFDS
      kTxPolarity      : boolean:= FALSE; -- true: inverse polarity
      -- CDCM-RX --
      genIDELAYCTRL    : boolean; -- If TRUE, IDELAYCTRL is instantiated.
      kDiffTerm        : boolean; -- IBUF DIFF_TERM
      kRxPolarity      : boolean; -- If true, inverts Rx polarity
      kIoStandardRx    : string;  -- IOSTANDARD of IBUFDS
      kIoDelayGroup    : string;  -- IODELAY_GROUP for IDELAYCTRL and IDELAY
      kFreqFastClk     : real;    -- Frequency of SERDES fast clock (MHz).
      kFreqRefClk      : real;    -- Frequency of refclk for IDELAYCTRL (MHz).
      -- Encoder/Decoder
      kNumEncodeBits   : integer:= 2;  -- 1:CDCM-10-1.5 or 2:CDCM-10-2.5
      -- Master/Slave
      kCbtMode         : string;
      -- DEBUG --
      enDebug          : boolean:= false
    );
  port
    (
      -- SYSTEM port --
      srst          : in std_logic; -- Asyncrhonous assert, syncrhonous deassert reset. (active high)
      clkSer        : in std_logic; -- From BUFG (5 x clkPar freq.)
      clkPar        : in std_logic; -- From BUFG
      clkIndep      : in std_logic; -- Independent clock for monitor
      clkIdelayRef  : in std_logic; -- REFCLK input for IDELAYCTRL. Must be independent from clkPar.
      clkIsReady    : in std_logic; -- Indicate that clkSer and clkPar are available.
      initIn        : in std_logic; -- Re-do the initialization process. Sync with clkPar.

      -- Status --
      cbtLaneUp     : out std_logic;

      -- Error --
      patternErr    : out std_logic; -- Indicates CDCM waveform pattern is collapsed.
      --idelayErr     : out std_logic; -- Attempted bitslip but the expected pattern was not found.
      bitslipErr    : out std_logic; -- Bit pattern which does not match the CDCM rule is detected.
      watchDogErr   : out std_logic; -- Watch dog can't eat dogfood within specified time. The other side seems to be down.

      -- Data I/F --
      isKTypeTx     : in std_logic; -- 1: Generate a K type character. 0: D type character.
      dataInTx      : in CbtUDataType;
      validInTx     : in std_logic; -- 1: charIn is valid. Encode and send it to CDCM-TX.
                                    -- 0: Send idle pattern;
      txBeat        : out std_logic; -- Indicates encoder cycle.
      txAck         : out std_logic; -- Acknowledge to validInTx.

      isIdleRx      : out std_logic; -- Indicates present character is idle.
      isKTypeRx     : out std_logic; -- 1: K type character. 0: D type character.
      dataOutRx     : out CbtUDataType;
      validOutRx    : out std_logic; -- 1: charOut is valid.

      -- CDCM ports --
      cdcmTxp       : out std_logic; -- Connect to TOPLEVEL port
      cdcmTxn       : out std_logic; -- Connect to TOPLEVEL port
      cdcmRxp       : in std_logic;  -- Connect to TOPLEVEL port
      cdcmRxn       : in std_logic;  -- Connect to TOPLEVEL port
      modClock      : out std_logic  -- CDCM modulated clock.

    );
end CbtLane;

architecture RTL of CbtLane is
  -- System --
  signal modulated_clock  : std_logic;
  signal clock_lost       : std_logic;
  signal clock_lost_indep : std_logic;
  signal sync_lost        : std_logic_vector(kSyncLength-1 downto 0);
  signal init_cdcm_rx     : std_logic;
  signal reg_init_cdcm_rx : std_logic;
  constant kNumDelay      : integer:= 1024;
  signal init_sr          : std_logic_vector(kNumDelay-1 downto 0);

  constant kDelayLaneUp   : positive:= 128;
  signal lane_up_sr       : std_logic_vector(kDelayLaneUp-1 downto 0);
  signal lane_up          : std_logic;

  -- RX quality check (clkIndep domain) --
  signal srst_indep       : std_logic;
  signal assert_init_indep, init_indep  : std_logic;
  signal valid_indep, patt_error_indep  : std_logic;
  signal lane_up_indep    : std_logic;

  signal sync_valid, sync_patterr, sync_lane_up, sync_rst : std_logic_vector(kSyncLength-1 downto 0);

  -- RX quality check (clkPar domain) --
  signal sync_init : std_logic_vector(kSyncLength-1 downto 0);
  signal init_from_rxquality  : std_logic;

  -- TX --
  signal cbt_tx_up        : std_logic;

  -- RX --
  signal decoder_bit_aligned  : std_logic;
  signal cbt_rx_up        : std_logic;
  signal back_ch_inst     : CbtBackChannelType;
  signal patterr_cbtrx    : std_logic;
  signal valid_cbtrx      : std_logic;
  signal watchdog_error   : std_logic;

  -- debug --
  attribute mark_debug  : boolean;
  attribute mark_debug  of clock_lost     : signal is enDebug;
  attribute mark_debug  of init_from_rxquality     : signal is enDebug;
  attribute mark_debug  of init_cdcm_rx   : signal is enDebug;
  attribute mark_debug  of lane_up        : signal is enDebug;

  attribute async_reg   : boolean;
  attribute async_reg   of u_par_to_ref   : label is true;
  attribute async_reg   of u_ref_to_par   : label is true;

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  -------------------------------------------------------------------------
  -- clkIndep clock domain
  -------------------------------------------------------------------------
  -- RX quality check by independent clock --
  u_rx_quality : process(clkPar)
    variable check_frame_counter  : integer range 0 to kCheckFrameLength-1;
    variable num_collapsed        : integer range 0 to kCheckFrameLength-1;
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst_indep = '1') then
        check_frame_counter   := 0;
        num_collapsed         := 0;
        assert_init_indep     <= '0';
      elsif(decoder_bit_aligned = '1') then
        check_frame_counter := check_frame_counter +1;
        if(check_frame_counter = kCheckFrameLength-1) then
          if(num_collapsed > kLowQualityTh) then
            assert_init_indep   <= '1';
          end if;
          num_collapsed       := 0;
        else
          assert_init_indep   <= '0';
          if(valid_indep = '1' and patt_error_indep = '1') then
            num_collapsed := num_collapsed +1;
          else
            null;
          end if;
        end if;
      else
        assert_init_indep   <= '0';
      end if;
    end if;
  end process;

  u_init_gen : process(clkIndep)
  begin
    if(clkIndep'event and clkIndep = '1') then
      if(srst_indep = '1') then
        init_indep  <= '0';
      elsif(assert_init_indep = '1') then
        init_indep  <= '1';
      elsif(lane_up_indep = '0') then
        init_indep  <= '0';
      else
        null;
      end if;
    end if;
  end process;



  -------------------------------------------------------------------------
  -- Clock domain crossing
  -------------------------------------------------------------------------
  lane_up_indep      <= sync_lane_up(kSyncLength-1);
  valid_indep        <= sync_valid(kSyncLength-1);
  patt_error_indep   <= sync_patterr(kSyncLength-1);
  srst_indep         <= sync_rst(kSyncLength-1);

  u_par_to_ref : process(clkIndep)
  begin
    if(clkIndep'event and clkIndep = '1') then
      sync_valid      <= sync_valid(kSyncLength-2 downto 0) & valid_cbtrx;
      sync_patterr    <= sync_patterr(kSyncLength-2 downto 0) & patterr_cbtrx;
      sync_lane_up    <= sync_lane_up(kSyncLength-2 downto 0) & lane_up;
      sync_rst        <= sync_rst(kSyncLength-2 downto 0) & srst;
    end if;
  end process;

  init_from_rxquality   <= sync_init(kSyncLength-1);
  clock_lost            <= sync_lost(kSyncLength-1);
  u_ref_to_par : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      sync_init   <= sync_init(kSyncLength-2 downto 0) & init_indep;
      sync_lost   <= sync_lost(kSyncLength-2 downto 0) & clock_lost_indep;
    end if;
  end process;


  -------------------------------------------------------------------------
  -- clkPar clock domain
  -------------------------------------------------------------------------

  modClock    <= modulated_clock;
  cbtLaneUp   <= lane_up;
  patternErr  <= patterr_cbtrx;
  validOutRx  <= valid_cbtrx;
  watchDogErr <= watchdog_error;

  -- CBT Lane Up ----------------------------------------------------------
  u_lane_up : process(srst, clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst = '1') then
        lane_up   <= '0';
      else
        lane_up_sr  <= lane_up_sr(kDelayLaneUp-2 downto 0) & (cbt_tx_up and cbt_rx_up);
        lane_up     <= lane_up_sr(kDelayLaneUp-1) and cbt_tx_up and cbt_rx_up;
      end if;
    end if;
  end process;

  -- CDCM-RX initialize timing --------------------------------------------
  gen_init_rx_master : if kCbtMode = "Master" generate
  begin
    u_clock_monitor : entity mylib.ClockMonitor
      port map
      (
        modClockIn  => modulated_clock,
        clkIndep    => clkIndep,
        clockLost   => clock_lost_indep
      );

    init_cdcm_rx  <= initIn or clock_lost or init_from_rxquality or watchdog_error;

    u_delay_sr : process(clkPar)
    begin
      if(clkPar'event and clkPar = '1') then
        init_sr   <= init_sr(kNumDelay-2 downto 0) & init_cdcm_rx;
      end if;
    end process;

    reg_init_cdcm_rx  <= init_sr(kNumDelay-1);

  end generate;

  gen_init_rx_slave : if kCbtMode = "Slave" generate
  begin
    init_cdcm_rx  <= initIn or init_from_rxquality or watchdog_error;
  end generate;

  -- Transmitter ---------------------------------------------------------
  u_cbttx : entity mylib.CbtTx
    generic map
    (
      -- CDCM-TX --
      kIoStandard      => kIoStandardTx,
      kCdcmModWidth    => kCdcmModWidth,
      -- CDCM encoder --
      kNumEncodeBits   => kNumEncodeBits,
      -- Tx Polarity --
      kTxPolarity      => kTxPolarity,
      -- DEBUG --
      enDEBUG          => enDEBUG
    )
    port map
    (
      -- SYSTEM port --
      srst        => srst,
      clkSer      => clkSer,
      clkPar      => clkPar,

      -- Status --
      cbtTxUp     => cbt_tx_up,

      -- Data I/F --
      isKType     => isKTypeTx,
      dataIn      => dataInTx,
      validIn     => validInTx,
      txBeat      => txBeat,
      txAck       => txAck,

      -- Back channel --
      instRx      => back_ch_inst,

      -- CDCM ports --
      cdcmTxp     => cdcmTxp,
      cdcmTxn     => cdcmTxn

    );

  -- Receiver -----------------------------------------------------------
  u_cbtrx : entity mylib.CbtRx
    generic map
    (
      -- CDCM-RX --
      genIDELAYCTRL      => genIDELAYCTRL,
      kDiffTerm          => kDiffTerm,
      kRxPolarity        => kRxPolarity,
      kIoStandard        => kIoStandardRx,
      kIoDelayGroup      => kIoDelayGroup,
      kCdcmModWidth      => kCdcmModWidth,
      kFreqFastClk       => kFreqFastClk,
      kFreqRefClk        => kFreqRefClk,
      -- CDCM decoder --
      kNumEncodeBits     => kNumEncodeBits,
      -- CBT --
      kCbtMode           => kCbtMode,
      -- DEBUG --
      enDEBUG            => enDEBUG
    )
    port map
    (
      -- SYSTEM port --
      srst          => srst,
      clkSer        => clkSer,
      clkPar        => clkPar,
      clkIdelayRef  => clkIdelayRef,
      clkIsReady    => clkIsReady,
      initIn        => init_cdcm_rx,

      -- Status --
      decoderReady  => decoder_bit_aligned,
      cbtRxUp       => cbt_rx_up,

      -- Error --
      patternErr    => patterr_cbtrx,
      --idelayErr     => idelayErr,
      bitslipErr    => bitslipErr,
      watchDogErr   => watchdog_error,

      -- Data I/F --
      isIdle        => isIdleRx,
      isKType       => isKTypeRx,
      dataOut       => dataOutRx,
      validOut      => valid_cbtrx,

      -- Back channel --
      instRx        => back_ch_inst,

      -- CDCM ports --
      cdcmRxp       => cdcmRxp,
      cdcmRxn       => cdcmRxn,
      modClock      => modulated_clock

    );

end RTL;
