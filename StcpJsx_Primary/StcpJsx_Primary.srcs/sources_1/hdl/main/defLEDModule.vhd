library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use mylib.defBCT.all;

package defLED is
  -- Local Address  -------------------------------------------------------
  constant kSelLED              : LocalAddressType := x"000"; -- W/R, [3:0], select LED
  
end package defLED;	

