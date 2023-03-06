library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_MISC.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

library mylib;

entity GtClockDistributer2 is
  port(
    -- GTX refclk --
    GT_REFCLK_P   : in std_logic;
    GT_REFCLK_N   : in std_logic;
    
    gtRefClk      : out std_logic;
    gtRefClkBufg  : out std_logic;

    -- USERCLK2 --
    mmcmReset     : in std_logic;
    mmcmLocked    : out std_logic;
    txOutClk      : in std_logic;
    rxOutClk      : in std_logic;
    
    userClk       : out std_logic;
    userClk2      : out std_logic;
    rxuserClk     : out std_logic;
    rxuserClk2    : out std_logic;

    -- GTXE_COMMON --
    reset         : in std_logic;
    clkIndep      : in std_logic;
    clkQPLL       : out std_logic;
    refclkQPLL    : out std_logic
    
);
end GtClockDistributer2;
  
architecture tool_wrapper of GtClockDistributer2 is
   attribute DowngradeIPIdentifiedWarnings: string;
   attribute DowngradeIPIdentifiedWarnings of tool_wrapper : architecture is "yes";

  -- GTX_REF --
  signal gtrefclk_i     : std_logic;
  
  component gig_ethernet_pcs_pma_clocking is
    port (
      gtrefclk_p     : in  std_logic;  -- Differential +ve of reference clock for MGT: 125MHz, very high quality.
      gtrefclk_n     : in  std_logic;  -- Differential -ve of reference clock for MGT: 125MHz, very high quality.
      txoutclk       : in  std_logic;  -- txoutclk from GT transceiver.
      rxoutclk       : in  std_logic;  -- rxoutclk from GT transceiver.
      mmcm_reset     : in  std_logic;  -- MMCM Reset
                                      
      gtrefclk       : out std_logic;  -- gtrefclk routed through an IBUFG.
      gtrefclk_bufg  : out std_logic;  -- gtrefclk routed through a BUFG for driving logic.     
      mmcm_locked    : out std_logic;  -- MMCM locked
      userclk        : out std_logic;  -- for GT PMA reference clock
      userclk2       : out std_logic;  -- 125MHz clock for core reference clock.
      rxuserclk      : out std_logic;  -- for GT PMA reference clock
      rxuserclk2     : out std_logic   -- 125MHz clock for core reference clock.
      );
  end component;

  -- GTXE COMMON --
  signal rst_pma        : std_logic;

 component gig_ethernet_pcs_pma_resets
    port (
      reset                    : in  std_logic;  -- Asynchronous reset for entire core.
      independent_clock_bufg   : in  std_logic;  -- System clock 
      pma_reset                : out std_logic   -- Synchronous transcevier PMA reset
      );
  end component;
  
  component gig_ethernet_pcs_pma_gt_common
    port(
      GTREFCLK0_IN         : in std_logic;
      QPLLLOCK_OUT         : out std_logic;
      QPLLLOCKDETCLK_IN    : in std_logic;
      QPLLOUTCLK_OUT       : out std_logic;
      QPLLOUTREFCLK_OUT    : out std_logic;
      QPLLREFCLKLOST_OUT   : out std_logic;    
      QPLLRESET_IN         : in std_logic
      );
  end component;
  
begin
  
  core_clocking_i : gig_ethernet_pcs_pma_clocking 
    port map(
      gtrefclk_p     => GT_REFCLK_P,
      gtrefclk_n     => GT_REFCLK_N,
      txoutclk       => txOutClk,
      rxoutclk       => rxOutClk,
      mmcm_reset     => mmcmReset,
                                      
      gtrefclk       => gtrefclk_i,
      gtrefclk_bufg  => gtRefClkBufg,
      mmcm_locked    => mmcmLocked,
      userclk        => userClk,
      userclk2       => userClk2,
      rxuserclk      => rxuserClk,
      rxuserclk2     => rxuserClk2
      );

  gtRefClk  <= gtrefclk_i;

  core_resets_i : gig_ethernet_pcs_pma_resets
    port map (
      reset                     => reset, 
      independent_clock_bufg    => clkIndep,
      pma_reset                 => rst_pma
      );

  core_gt_common_i : gig_ethernet_pcs_pma_gt_common
    port map(
      GTREFCLK0_IN                => gtrefclk_i ,
      QPLLLOCK_OUT                => open,
      QPLLLOCKDETCLK_IN           => clkIndep,
      QPLLOUTCLK_OUT              => clkQPLL,
      QPLLOUTREFCLK_OUT           => refclkQPLL,
      QPLLREFCLKLOST_OUT          => open,    
      QPLLRESET_IN                => rst_pma
      );
  
end tool_wrapper;
