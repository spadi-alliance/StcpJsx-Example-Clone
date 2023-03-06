library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defBCT.all;
use mylib.defSiTCP.all;

library UNISIM;
use UNISIM.VComponents.all;

entity RbcpCdc is
  port(
    -- System clock domain --
    rstSys      : in std_logic;
    clkSys      : in std_logic;
    rbcpAddr    : out std_logic_vector(kWidthAddrRBCP-1 downto 0);
    rbcpWd      : out std_logic_vector(kWidthDataRBCP-1 downto 0);
    rbcpWe      : out std_logic;
    rbcpRe      : out std_logic;
    rbcpAck     : in std_logic;
    rbcpRd      : in std_logic_vector(kWidthDataRBCP-1 downto 0);

    -- XGMII clock domain --
    rstXgmii    : in std_logic;
    clkXgmii    : in std_logic;
    rbcpXgAddr  : in std_logic_vector(kWidthAddrRBCP-1 downto 0);
    rbcpXgWd    : in std_logic_vector(kWidthDataRBCP-1 downto 0);
    rbcpXgWe    : in std_logic;
    rbcpXgRe    : in std_logic;
    rbcpXgAck   : out std_logic;
    rbcpXgRd    : out std_logic_vector(kWidthDataRBCP-1 downto 0)
    );
end RbcpCdc;

architecture RTL of RbcpCdc is
  -- signal declaration ---------------------------------------------------
  constant kWidthXtoS : integer:= kWidthAddrRBCP + kWidthDataRBCP + 2;
  signal reg_sys_out, reg_xgmii_in  : std_logic_vector(kWidthXtoS-1 downto 0);

  constant kWidthStoX : integer:= kWidthDataRBCP + 1;
  signal reg_sys_in, reg_xgmii_out  : std_logic_vector(kWidthStoX-1 downto 0);

-- ================================ body ==================================
begin
  -- signal connection ----------------------------------------------------


  -- XGMII to SYSTEM --
  rbcpAddr  <= reg_sys_out(kWidthXtoS-1 downto kWidthXtoS-kWidthAddrRBCP);
  rbcpWd    <= reg_sys_out(kWidthXtoS-kWidthAddrRBCP-1 downto kWidthXtoS-kWidthAddrRBCP-kWidthDataRBCP);
  rbcpWe    <= reg_sys_out(1);
  rbcpRe    <= reg_sys_out(0);

  reg_xgmii_in(kWidthXtoS-1 downto kWidthXtoS-kWidthAddrRBCP)                                 <= rbcpXgAddr;
  reg_xgmii_in(kWidthXtoS-kWidthAddrRBCP-1 downto kWidthXtoS-kWidthAddrRBCP-kWidthDataRBCP)   <= rbcpXgWd;
  reg_xgmii_in(1)   <= rbcpXgWe;
  reg_xgmii_in(0)   <= rbcpXgRe;

  u_we_to_sys : xpm_cdc_pulse
   generic map (
      DEST_SYNC_FF   => 6,   -- DECIMAL; range: 2-10
      INIT_SYNC_FF   => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      REG_OUTPUT     => 0,   -- DECIMAL; 0=disable registered output, 1=enable registered output
      RST_USED       => 1,   -- DECIMAL; 0=no reset, 1=implement reset
      SIM_ASSERT_CHK => 0    -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   )
   port map (
      dest_pulse  => reg_sys_out(1),
      dest_clk    => clkSys,
      dest_rst    => rstSys,
      src_clk     => clkXgmii,
      src_pulse   => reg_xgmii_in(1),
      src_rst     => rstXgmii
   );

  u_re_to_sys : xpm_cdc_pulse
   generic map (
      DEST_SYNC_FF   => 6,   -- DECIMAL; range: 2-10
      INIT_SYNC_FF   => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      REG_OUTPUT     => 0,   -- DECIMAL; 0=disable registered output, 1=enable registered output
      RST_USED       => 0,   -- DECIMAL; 0=no reset, 1=implement reset
      SIM_ASSERT_CHK => 0    -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   )
   port map (
      dest_pulse  => reg_sys_out(0),
      dest_clk    => clkSys,
      dest_rst    => rstSys,
      src_clk     => clkXgmii,
      src_pulse   => reg_xgmii_in(0),
      src_rst     => rstXgmii
   );

  u_xgmii_to_system : xpm_cdc_array_single
  generic map (
     DEST_SYNC_FF     => 5,   -- DECIMAL; range: 2-10
     INIT_SYNC_FF     => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
     SIM_ASSERT_CHK   => 0,   -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
     SRC_INPUT_REG    => 1,   -- DECIMAL; 0=do not register input, 1=register input
     WIDTH            => kWidthXtoS-2  -- DECIMAL; range: 1-1024
  )
  port map (
     dest_out   => reg_sys_out(kWidthXtoS-1 downto 2),
     dest_clk   => clkSys,
     src_clk    => clkXgmii,
     src_in     => reg_xgmii_in(kWidthXtoS-1 downto 2)
  );

  -- SYSTEM to XGMII --
  rbcpXgRd  <= reg_xgmii_out(kWidthStoX-1 downto kWidthStoX-kWidthDataRBCP);
  rbcpXgAck <= reg_xgmii_out(0);

  reg_sys_in(kWidthStoX-1 downto kWidthStoX-kWidthDataRBCP)   <= rbcpRd;
  reg_sys_in(0)   <= rbcpAck;

  u_ack_to_xgmii : xpm_cdc_pulse
   generic map (
      DEST_SYNC_FF   => 6,   -- DECIMAL; range: 2-10
      INIT_SYNC_FF   => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
      REG_OUTPUT     => 0,   -- DECIMAL; 0=disable registered output, 1=enable registered output
      RST_USED       => 0,   -- DECIMAL; 0=no reset, 1=implement reset
      SIM_ASSERT_CHK => 0    -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   )
   port map (
      dest_pulse  => reg_xgmii_out(0),
      dest_clk    => clkXgmii,
      dest_rst    => rstXgmii,
      src_clk     => clkSys,
      src_pulse   => reg_sys_in(0),
      src_rst     => rstSys
   );

  u_system_to_xgmii : xpm_cdc_array_single
  generic map (
     DEST_SYNC_FF     => 6,   -- DECIMAL; range: 2-10
     INIT_SYNC_FF     => 0,   -- DECIMAL; 0=disable simulation init values, 1=enable simulation init values
     SIM_ASSERT_CHK   => 0,   -- DECIMAL; 0=disable simulation messages, 1=enable simulation messages
     SRC_INPUT_REG    => 1,   -- DECIMAL; 0=do not register input, 1=register input
     WIDTH            => kWidthStoX-1  -- DECIMAL; range: 1-1024
  )
  port map (
     dest_out   => reg_xgmii_out(kWidthStoX-1 downto 1),
     dest_clk   => clkXgmii,
     src_clk    => clkSys,
     src_in     => reg_sys_in(kWidthStoX-1 downto 1)
  );

end RTL;

