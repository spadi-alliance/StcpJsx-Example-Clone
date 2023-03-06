library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library mylib;
use mylib.defResetGen.all;

entity ResetGen is
    port (
      rst       : in std_logic;
      clk       : in std_logic;
      resetOut  : out std_logic
      );
end ResetGen;

architecture RTL of ResetGen is
  -- Internal signal declaration ---------------------------------------
  signal reset_shiftreg : std_logic_vector(kWidthResetSync-1 downto 0);
  signal sync_reset     : std_logic;

begin
  --============================ body ==================================
  resetOut  <= sync_reset;

  sync_reset  <= reset_shiftreg(kWidthResetSync-1);
  u_sync_base_reset : process(rst, clk)
  begin
    if(rst = '1') then
      reset_shiftreg  <= (others => '1');
    elsif(clk'event and clk = '1') then
      reset_shiftreg  <= reset_shiftreg(kWidthResetSync-2 downto 0) & '0';
    end if;
  end process;

end RTL;
