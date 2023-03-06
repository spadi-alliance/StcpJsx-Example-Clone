library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.numeric_std.all;

library UNISIM;
use UNISIM.VComponents.all;

library mylib;
use mylib.defCDCM.all;
use mylib.defMikumari.all;
use mylib.defStcpJsx.all;


entity StcpJsxPrimWrapper is
  generic(
    -- CBT generic -------------------------------------------------------------
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
    enDebugCBT       : boolean:= false;

    -- MIKUMARI generic --------------------------------------------------------
    -- Scrambler --
    enScrambler      : boolean:= true;
    -- DEBUG --
    enDebugMikumari  : boolean:= false
  );
  port(
    -- System ports -----------------------------------------------------------
    rst           : in std_logic;          -- Asynchronous reset input
    clkSer        : in std_logic;          -- Slow clock
    clkPar        : in std_logic;          -- Fast clock
    clkIndep      : in std_logic;          -- Independent clock for monitor in CBT
    clkIdctrl     : in std_logic;          -- Reference clock for IDELAYCTRL (if exist)
    clkIsReady    : in std_logic;          -- Flag to indicate slow and fast clocks are ready
    initIn        : in std_logic;          -- Redo the initialize process

    TXP           : out std_logic;         -- CDCM TXP port. Connect to toplevel port
    TXN           : out std_logic;         -- CDCM TXN port. Connect to toplevel port
    RXP           : in std_logic;          -- CDCM RXP port. Connect to toplevel port
    RXN           : in std_logic;          -- CDCM RXN port. Connect to toplevel port
    modClk        : out std_logic;         -- Modulated clock output

    -- CBT ports ------------------------------------------------------------
    laneUp        : out std_logic;         -- CBT link connection is established
    pattErr       : out std_logic;         -- CDCM waveform pattern is broken
    watchDogErr   : out std_logic;         -- Watchdog timer alert

    -- Mikumari ports -------------------------------------------------------
    linkUp        : out std_logic;         -- MIKUMARI link connection is established

    -- NDP ports ------------------------------------------------------------
    busyPulseSend   : out std_logic;
    busyCommandSend : out std_logic;

    -- Pulse input --
    stcpPulseIn     : in StcpJsxPulseType;
    pulseError      : out std_logic;

    -- Command input --
    stcpCommandIn   : in StcpJsxCommandType;
    commandError    : out std_logic;

    hbNumber        : in HbNumberType;
    gateNumber      : in GateNumberType;

    -- Slave flag output --
    stcpFlagOut     : out StcpJsxFlagType

  );
end StcpJsxPrimWrapper;

architecture Behavioral of StcpJsxPrimWrapper is
  -- MIKUMARI --
  signal mikumari_link_up       :  std_logic;
  signal miku_data_tx, miku_data_rx   : CbtUDataType;
  signal miku_valid_tx, miku_valid_rx : std_logic;
  signal miku_frame_last_tx, miku_frame_last_rx : std_logic;
  signal miku_tx_ack            : std_logic;
  signal miku_checksum_error    : std_logic;

  signal miku_pulse_in          : std_logic;
  signal miku_pulse_type_tx     : MikumariPulseType;
  signal miku_pulse_busy        : std_logic;

begin
  -- ===================================================================================
  -- body
  -- ===================================================================================
  linkUp  <= mikumari_link_up;


  u_MIKUMARI : entity mylib.MikumariBlock
    generic map(
      -- CBT generic -------------------------------------------------------------
      -- CDCM-Mod-Pattern --
      kCdcmModWidth    => kCdcmModWidth,
      -- CDCM-TX --
      kIoStandardTx    => kIoStandardTx,
      kTxPolarity      => kTxPolarity,
      -- CDCM-RX --
      genIDELAYCTRL    => genIDELAYCTRL,
      kDiffTerm        => kDiffTerm,
      kRxPolarity      => kRxPolarity,
      kIoStandardRx    => kIoStandardRx,
      kIoDelayGroup    => kIoDelayGroup,
      kFreqFastClk     => kFreqFastClk,
      kFreqRefClk      => kFreqRefClk,
      -- Encoder/Decoder
      kNumEncodeBits   => kNumEncodeBits,
      -- Master/Slave
      kCbtMode         => kCbtMode,
      -- DEBUG --
      enDebugCBT       => enDebugCBT,

      -- MIKUMARI generic --------------------------------------------------------
      -- Scrambler --
      enScrambler      => enScrambler,
      -- DEBUG --
      enDebugMikumari  => enDebugMikumari
    )
    port map(
      -- System ports -----------------------------------------------------------
      rst           => rst,
      clkSer        => clkSer,
      clkPar        => clkPar,
      clkIndep      => clkIndep,
      clkIdctrl     => clkIdctrl,
      clkIsReady    => clkIsReady,
      initIn        => initIn,

      TXP           => TXP,
      TXN           => TXN,
      RXP           => RXP,
      RXN           => RXN,
      modClk        => modClk,

      -- CBT ports ------------------------------------------------------------
      laneUp        => laneUp,
      pattErr       => pattErr,
      watchDogErr   => watchDogErr,

      -- Mikumari ports -------------------------------------------------------
      linkUp        => mikumari_link_up,

      -- Data IF TX --
      dataInTx      => miku_data_tx,
      validInTx     => miku_valid_tx,
      frameLastInTx => miku_frame_last_tx,
      txAck         => miku_tx_ack,

      pulseIn       => miku_pulse_in,
      pulseTypeTx   => miku_pulse_type_tx,
      busyPulseTx   => miku_pulse_busy,

      -- Data IF RX --
      dataOutRx     => miku_data_rx,
      validOutRx    => miku_valid_rx,
      frameLastRx   => miku_frame_last_rx,
      checksumErr   => miku_checksum_error,

      pulseOut      => open,
      pulseTypeRx   => open
    );

  u_STCP : entity mylib.StcpJsxPrimary
    port map
    (
      -- system --
      rst             => rst,
      clkPar          => clkPar,
      linkUpIn        => mikumari_link_up,

      busyPulseSend   => busyPulseSend,
      busyCommandSend => busyCommandSend,

      -- Pulse input --
      stcpPulseIn     => stcpPulseIn,
      pulseError      => pulseError,

      -- Command input --
      stcpCommandIn   => stcpCommandIn,
      commandError    => commandError,

      hbNumber        => hbNumber,
      gateNumber      => gateNumber,

      -- Slave flag output --
      stcpFlagOut      => stcpFlagOut,

      -- MIKUMARI IF --
      dataOutTx       => miku_data_tx,
      validOutTx      => miku_valid_tx,
      frameLastOutTx  => miku_frame_last_tx,
      txAck           => miku_tx_ack,

      pulseOut        => miku_pulse_in,
      pulseTypeOut    => miku_pulse_type_tx,
      busyPulseTx     => miku_pulse_busy,

      dataInRx        => miku_data_rx,
      validInRx       => miku_valid_rx,
      frameLastRx     => miku_frame_last_rx
    );


end Behavioral;