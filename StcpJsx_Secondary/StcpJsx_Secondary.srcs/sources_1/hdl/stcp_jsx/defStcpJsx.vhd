library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library mylib;
use mylib.defCDCM.all;
use mylib.defMikumari.all;

package defStcpJsx is

  -- Pulse type definition ---------------------------------------------------
  constant kNumPulse        : integer:= 6;
  subtype pulseId is integer range 0 to kNumPulse-1;
  type pulseRecord is record
    id : pulseId;
  end record;

  constant kHardReset       : pulseRecord := (id => 0);
  constant kHbCounterReset  : pulseRecord := (id => 1);
  constant kGateStart       : pulseRecord := (id => 2);
  constant kGateEnd         : pulseRecord := (id => 3);
  constant kVetoStart       : pulseRecord := (id => 4);
  constant kVetoEnd         : pulseRecord := (id => 5);

  subtype StcpJsxPulseType is std_logic_vector(kNumPulse-1 downto 0);

  constant kHardResetPulse  : MikumariPulseType:= "000";
  constant kHbCntResetPulse : MikumariPulseType:= "001";
  constant kGateStartPulse  : MikumariPulseType:= "010";
  constant kGateEndPulse    : MikumariPulseType:= "011";
  constant kVetoStartPulse  : MikumariPulseType:= "100";
  constant kVetoEndPulse    : MikumariPulseType:= "101";
  constant kErrorPulse      : MikumariPulseType:= "111";

  -- Command type definition ------------------------------------------------
  constant kNumCommand        : integer:= 4;
  subtype commandId is integer range 0 to kNumCommand-1;
  type commandRecord is record
    id : commandId;
  end record;

  constant kRunStart        : pulseRecord := (id => 0);
  constant kRunEnd          : pulseRecord := (id => 1);
  constant kHbFrameNum      : pulseRecord := (id => 2);
  constant kGateNum         : pulseRecord := (id => 3);

  subtype StcpJsxCommandType is std_logic_vector(kNumCommand-1 downto 0);

  constant kComRunStart   : CbtUDataType:= B"1000_1100";
  constant kComRunEnd     : CbtUDataType:= B"1010_1100";
  constant kComHbFrameNum : CbtUDataType:= B"0010_1010";
  constant kComGateNum    : CbtUDataType:= B"1001_1010";
  constant kComError      : CbtUDataType:= B"1110_1010";

  constant kWidthRegValue   : integer:= 32;
  type StcpRegArray is array(integer range 0 to kWidthRegValue/8-1) of
    std_logic_vector(7 downto 0);

  subtype HbNumberType   is std_logic_vector(15 downto 0);
  subtype GateNumberType is std_logic_vector(7 downto 0);

  type CommandSeqType is
    (
     WaitCommand, SetRegValue, SendCommand, SendRegValue, FinalizeCommand
   );

  type ParseSeqType is
    (
     WaitRxData, ReceiveRegValue, SetCommand, FinalizeParse
   );

  -- Flag definition -----------------------------------------------------
  constant kNumFlag        : integer:=8;
  subtype flagId is integer range 0 to kNumFlag-1;
  type flagRecord is record
    id : flagId;
  end record;

  constant kModBusy         : flagRecord := (id => 0);
  constant kModReady        : flagRecord := (id => 1);
  constant kDLinkStatus     : flagRecord := (id => 2);
  constant kSEUStatus       : flagRecord := (id => 3);
  constant kLHbfNumMismatch : flagRecord := (id => 4);
  constant kGHbfNumMismatch : flagRecord := (id => 5);
  constant kNotInUse2       : flagRecord := (id => 6);
  constant kNotInUse3       : flagRecord := (id => 7);

  subtype StcpJsxFlagType is std_logic_vector(kNumFlag-1 downto 0);


  -- Encode functions --
  function encodeStcpPulseType(pulse_in : StcpJsxPulseType) return MikumariPulseType;
  function encodeStcpCommand(command_in : StcpJsxCommandType) return CbtUDataType;

  -- Decode functions --
  function decodeStcpPulseType(pulse_type : MikumariPulseType) return StcpJsxPulseType;
  function decodeStcpCommand(data_in : CbtUDataType) return StcpJsxCommandType;

  function checkStcpPulseError(pulse_type : MikumariPulseType) return std_logic;
  function checkStcpCommandError(data_in : CbtUDataType) return std_logic;

end package defStcpJsx;
-- ----------------------------------------------------------------------------------
-- Package body
-- ----------------------------------------------------------------------------------
package body defStcpJsx is
  -- Pulse --------------------------------------------------------------------
  function encodeStcpPulseType(pulse_in : StcpJsxPulseType) return MikumariPulseType is
    variable result   : MikumariPulseType;
  begin
    result  := kHardResetPulse  when(pulse_in = "000001") else
               kHbCntResetPulse when(pulse_in = "000010") else
               kGateStartPulse  when(pulse_in = "000100") else
               kGateEndPulse    when(pulse_in = "001000") else
               kVetoStartPulse  when(pulse_in = "010000") else
               kVetoEndPulse    when(pulse_in = "100000") else kErrorPulse;

    return result;

  end encodeStcpPulseType;

  function decodeStcpPulseType(pulse_type : MikumariPulseType) return StcpJsxPulseType is
    variable result   : StcpJsxPulseType;
  begin
    result  := "000001" when(pulse_type = kHardResetPulse  ) else
               "000010" when(pulse_type = kHbCntResetPulse ) else
               "000100" when(pulse_type = kGateStartPulse  ) else
               "001000" when(pulse_type = kGateEndPulse    ) else
               "010000" when(pulse_type = kVetoStartPulse  ) else
               "100000" when(pulse_type = kVetoEndPulse    ) else "000000";

    return result;

  end decodeStcpPulseType;

  function checkStcpPulseError(pulse_type : MikumariPulseType) return std_logic is
    variable result   : std_logic;
  begin
    result  := '1' when(pulse_type = kErrorPulse) else '0';
    return result;
  end checkStcpPulseError;

  -- Command -----------------------------------------------------------------
  function encodeStcpCommand(command_in : StcpJsxCommandType) return CbtUDataType is
    variable result   : CbtUDataType;
  begin
    result  := kComRunStart   when(command_in = "0001") else
               kComRunEnd     when(command_in = "0010") else
               kComHbFrameNum when(command_in = "0100") else
               kComGateNum    when(command_in = "1000") else kComError;
    return result;

  end encodeStcpCommand;

  function decodeStcpCommand(data_in : CbtUDataType) return StcpJsxCommandType is
    variable result : StcpJsxCommandType;
  begin
    result  := "0001" when(data_in = kComRunStart  ) else
               "0010" when(data_in = kComRunEnd    ) else
               "0100" when(data_in = kComHbFrameNum) else
               "1000" when(data_in = kComGateNum   ) else "0000";
    return result;
  end decodeStcpCommand;

  function checkStcpCommandError(data_in : CbtUDataType) return std_logic is
    variable result   : std_logic;
  begin
    result  := '1' when(data_in = kComError) else '0';
    return result;
  end checkStcpCommandError;

end package body defStcpJsx;
