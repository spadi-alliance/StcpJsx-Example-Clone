library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use mylib.defBCT.all;

package defFMP is
  -- SPI command register --
  constant kNumArray        : positive:= 8; -- Write + Read + Dummy + Addr (4) + Inst
  constant kWidthIndexReg   : positive:= 3;
  
  constant kIndexInst       : std_logic_vector(kWidthIndexReg-1 downto 0):= "000";
  constant kIndexAddr3      : std_logic_vector(kIndexInst'range):=          "001";
  constant kIndexAddr2      : std_logic_vector(kIndexInst'range):=          "010";
  constant kIndexAddr1      : std_logic_vector(kIndexInst'range):=          "011";
  constant kIndexAddr0      : std_logic_vector(kIndexInst'range):=          "100";
  constant kIndexDummy      : std_logic_vector(kIndexInst'range):=          "101";
  constant kIndexRead       : std_logic_vector(kIndexInst'range):=          "110";
  constant kIndexWrite      : std_logic_vector(kIndexInst'range):=          "111";

  -- Length command --
  constant kWidthInst       : positive:= 3;
  constant kWidthRead       : positive:= 10;
  constant kWidthWrite      : positive:= 10;

  -- Status register --
  
  constant kWidthStatus     : positive:= 8;

  -- Ctrl register --
  constant kWidthCtrl       : positive:= 8;
  constant kIndexDummyMode  : positive:= 2;

  subtype  ModeType         is  std_logic_vector(1 downto 0);

  constant kIsReadMode      : ModeType:= "00";
  constant kIsWriteMode     : ModeType:= "01";
  constant kIsInstMode      : ModeType:= "10";

  -- Local Address  -------------------------------------------------------
  constant kStatus          : LocalAddressType := x"000"; -- R,   [7:0]
  constant kCtrl            : LocalAddressType := x"010"; -- W/R, [7:0]
  constant kRegister        : LocalAddressType := x"020"; -- W/R, [7:0], (8 byte)
  constant kInstLength      : LocalAddressType := x"030"; -- W/R, [2:0]
  constant kReadLength      : LocalAddressType := x"040"; -- W/R, [9:0]
  constant kWriteLength     : LocalAddressType := x"050"; -- W/R, [9:0]
  constant kReadCountFIFO   : LocalAddressType := x"060"; -- R,   [9:0]
  constant kReadFIFO        : LocalAddressType := x"070"; -- R,   [7:0]
  constant kWriteCountFIFO  : LocalAddressType := x"080"; -- R,   [9:0]
  constant kWriteFIFO       : LocalAddressType := x"090"; -- W,   [7:0]

  constant kExecute         : LocalAddressType := x"100"; -- W,
  
end package defFMP;	

