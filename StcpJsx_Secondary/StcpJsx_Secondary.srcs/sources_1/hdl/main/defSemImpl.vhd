library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
--use mylib.defBCT.all;

package defSEM is
  -- Heartbeat preset --
  constant kMaxCountHeartbeat : std_logic_vector(9 downto 0):= (others => '1');

  -- Couner --
  constant kWidthCorrection   : positive:= 16;
  
  -- SEM ports --
  constant kWidthMonData    : positive:= 8;
  constant kWidthErrAddr    : positive:= 40;
  constant kWidthIcapData   : positive:= 32;
  constant kWidthSyndrome   : positive:= 13;
  constant kWidthFar        : positive:= 26;
  constant kWidthSynBit     : positive:= 5;
  constant kWidthSynWord    : positive:= 7;

  type SemStatusType is record
    watchdog_alarm      : std_logic;
    counter_correction  : std_logic_vector(kWidthCorrection-1 downto 0);
    uncorrectable_alarm : std_logic;
  end record;

end package defSEM;	

