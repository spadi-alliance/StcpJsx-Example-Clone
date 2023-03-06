library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package defCDCM is

  -- SerDes parameter --
  constant kWidthSys        : positive:= 1;
  constant kWidthDev        : positive:= 10;
  subtype CdcmPatternType is std_logic_vector(kWidthDev-1 downto 0);

  constant kWidthPayload    : positive:= 4;
  constant kPaylowdPos      : std_logic_vector(kWidthDev-4 downto 3):= "0011";

  -- SerDes pattern --
  constant kCDCMPattern     : CdcmPatternType:= "000----111"; -- Center 4-bits are payload.
  constant kAllZeroCDCM     : CdcmPatternType:= (others => '0');
  constant kInitPCDCM       : CdcmPatternType:= B"000_0111_111";
  constant kInitMCDCM       : CdcmPatternType:= B"000_0001_111";
  constant kIdleCDCM        : CdcmPatternType:= B"000_0011_111";

  -- TX ---------------------------------------------------------------------------------
  subtype  TxModeType is std_logic_vector(1 downto 0);
  constant kDisaTx          : TxModeType:= "11";
  constant kIdleTx          : TxModeType:= "10";
  constant kInitTx          : TxModeType:= "01";
  constant kNormalTx        : TxModeType:= "00";

  -- RX ---------------------------------------------------------------------------------
  subtype  RxInitStatusType is std_logic_vector(2 downto 0);
  constant kWaitClkReady      : RxInitStatusType:= "000";
  constant kAdjustingIdelay   : RxInitStatusType:= "001";
  constant kTryingBitslip     : RxInitStatusType:= "010";
  constant kInitFinish        : RxInitStatusType:= "011";
  constant kUndefinedRx       : RxInitStatusType:= "111";

  -- IDELAY
  constant kNumTaps         : positive:= 32;
  constant kMaxIdelayCheck  : positive:= 256;
  constant kSuccThreshold   : positive:= 230;
  constant kWidthCheckCount : positive:= 8;

  function GetTapDelay(freq_idelayctrl_ref : real) return real;
  function GetPlateauLength(tap_delay       : real;
                            freq_fast_clock : real) return integer;

   type IdelayControlProcessType is (
    Init,
    WaitPllReady,
    Check,
    NumTrialCheck,
    Increment,
    Decrement,
    IdelayAdjusted
    --IdelayFailure
    );

  -- BITSLIP
  constant kMaxPattCheck    : positive:= 32;
  constant kPattOkThreshold : positive:= 10;

  type BitslipControlProcessType is (
    Init,
    WaitStart,
    CheckIdlePatt,
    NumTrialCheck,
    BitSlip,
    BitslipFinished,
    BitslipFailure
    );

  -- Pattern match --
  constant kNumPattMatchCycle : integer:= 16;

  -- CBT --------------------------------------------------------------------------------
  -- CBT character : (MSB) 2-bit header + 8-bit data (LSB)

  constant kNumCbtHeaderBits : positive:= 2;
  constant kNumUserDataBits  : positive:= 8;
  constant kNumCbtCharBits   : positive:= kNumCbtHeaderBits + kNumUserDataBits;

  subtype CbtHeaderType is std_logic_vector(kNumCbtHeaderBits-1 downto 0);
  constant kKtype   : CbtHeaderType:= "00";
  constant kDtypeP  : CbtHeaderType:= "01";
  constant kDtypeM  : CbtHeaderType:= "10";
  constant kTtype   : CbtHeaderType:= "11";

  subtype  CbtCharType is std_logic_vector(kNumCbtCharBits-1 downto 0);
  -- For CDCM-10-1.5 --
  constant kTTypeCharInit1_1P5   : CbtCharType:= kTtype & B"0001_0110";
  constant kTTypeCharInit2_1P5   : CbtCharType:= kTtype & B"0010_1001";
  constant kTTypeCharDogfood     : CbtCharType:= kTtype & B"0110_1001";
  -- For CDCM-10-2.5 --
  constant kTTypeCharInit1_2P5   : CbtCharType:= kTtype & B"0001_0111";
  constant kTTypeCharInit2_2P5   : CbtCharType:= kTtype & B"0010_1000";

  function GetInit1Char(payload_width: integer) return CbtCharType;
  function GetInit2Char(payload_width: integer) return CbtCharType;


  subtype  CbtUDataType is std_logic_vector(kNumUserDataBits-1 downto 0);

  -- CBT back channel instruction --
  type CbtBackChannelType is (
    SendZero,
    SendIdle,
    SendInitPattern,
    SendTCharI1,
    SendTCharI2,
    StateCbtRxUp,
    DelayReinit
  );

  -- Watch dog timer --
  constant kWidthWatchDogTimer  : positive:= 20;

  -- RX quality check --
  constant kCheckFrameLength  : integer:= 512;
  constant kLowQualityTh      : integer:= integer(0.01*real(kCheckFrameLength)); -- 1%
  constant kSyncLength        : integer:= 4;

end package defCDCM;
-- ----------------------------------------------------------------------------------
-- Package body
-- ----------------------------------------------------------------------------------
package body defCDCM is

  -- GetTapDelay --------------------------------------------------------------
  function GetTapDelay(freq_idelayctrl_ref : real) return real is
    -- Argument : Frequency of refclk for IDELAYCTRL (MHz). Integer number.
    -- Return   : Delay per tap in IDELAY (ps). Real number.
    variable result : real;
  begin
    if (190.0 < freq_idelayctrl_ref and freq_idelayctrl_ref < 210.0) then
      result  := 78.0;
    elsif(290.0 < freq_idelayctrl_ref and freq_idelayctrl_ref < 310.0) then
      result  := 52.0;
    elsif(390.0 < freq_idelayctrl_ref and freq_idelayctrl_ref < 410.0) then
      result  := 39.0;
    else
      result  := 0.0;
    end if;

    return result;

  end GetTapDelay;

  -- GetPlateauLength ---------------------------------------------------------
  function GetPlateauLength(tap_delay       : real;
                            freq_fast_clock : real) return integer is
                            -- tap_delay : IDELAY tap delay (ps).
                            -- freq_fast_clock : Frequency of SERDES fast clock (MHz)
    constant kStableRange          : real:= 0.8;
    constant kExpectedStableLength : real:= 1.0/(2.0*freq_fast_clock)*1000.0*1000.0*kStableRange; -- [ps]
    constant kMaxLength            : integer:= 12;
    variable result                : integer:= integer(kExpectedStableLength/tap_delay);
  begin
    if(result > kMaxLength) then
      result  := kMaxLength;
    end if;
    return result;
  end GetPlateauLength;

  -- GetInit1Char -------------------------------------------------------------
  function GetInit1Char(payload_width: integer) return CbtCharType is
  begin
    case payload_width is
      when 1      => return(kTTypeCharInit1_1P5);
      when 2      => return(kTTypeCharInit1_2P5);
      when others => return(kTTypeCharInit1_1P5);
    end case;
  end GetInit1Char;

  -- GetInit2Char -------------------------------------------------------------
  function GetInit2Char(payload_width: integer) return CbtCharType is
  begin
    case payload_width is
      when 1      => return(kTTypeCharInit2_1P5);
      when 2      => return(kTTypeCharInit2_2P5);
      when others => return(kTTypeCharInit2_1P5);
    end case;
  end GetInit2Char;


end package body defCDCM;
