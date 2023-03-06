library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package defMiiRstTimer is
  constant kWidthPhyAddr  : positive:= 5;
  
  constant kNumInstance   : integer:= 5;

  constant kWidthCounter  : positive:= 13;
  constant kPresetCount   : std_logic_vector(kWidthCounter-1 downto 0):= "1011101110000";

end package defMiiRstTimer;

