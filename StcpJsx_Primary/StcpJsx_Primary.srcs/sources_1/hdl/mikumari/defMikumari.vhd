library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library mylib;
use mylib.defCDCM.all;

package defMikumari is

  -- K-type characters --
  -- For CDCM-10-1.5 --
  constant kMikuInitK1_1P5      : CbtUDataType:= B"0101_1101";
  constant kMikuInitK2_1P5      : CbtUDataType:= B"0101_1011";
  -- For CDCM-10-2.5 --
  constant kMikuInitK1_2P5      : CbtUDataType:= B"1000_1011";
  constant kMikuInitK2_2P5      : CbtUDataType:= B"1000_1110";

  constant kMikumariFsk         : CbtUDataType:= B"1111_0010";
  constant kMikumariFek         : CbtUDataType:= B"1111_0001";

  function GetInitK1(payload_width: integer) return CbtUDataType;
  function GetInitK2(payload_width: integer) return CbtUDataType;

  -- Back channel --
  type MikumariBackChannelType is (
    WaitCbtUp, SendInitK1, SendInitK2, MikumariRxUp
  );

  -- Mikumari Pulse --
  subtype  MikumariPulseType        is std_logic_vector(2 downto 0);
  subtype  MikumariEncodedPulseType is std_logic_vector(3 downto 0);
  constant kWidthPulseCount       : positive:= 4;
  constant kWidthPulseSr          : positive:= 10;

  -- Check sum --
  constant kWidthCheckSum         : positive:= 8;

  -- Mikumari TX --
  constant kNumTxFlag         : integer:= 11;
  subtype flagId is integer range 0 to kNumTxFlag-1;
  type flagRecord is record
    index : flagId;
  end record;

  constant kUserDataTx    : flagRecord := (index => 0);
  constant kLastData      : flagRecord := (index => 1);
  constant kPulseReserve  : flagRecord := (index => 2);
  constant kPulseTx       : flagRecord := (index => 3);
  constant kInitMikuTx    : flagRecord := (index => 4);
  constant kCsReserve     : flagRecord := (index => 5);
  constant kCheckSumTx    : flagRecord := (index => 6);
  constant kFekReserve    : flagRecord := (index => 7);
  constant kFekTx         : flagRecord := (index => 8);
  constant kFskReserve    : flagRecord := (index => 9);
  constant kFskTx         : flagRecord := (index => 10);

  function isBusyTx(tx_flag : std_logic_vector(kNumTxFlag-1 downto 0)) return std_logic;
  function isBusyIFBuf(tx_flag : std_logic_vector(kNumTxFlag-1 downto 0)) return std_logic;
  function encodePulseType(pulse_type : MikumariPulseType) return MikumariEncodedPulseType;

  -- Mikumari RX --
  function isPulseChar(cbt_data : CbtUDataType; is_ktype  : std_logic) return std_logic;
  function decodePulseType(cbt_data : CbtUDataType) return MikumariPulseType;

  constant kWidthLinkDelay  : positive:= 64;

  -- Scrambler/Descrambler --
  type SetSeedType is
     (
      WaitLinkUp, SendFirstFsk, WaitFirstFsk, SetSeed, SeedIsSet
    );


end package defMikumari;
-- ----------------------------------------------------------------------------------
-- Package body
-- ----------------------------------------------------------------------------------
package body defMikumari is
  -- Mikumari TX --------------------------------------------------------------------
  function isBusyTx(tx_flag : std_logic_vector(kNumTxFlag-1 downto 0)) return std_logic is
    variable result   : std_logic;
  begin
    result  := or_reduce(tx_flag(kFskTx.index downto kPulseTx.Index));
    --result  := or_reduce(tx_flag(kFekTx.index downto kLastData.index));
    --result  := or_reduce(tx_flag(kFskTx.index downto kLastData.index));

    return result;

  end isBusyTx;

  function isBusyIFBuf(tx_flag : std_logic_vector(kNumTxFlag-1 downto 0)) return std_logic is
    variable result   : std_logic;
  begin
    --result  := or_reduce(tx_flag(kCheckSumTx.index downto kLastData.index));
    result  := or_reduce(tx_flag(kFekTx.index downto kLastData.index));

    return result;

  end isBusyIFBuf;


  function encodePulseType(pulse_type : MikumariPulseType) return MikumariEncodedPulseType is
    variable  result  : MikumariEncodedPulseType;
  begin
    result  := "1010" when(pulse_type = "000") else
               "1110" when(pulse_type = "001") else
               "1011" when(pulse_type = "010") else
               "1101" when(pulse_type = "011") else
               "0111" when(pulse_type = "100") else
               "1001" when(pulse_type = "101") else
               "0110" when(pulse_type = "110") else
               "1100" when(pulse_type = "111") else "1001";

    return result;
  end encodePulseType;

  -- Mikumari RX --------------------------------------------------------------------
  function isPulseChar(cbt_data : CbtUDataType; is_ktype : std_logic) return std_logic is
    variable result   : std_logic;
  begin
    result  := '1' when(is_ktype = '1' and cbt_data(CbtUDataType'left downto 4) = "1010") else
               '1' when(is_ktype = '1' and cbt_data(CbtUDataType'left downto 4) = "1110") else
               '1' when(is_ktype = '1' and cbt_data(CbtUDataType'left downto 4) = "1011") else
               '1' when(is_ktype = '1' and cbt_data(CbtUDataType'left downto 4) = "1101") else
               '1' when(is_ktype = '1' and cbt_data(CbtUDataType'left downto 4) = "0111") else
               '1' when(is_ktype = '1' and cbt_data(CbtUDataType'left downto 4) = "1001") else
               '1' when(is_ktype = '1' and cbt_data(CbtUDataType'left downto 4) = "0110") else
               '1' when(is_ktype = '1' and cbt_data(CbtUDataType'left downto 4) = "1100") else '0';

    return result;
  end isPulseChar;

  function decodePulseType(cbt_data : CbtUDataType) return MikumariPulseType is
    variable result   : MikumariPulseType;
  begin
    result  := "000" when(cbt_data(CbtUDataType'left downto 4) = "1010") else
               "001" when(cbt_data(CbtUDataType'left downto 4) = "1110") else
               "010" when(cbt_data(CbtUDataType'left downto 4) = "1011") else
               "011" when(cbt_data(CbtUDataType'left downto 4) = "1101") else
               "100" when(cbt_data(CbtUDataType'left downto 4) = "0111") else
               "101" when(cbt_data(CbtUDataType'left downto 4) = "1001") else
               "110" when(cbt_data(CbtUDataType'left downto 4) = "0110") else
               "111" when(cbt_data(CbtUDataType'left downto 4) = "1100") else "000";

    return result;
  end decodePulseType;

  -- CBT K-char selector -------------------------------------------------------------
  function GetInitK1(payload_width: integer) return CbtUDataType is
  begin
    case payload_width is
      when 1      =>  return(kMikuInitK1_1P5);
      when 2      =>  return(kMikuInitK1_2P5);
      when others =>  return(kMikuInitK1_1P5);
    end case;
  end GetInitK1;

  function GetInitK2(payload_width: integer) return CbtUDataType is
  begin
    case payload_width is
      when 1      =>  return(kMikuInitK2_1P5);
      when 2      =>  return(kMikuInitK2_2P5);
      when others =>  return(kMikuInitK2_1P5);
    end case;
  end GetInitK2;



end package body defMikumari;
