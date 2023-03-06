library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

-- PRBS based on 16-bit maximum length sequence generator --
-- 1 + x + x^3 + x^12 + x^16 <=> x^-16 + x^-15 + x^-13 + x^-4 + 1 --

entity PRBS16 is
  port
  (
    setSeed   : in std_logic;
    clk       : in std_logic;
    enClk     : in std_logic;
--    dataIn    : in std_logic;
    dataOut   : out std_logic_vector(15 downto 0)
  );
end PRBS16;

architecture RTL of PRBS16 is

  constant kLengthSr  : positive:= 16;
  constant kSeed      : std_logic_vector(kLengthSr-1 downto 0):= B"0000_1010_0010_0101";
  signal reg_sr       : std_logic_vector(kLengthSr-1 downto 0):= (others => '0');

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  dataOut   <= reg_sr;

  u_lfsr : process(clk, setSeed)
  begin
    if(setSeed = '1') then
      reg_sr      <= kSeed;
    elsif(clk'event and clk = '1') then
      if(enClk = '1') then
        reg_sr(0)   <= reg_sr(15);               -- -16
        reg_sr(1)   <= reg_sr(0) xor reg_sr(15); -- -15
        reg_sr(2)   <= reg_sr(1);                -- -14
        reg_sr(3)   <= reg_sr(2) xor reg_sr(15); -- -13
        reg_sr(4)   <= reg_sr(3);                -- -12
        reg_sr(5)   <= reg_sr(4);                -- -11
        reg_sr(6)   <= reg_sr(5);                -- -10
        reg_sr(7)   <= reg_sr(6);                -- -9
        reg_sr(8)   <= reg_sr(7);                -- -8
        reg_sr(9)   <= reg_sr(8);                -- -7
        reg_sr(10)  <= reg_sr(9);                -- -6
        reg_sr(11)  <= reg_sr(10);               -- -5
        reg_sr(12)  <= reg_sr(11) xor reg_sr(15);-- -4
        reg_sr(13)  <= reg_sr(12);               -- -3
        reg_sr(14)  <= reg_sr(13);               -- -2
        reg_sr(15)  <= reg_sr(14);               -- -1
      end if;
    end if;
  end process;

end RTL;
