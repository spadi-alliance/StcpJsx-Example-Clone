library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package defToplevel is
  -- Number of input per a main port.
  constant kNumInput            : integer:= 32;
  constant kNumInputMZN         : integer:= 32;

  -- Number of MIF blocks --
  constant kNumMIF              : integer:= 2;

  -- AMANEQ specification
  constant kNumLED              : integer:= 4;
  constant kNumBitDIP           : integer:= 4;
  constant kNumNIM              : integer:= 2;
  constant kNumGtx              : integer:= 1;

end package defToplevel;
