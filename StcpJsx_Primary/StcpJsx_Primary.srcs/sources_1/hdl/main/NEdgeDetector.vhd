--Negative Edge detector

library ieee;
use ieee.std_logic_1164.all;

entity NEdgeDetector is
  port(
    rst         : in std_logic;
    clk	        : in std_logic;
    dIn         : in std_logic;
    dOut	: out std_logic
    );
end NEdgeDetector;

architecture RTV of NEdgeDetector is
  signal q1, q2	: std_logic;
	
begin
  u_ff : process(rst, clk)
  begin
    if(rst = '1') then
      q1        <= '0';
      q2        <= '0';
    elsif(clk'event and clk = '1') then
      q1        <= dIn;
      q2        <= q1;
    end if;
  end process;
  
  dOut <= q1 NOR (NOT q2);

end RTV;
