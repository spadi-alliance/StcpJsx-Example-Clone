library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use mylib.defBCT.all;

package defC6C is
  -- Auto reset sequence --
  constant kWidthRstCnt     : integer:= 25;
  constant kWidthRstSr      : integer:= 20;

  -- GSPI-IF --
  constant kSysClkFreq      : integer:= 150_000_000;
  constant kSpiClkFreq      : integer:= 10_000_000;
  constant kWidthSpi        : integer:= 32;

  constant kCpol            : std_logic:= '0';
  constant kCpha            : std_logic:= '0';

  constant kLengthInterval  : positive:= 32;

  type SpiIfProcessType is (
    Idle, StartIF, WaitCommandDone, Interval, Finalize
    );

  -- Local bus --
  type C6CBusProcessType is (
    Init, Idle, Connect,
    Write, Read,
    ExecuteWrite, ExecuteRead,
    WaitDone,
    Finalize,
    Done
    );


  -- Local Address  -------------------------------------------------------
  constant kTxd             : LocalAddressType := x"000"; -- W,   [31:0]
  constant kRxd             : LocalAddressType := x"010"; -- R,   [31:0]

  constant kExecWrite       : LocalAddressType := x"100"; -- W,
  constant kExecRead        : LocalAddressType := x"200"; -- R,   [31:0]

end package defC6C;

