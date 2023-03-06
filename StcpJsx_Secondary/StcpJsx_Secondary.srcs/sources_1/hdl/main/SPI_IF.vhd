----------------------------------------------------------------------------
--! @file   SPI_IF.vhd
--! @brief  SPI interface to SPI Flash ROM
--! @author Takehiro Shiozaki
--! @date   2014-06-24
--!
--! @modify
--! @author Ryotaro Honda
--! @date   2019-03-xx
----------------------------------------------------------------------------

library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use mylib.defSPI_IF.all;

Library UNISIM;
use UNISIM.vcomponents.all;


entity SPI_IF is
  generic(
    genSTARTUPE2 : boolean:= true;
    invClk       : std_logic:= '0'
  );
  port(
    clk         : in std_logic;
    rst         : in std_logic;

    dIn         : in std_logic_vector(kWidthDataPerCycle-1 downto 0);
    dOut        : out std_logic_vector(kWidthDataPerCycle-1 downto 0);
    start       : in std_logic;
    busy        : out std_logic;

    sclkSpi     : out std_logic;
    mosiSpi     : out std_logic;
    misoSpi     : in std_logic
    );
end SPI_IF;

architecture RTL of SPI_IF is
  attribute mark_debug  : string;

  signal reg_din : std_logic_vector(kWidthDataPerCycle-1 downto 0);

  signal bit_sel : std_logic_vector(kWidthBitSel-1 downto 0);
  signal bit_sel_count_down : std_logic;
  signal bit_sel_count_clear : std_logic;

  signal reg_shift : std_logic_vector(kWidthDataPerCycle-1 downto 0);
  signal reg_shift_enable : std_logic;

  signal reg_sclk_spi : std_logic;
  signal sclk_spi_pre : std_logic;
  signal mosi_spi_pre : std_logic;

  type State is (IDLE, PREPARE, SCLK_LOW, SCLK_HIGH, PAUSE);
  signal current_state, next_state : State;

  -- debug --
  -- attribute mark_debug of sclk_spi_pre  : signal is "true";
  -- attribute mark_debug of mosi_spi_pre  : signal is "true";
  -- attribute mark_debug of misoSpi       : signal is "true";
  -- attribute mark_debug of reg_spid      : signal is "true";
  -- attribute mark_debug of reg_shift_enable  : signal is "true";
  -- attribute mark_debug of dIn           : signal is "true";
  -- attribute mark_debug of dOut          : signal is "true";
begin
  -- =========================== body =========================== --

  process(clk, rst)
  begin
    if(rst = '1') then
      reg_din   <= (others => '0');
    elsif(clk'event and clk = '1') then
      if(start = '1') then
        reg_din <= dIn;
      end if;
    end if;
  end process;

  mosi_spi_pre <= reg_din(conv_integer(bit_sel));

  process(clk, rst)
  begin
    if(rst = '1') then
      reg_shift <= (others => '0');
    elsif(clk'event and clk = '1') then
      if(reg_shift_enable = '1') then
        reg_shift <= reg_shift(kWidthDataPerCycle-2 downto 0) & misoSpi;
      end if;
    end if;
  end process;

  dOut <= reg_shift;

  process(clk, rst)
  begin
    if(rst = '1') then
      bit_sel <= (others => '0');
    elsif(clk'event and clk = '1') then
      if(bit_sel_count_clear = '1') then
        bit_sel <= (others => '1');
      elsif(bit_sel_count_down = '1') then
        bit_sel <= bit_sel - 1;
      end if;
    end if;
  end process;

  process(clk, rst)
  begin
    if(rst = '1') then
      current_state <= IDLE;
    elsif(clk'event and clk = '1') then
      current_state <= next_state;
    end if;
  end process;

  process(current_state, start, bit_sel)
  begin
    case current_state is
      when IDLE =>
        if(start = '1') then
          next_state <= PREPARE;
        else
          next_state <= current_state;
        end if;
      when PREPARE =>
        next_state <= SCLK_LOW;
      when SCLK_LOW =>
        next_state <= SCLK_HIGH;
      when SCLK_HIGH =>
        if(bit_sel = 0) then
          next_state <= PAUSE;
        else
          next_state <= SCLK_LOW;
        end if;
      when PAUSE =>
        next_state <= IDLE;
      when others =>
        next_state <= IDLE;
    end case;
  end process;

  sclk_spi_pre          <= '1' when(current_state = SCLK_HIGH) else '0';
  reg_shift_enable      <= '1' when(current_state = SCLK_HIGH) else '0';
  bit_sel_count_down    <= '1' when(current_state = SCLK_HIGH) else '0';
  bit_sel_count_clear   <= '1' when(current_state = IDLE) else '0';
  busy                  <= '1' when(current_state /= IDLE) else '0';


  process(clk, rst)
  begin
    if(rst = '1') then
      reg_sclk_spi <= '0';
    elsif(clk'event and clk = '1') then
      reg_sclk_spi <= sclk_spi_pre xor invClk;
    end if;
  end process;

  process(clk, rst)
  begin
    if(rst = '1') then
      mosiSpi <= '0';
    elsif(clk'event and clk = '1') then
      mosiSpi <= mosi_spi_pre;
    end if;
  end process;

  gen_sclk: if genSTARTUPE2 = false generate
    sclkSpi   <= reg_sclk_spi;
  end generate;

  gen_startupe2: if genSTARTUPE2 = true generate
    sclkSpi   <= '0';
    u_STARTUPE2 : STARTUPE2
      generic map (
          PROG_USR => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
          SIM_CCLK_FREQ => 0.0  -- Set the Configuration Clock Frequency(ns) for simulation.
      )
      port map (
          CFGCLK  => open,              -- 1-bit output: Configuration main clock output
          CFGMCLK   => open,            -- 1-bit output: Configuration internal oscillator clock output
          EOS       => open,            -- 1-bit output: Active high output signal indicating the End Of Startup.
          PREQ      => open,            -- 1-bit output: PROGRAM request to fabric output
          CLK       => '0',             -- 1-bit input: User start-up clock input
          GSR       => '0',             -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
          GTS       => '0',             -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
          KEYCLEARB => '0',             -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
          PACK      => '0' ,            -- 1-bit input: PROGRAM acknowledge input
          USRCCLKO  => reg_sclk_spi,    -- 1-bit input: User CCLK input
          USRCCLKTS => '0',             -- 1-bit input: User CCLK 3-state enable input
          USRDONEO  => '1',             -- 1-bit input: User DONE pin output control
          USRDONETS => '1'              -- 1-bit input: User DONE 3-state enable output
      );

  end generate;

end RTL;
