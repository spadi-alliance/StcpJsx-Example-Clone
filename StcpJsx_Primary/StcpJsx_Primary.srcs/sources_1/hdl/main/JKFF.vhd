--JKFF ACLR 1bit

library ieee;
use ieee.std_logic_1164.all;

entity JKFF is
    port(
	arst  : in std_logic;
	J	    : in std_logic;
	K     : in std_logic;
	clk   : in std_logic;
	Q     : out std_logic
	);
end JKFF;

architecture RTL of JKFF is
signal q1	: std_logic;
begin
	process (clk, arst)
	begin
	   if (arst = '1') then   
	      q1 <= '0';
	   elsif (clk'event AND clk='1') then 
	      q1 <= (J AND (NOT q1)) OR (K NOR (NOT q1));
	   end if;
	end process;

Q	<= q1;
end RTL;
