library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use mylib.defToplevel.all;

entity DCR_NetAssign is
  Port (
    mznInU  : in  std_logic_vector(kNumInputMZN-1 downto 0);
    mznInD  : in  std_logic_vector(kNumInputMZN-1 downto 0);
    dcrOutU : out std_logic_vector(kNumInputMZN-1 downto 0);
    dcrOutD : out std_logic_vector(kNumInputMZN-1 downto 0)
    );
end DCR_NetAssign;

architecture Behavioral of DCR_NetAssign is

begin
  dcrOutU(0)  <= mznInU(15);
  dcrOutU(1)  <= mznInU(13);
  dcrOutU(2)  <= mznInU(11);
  dcrOutU(3)  <= mznInU(9);
  dcrOutU(4)  <= mznInU(7);
  dcrOutU(5)  <= NOT mznInU(5);
  dcrOutU(6)  <= mznInU(3);
  dcrOutU(7)  <= mznInU(1);
  dcrOutU(8)  <= mznInU(31);
  dcrOutU(9)  <= mznInU(29);
  dcrOutU(10) <= mznInU(27);
  dcrOutU(11) <= mznInU(25);
  dcrOutU(12) <= mznInU(23);
  dcrOutU(13) <= mznInU(21);
  dcrOutU(14) <= mznInU(19);
  dcrOutU(15) <= mznInU(17);
  dcrOutU(16) <= mznInU(14);
  dcrOutU(17) <= mznInU(12);
  dcrOutU(18) <= mznInU(10);
  dcrOutU(19) <= mznInU(8);
  dcrOutU(20) <= NOT mznInU(6);
  dcrOutU(21) <= mznInU(4);
  dcrOutU(22) <= mznInU(2);
  dcrOutU(23) <= mznInU(0);
  dcrOutU(24) <= mznInU(30);
  dcrOutU(25) <= mznInU(28);
  dcrOutU(26) <= mznInU(26);
  dcrOutU(27) <= mznInU(24);
  dcrOutU(28) <= mznInU(22);
  dcrOutU(29) <= mznInU(20);
  dcrOutU(30) <= mznInU(18);
  dcrOutU(31) <= mznInU(16);

  dcrOutD(0)  <= mznInD(15);
  dcrOutD(1)  <= mznInD(13);
  dcrOutD(2)  <= mznInD(11);
  dcrOutD(3)  <= mznInD(9);
  dcrOutD(4)  <= mznInD(7);
  dcrOutD(5)  <= mznInD(5);
  dcrOutD(6)  <= mznInD(3);
  dcrOutD(7)  <= mznInD(1);
  dcrOutD(8)  <= NOT mznInD(31);
  dcrOutD(9)  <= mznInD(29);
  dcrOutD(10) <= NOT mznInD(27);
  dcrOutD(11) <= NOT mznInD(25);
  dcrOutD(12) <= mznInD(23);
  dcrOutD(13) <= NOT mznInD(21);
  dcrOutD(14) <= mznInD(19);
  dcrOutD(15) <= mznInD(17);
  dcrOutD(16) <= mznInD(14);
  dcrOutD(17) <= mznInD(12);
  dcrOutD(18) <= mznInD(10);
  dcrOutD(19) <= mznInD(8);
  dcrOutD(20) <= mznInD(6);
  dcrOutD(21) <= mznInD(4);
  dcrOutD(22) <= mznInD(2);
  dcrOutD(23) <= mznInD(0);
  dcrOutD(24) <= mznInD(30);
  dcrOutD(25) <= NOT mznInD(28);
  dcrOutD(26) <= NOT mznInD(26);
  dcrOutD(27) <= mznInD(24);
  dcrOutD(28) <= mznInD(22);
  dcrOutD(29) <= mznInD(20);
  dcrOutD(30) <= mznInD(18);
  dcrOutD(31) <= mznInD(16);

end Behavioral;
