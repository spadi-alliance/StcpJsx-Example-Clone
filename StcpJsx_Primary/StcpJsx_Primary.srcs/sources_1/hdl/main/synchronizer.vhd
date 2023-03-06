library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity synchronizer is
  Port (
    clk         : in STD_LOGIC;
    dIn		: in STD_LOGIC;
    dOut	: out  STD_LOGIC
    );
end synchronizer;

architecture RTL of synchronizer is
  signal q1, q2	: std_logic;
  
begin
  dOut	<= q2;

  u_Sync1 : process(CLK)
  begin
    if(CLK'event and CLK = '1') then
      q1	<= dIn;
    end if;
  end process u_Sync1;
  
  u_Sync2 : process(CLK)
  begin
    if(CLK'event and CLK = '1') then
      q2	<= q1;
    end if;
  end process u_Sync2;

end RTL;

