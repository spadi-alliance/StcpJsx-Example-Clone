library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use mylib.defBCT.all;

package defSDS is
  -- XADC IP def --
  constant kWidthDrpDIn     : positive:= 16;
  constant kWidthDrpDOut    : positive:= 16;
  constant kWidthDrpAddr    : positive:= 7;
  constant kWidthXadcCh     : positive:= 5;

  -- XADC process --
  constant kIsRead          : std_logic:= '0';
  constant kIsWrite         : std_logic:= '1';

  -- Sds Status --
  constant kWidthStatus     : positive:= 8;
  -- 0: over temperature (system shutdown)
  -- 1: user temperature alarm
  -- 2: user vccint alarm

  -- Local Address  -------------------------------------------------------
  -- XADC --
  constant kSdsStatus       : LocalAddressType := x"000"; -- R,   [7:0]
  
  constant kXadcDrpMode     : LocalAddressType := x"010"; -- W/R, [0:0]
  constant kXadcDrpAddr     : LocalAddressType := x"020"; -- W/R, [6:0]
  constant kXadcDrpDin      : LocalAddressType := x"030"; -- W/R, [7:0], (2 byte)
  constant kXadcDrpDout     : LocalAddressType := x"040"; -- R,   [7:0], (2 byte)
  constant kXadcExecute     : LocalAddressType := x"0f0"; -- W,

  constant kSemCorCount     : LocalAddressType := x"100"; -- R,   [7:0], (2 byte)
  constant kSemRstCorCount  : LocalAddressType := x"200"; -- W,   
  constant kSemErrAddr      : LocalAddressType := x"300"; -- W,   [7:0], (5 byte)
  constant kSemErrStrobe    : LocalAddressType := x"400"; -- W,   
end package defSDS;	

