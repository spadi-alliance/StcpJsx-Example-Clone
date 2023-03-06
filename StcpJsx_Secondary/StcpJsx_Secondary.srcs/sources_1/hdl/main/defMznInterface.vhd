library ieee, mylib;
use ieee.std_logic_1164.all;

package defMIF is
  -- Status --
  constant kWidthStatusMzn       : integer:= 1;
  constant kWidthStatusBase      : integer:= 2;

  -- Mezzanine to Base --
  constant kIdMznMikuLinkUp      : integer:= 0;

  -- Base to Mezzanine --
  constant kIdBaseProgFullBMgr   : integer:= 0;
  constant kIdBaseHbfNumMismatch : integer:= 1;

end package defMIF;
