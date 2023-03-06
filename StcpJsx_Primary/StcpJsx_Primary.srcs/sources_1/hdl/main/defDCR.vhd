library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package defDCR is
  
--  constant kNumDcrChannel   : positive:= 32;
  
  function DcrUIoStd(index: integer)        return string;
  function DcrDIoStd(index: integer)        return string;

end package defDCR;

package body defDCR is

  function DcrUIoStd(index: integer) return string is
  begin
    case index is
      when 0  => return("LVDS_25");
      when 1  => return("LVDS_25");
      when 2  => return("LVDS_25");
      when 3  => return("LVDS_25");
      when 4  => return("LVDS_25");
      when 5  => return("LVDS_25");
      when 6  => return("LVDS_25");
      when 7  => return("LVDS_25");
      when 8  => return("LVDS_25");
      when 9  => return("LVDS_25");
      when 10 => return("LVDS_25");
      when 11 => return("LVDS_25");
      when 12 => return("LVDS_25");
      when 13 => return("LVDS_25");
      when 14 => return("LVDS_25");
      when 15 => return("LVDS_25");
      when 16 => return("LVDS_25");
      when 17 => return("LVDS_25");
      when 18 => return("LVDS_25");
      when 19 => return("LVDS_25");
      when 20 => return("LVDS_25");
      when 21 => return("LVDS_25");
      when 22 => return("LVDS_25");
      when 23 => return("LVDS_25");
      when 24 => return("LVDS_25");
      when 25 => return("LVDS_25");
      when 26 => return("LVDS_25");
      when 27 => return("LVDS_25");
      when 28 => return("LVDS_25");
      when 29 => return("LVDS_25");
      when 30 => return("LVDS_25");
      when 31 => return("LVDS_25");
    end case;
  end function DcrUIoStd;

  function DcrDIoStd(index: integer) return string is
  begin
    case index is
      when 0  => return("LVDS");
      when 1  => return("LVDS");
      when 2  => return("LVDS");
      when 3  => return("LVDS");
      when 4  => return("LVDS");
      when 5  => return("LVDS");
      when 6  => return("LVDS_25");
      when 7  => return("LVDS_25");
      when 8  => return("LVDS_25");
      when 9  => return("LVDS_25");
      when 10 => return("LVDS_25");
      when 11 => return("LVDS_25");
      when 12 => return("LVDS_25");
      when 13 => return("LVDS_25");
      when 14 => return("LVDS_25");
      when 15 => return("LVDS_25");
      when 16 => return("LVDS");
      when 17 => return("LVDS");
      when 18 => return("LVDS");
      when 19 => return("LVDS");
      when 20 => return("LVDS");
      when 21 => return("LVDS");
      when 22 => return("LVDS_25");
      when 23 => return("LVDS_25");
      when 24 => return("LVDS_25");
      when 25 => return("LVDS_25");
      when 26 => return("LVDS_25");
      when 27 => return("LVDS_25");
      when 28 => return("LVDS_25");
      when 29 => return("LVDS_25");
      when 30 => return("LVDS_25");
      when 31 => return("LVDS_25");
    end case;
  end function DcrDIoStd;

end package body defDCR;
