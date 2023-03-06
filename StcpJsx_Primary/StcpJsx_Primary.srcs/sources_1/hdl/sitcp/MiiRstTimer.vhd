library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.std_logic_unsigned.all;

library mylib;
use mylib.defMiiRstTimer.all;

entity MiiRstTimer is
  port (
    rst         : in std_logic;
    clk         : in std_logic;
    rstMiiOut   : out std_logic
    );
end MiiRstTimer;

architecture RTL of MiiRstTimer is
  attribute keep : string;
  
  -- signal decralation -----------------------------------------------------
  signal clk_src  : std_logic_vector(kNumInstance downto 0);
  signal clk_div  : std_logic_vector(kNumInstance-1 downto 0);
  signal clk_2kHz : std_logic;

  signal reg_reset    : std_logic;
  signal reg_counter  : std_logic_vector(kPresetCount'range);

begin
  -- ====================== body ============================= --
  clk_2kHz  <= clk_div(kNumInstance-1);
  
  clk_src(0)  <= clk;
  gen_clkdiv : for i in 0 to kNumInstance-1 generate
  begin
    clk_src(i+1)  <= clk_div(i);
    
    uDiv10 : entity mylib.Division10
      port map(
        rst       => rst,
        clk       => clk_src(i),
        clkDiv10  => clk_div(i)
      );
  end generate;

  process(clk_2kHz, rst)
  begin
    if(rst = '1') then
      reg_reset     <= '0';
      reg_counter   <= (others=> '0');
    elsif(clk_2kHz'event and clk_2kHz = '1') then
      if(reg_counter = kPresetCount) then
        reg_reset   <= '1';
      else
        reg_counter   <= reg_counter +1;
      end if;
    end if;
  end process;

  uOneShotRst : entity mylib.EdgeDetector
    port map(
      rst   => rst,
      clk   => clk_2kHz,
      dIn   => reg_reset,
      dOut  => rstMiiOut
      );

end RTL;
