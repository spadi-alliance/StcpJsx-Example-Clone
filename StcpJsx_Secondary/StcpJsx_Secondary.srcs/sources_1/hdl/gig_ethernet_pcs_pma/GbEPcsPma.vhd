-- (c) Copyright 2009 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
-- 
-- 
--------------------------------------------------------------------------------
-- Description: This is the top level vhdl example design for the
--              Ethernet 1000BASE-X PCS/PMA core.
--
--              This design example instantiates IOB flip-flops
--              and input/output buffers on the GMII.
--
--              A Transmitter Elastic Buffer is instantiated on the Tx
--              GMII path to perform clock compenstation between the
--              core and the external MAC driving the Tx GMII.
--
--              This design example can be synthesised.
--
--
--
--    ----------------------------------------------------------------
--    |                             Example Design                   |
--    |                                                              |
--    |             ----------------------------------------------   |
--    |             |           Core Block (wrapper)             |   |
--    |             |                                            |   |
--    |             |   --------------          --------------   |   |
--    |             |   |    Core    |          | tranceiver |   |   |
--    |             |   |            |          |            |   |   |
--    |  ---------  |   |            |          |            |   |   |
--    |  |       |  |   |            |          |            |   |   |
--    |  |  Tx   |  |   |            |          |            |   |   |
--  ---->|Elastic|----->| GMII       |--------->|        TXP |--------->
--    |  |Buffer |  |   | Tx         |          |        TXN |   |   |
--    |  |       |  |   |            |          |            |   |   |
--    |  ---------  |   |            |          |            |   |   |
--    | GMII        |   |            |          |            |   |   |
--    | IOBs        |   |            |          |            |   |   |
--    |             |   |            |          |            |   |   |
--    |             |   | GMII       |          |        RXP |   |   |
--  <-------------------| Rx         |<---------|        RXN |<---------
--    |             |   |            |          |            |   |   |
--    |             |   --------------          --------------   |   |
--    |             |                                            |   |
--    |             ----------------------------------------------   |
--    |                                                              |
--    ----------------------------------------------------------------
--
--


library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;


--------------------------------------------------------------------------------
-- The entity declaration for the example design
--------------------------------------------------------------------------------

entity GbEPcsPma is
  generic(
    gtClockPath   : std_logic_vector(2 downto 0):= "001"
    );
  port(

    --An independent clock source used as the reference clock for an
    --IDELAYCTRL (if present) and for the main GT transceiver reset logic.
    --This example design assumes that this is of frequency 200MHz.
    independent_clock        : in std_logic;

    -- common clocks --
    gtrefclk                 : in std_logic;                         
    gtrefclk_bufg            : in std_logic;
    
    gt0_qplloutclk           : in std_logic;
    gt0_qplloutrefclk        : in std_logic;

    userclk                  : in std_logic;
    userclk2                 : in std_logic;
    rxuserclk                : in std_logic;                  
    rxuserclk2               : in std_logic;

    mmcm_locked              : in std_logic;
    mmcm_reset               : out std_logic;

    -- clockout --
    txoutclk                 : out std_logic;
    rxoutclk                 : out std_logic;

    -- Tranceiver Interface
    -----------------------
    txp                  : out std_logic;      -- Differential +ve of serial transmission from PMA to PMD.
    txn                  : out std_logic;      -- Differential -ve of serial transmission from PMA to PMD.
    rxp                  : in std_logic;       -- Differential +ve for serial reception from PMD to PMA.
    rxn                  : in std_logic;       -- Differential -ve for serial reception from PMD to PMA.

    -- GMII Interface (client MAC <=> PCS)
    --------------------------------------
    gmii_tx_clk          : in std_logic;                     -- Transmit clock from client MAC.
    gmii_rx_clk          : out std_logic;                    -- Receive clock to client MAC.
    gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
    gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
    gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
    gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
    gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
    gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
    -- Management: MDIO Interface
    -----------------------------

    mdc                  : in    std_logic;                  -- Management Data Clock
    mdio_i               : in    std_logic;                  -- Management Data In
    mdio_o               : out   std_logic;                  -- Management Data Out
    mdio_t               : out   std_logic;                  -- Management Data Tristate
    phyaddr              : in std_logic_vector(4 downto 0);     
    configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
    configuration_valid  : in std_logic;                     -- Validation signal for Config vector.

    -- General IO's
    ---------------
    status_vector        : out std_logic_vector(15 downto 0); -- Core status.
    reset                : in std_logic                       -- Asynchronous reset for entire core.
--    signal_detect        : in std_logic                      -- Input from PMD to indicate presence of optical input.
    );
end GbEPcsPma;



architecture wrapper of GbEPcsPma is
  attribute DowngradeIPIdentifiedWarnings: string;
  attribute DowngradeIPIdentifiedWarnings of wrapper : architecture is "yes";

  constant signal_detect  : std_logic:= '1';
  
  -----------------------------------------------------------------------------
  -- Component Declaration for the Transmitter Elastic Buffer
  -----------------------------------------------------------------------------
  component gig_ethernet_pcs_pma_tx_elastic_buffer
    port (

      reset                : in std_logic;                     -- Asynchronous Reset.

      -- Signals received from the input gmii_tx_clk_wr domain.
      ---------------------------------------------------------

      gmii_tx_clk_wr       : in std_logic;                     -- Write clock domain.
      gmii_txd_wr          : in std_logic_vector(7 downto 0);  -- gmii_txd synchronous to gmii_tx_clk_wr.
      gmii_tx_en_wr        : in std_logic;                     -- gmii_tx_en synchronous to gmii_tx_clk_wr.
      gmii_tx_er_wr        : in std_logic;                     -- gmii_tx_er synchronous to gmii_tx_clk_wr.

      -- Signals transfered onto the new gmii_tx_clk_rd domain.
      ---------------------------------------------------------

      gmii_tx_clk_rd       : in std_logic;                     -- Read clock domain.
      gmii_txd_rd          : out std_logic_vector(7 downto 0); -- gmii_txd synchronous to gmii_tx_clk_rd.
      gmii_tx_en_rd        : out std_logic;                    -- gmii_tx_en synchronous to gmii_tx_clk_rd.
      gmii_tx_er_rd        : out std_logic                     -- gmii_tx_er synchronous to gmii_tx_clk_rd.
      );
  end component;

  ------------------------------------------------------------------------------
  -- Component Declaration for the Core Block
  ------------------------------------------------------------------------------

  component gig_ethernet_pcs_pma
    port (
      -- Transceiver Interface
      ---------------------
      gtrefclk             : in std_logic;                    
      gtrefclk_bufg        : in std_logic; 
      txp                  : out std_logic;                    -- Differential +ve of serial transmission from PMA to PMD.
      txn                  : out std_logic;                    -- Differential -ve of serial transmission from PMA to PMD.
      rxp                  : in std_logic;                     -- Differential +ve for serial reception from PMD to PMA.
      rxn                  : in std_logic;                     -- Differential -ve for serial reception from PMD to PMA.

      txoutclk             : out std_logic;                   
      rxoutclk             : out std_logic;                   
      resetdone            : out std_logic;                    -- The GT transceiver has completed its reset cycle
      cplllock             : out std_logic;                    
      mmcm_reset           : out std_logic;                    
      mmcm_locked          : in std_logic;                     -- Locked indication from MMCM
      userclk              : in std_logic;                    
      userclk2             : in std_logic;                    
      rxuserclk              : in std_logic;                  
      rxuserclk2             : in std_logic;                  
      independent_clock_bufg : in std_logic;                  
      pma_reset            : in std_logic;                     -- transceiver PMA reset signal
      -- GMII Interface
      -----------------
      gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
      gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
      gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.

      -- Management: MDIO Interface
      -----------------------------

      mdc                  : in std_logic;                     -- Management Data Clock
      mdio_i               : in std_logic;                     -- Management Data In
      mdio_o               : out std_logic;                    -- Management Data Out
      mdio_t               : out std_logic;                    -- Management Data Tristate
      phyaddr              : in std_logic_vector(4 downto 0);  
      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
      configuration_valid  : in std_logic;                     -- Validation signal for Config vector.

      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
      
      signal_detect             : in std_logic;                      -- Input from PMD to indicate presence of optical input.

      gt0_qplloutclk_in                          : in   std_logic;
      gt0_qplloutrefclk_in                       : in   std_logic
      );
  end component;

  component gig_ethernet_pcs_pma_resets
    port (
      reset                    : in  std_logic;                -- Asynchronous reset for entire core.
      independent_clock_bufg   : in  std_logic;                -- System clock 
      pma_reset                : out std_logic                 -- Synchronous transcevier PMA reset
      );
  end component;

  -- GT Interface
  ----------------
  SIGNAL pma_reset             : std_logic;


  ------------------------------------------------------------------------------
  -- internal signals used in this top level example design.
  ------------------------------------------------------------------------------

  -- An independent clock source used as the reference clock for an
  -- IDELAYCTRL (if present) and for the main GT transceiver reset logic.

  -- GMII signals
  signal gmii_txd_reg          : std_logic_vector(7 downto 0); -- Internal gmii_txd signal.
  signal gmii_tx_en_reg        : std_logic;                    -- Internal gmii_tx_en signal.
  signal gmii_tx_er_reg        : std_logic;                    -- Internal gmii_tx_er signal.
  signal gmii_txd_fifo         : std_logic_vector(7 downto 0); -- gmii_txd signal after Tx Elastic Buffer.
  signal gmii_tx_en_fifo       : std_logic;                    -- gmii_tx_en signal after Tx Elastic Buffer.
  signal gmii_tx_er_fifo       : std_logic;                    -- gmii_tx_er signal after Tx Elastic Buffer.
  
  signal gmii_rxd_int          : std_logic_vector(7 downto 0); -- Internal gmii_rxd signal.
  signal gmii_rx_dv_int        : std_logic;                    -- Internal gmii_rx_dv signal.
  signal gmii_rx_er_int        : std_logic;                    -- Internal gmii_rx_er signal.
  
begin


  ------------------------------------------------------------------------------
  -- Instantiate the Core Block
  ------------------------------------------------------------------------------
  pcs_pma_i : gig_ethernet_pcs_pma
    port map(
      -- Transceiver Interface
      ---------------------
      gtrefclk             => gtrefclk,
      gtrefclk_bufg        => gtrefclk_bufg,
      txp                  => txp,
      txn                  => txn,
      rxp                  => rxp,
      rxn                  => rxn,

      txoutclk             => txoutclk,
      rxoutclk             => rxoutclk,
      resetdone            => open,
      cplllock             => open,
      mmcm_reset           => mmcm_reset,
      mmcm_locked          => mmcm_locked,
      userclk              => userclk,
      userclk2             => userclk2,
      rxuserclk              => rxuserclk,
      rxuserclk2             => rxuserclk2,
      independent_clock_bufg => independent_clock,
      pma_reset            => pma_reset,
      -- GMII Interface
      -----------------
      gmii_txd             => gmii_txd_fifo,
      gmii_tx_en           => gmii_tx_en_fifo,
      gmii_tx_er           => gmii_tx_er_fifo,
      gmii_rxd             => gmii_rxd_int,
      gmii_rx_dv           => gmii_rx_dv_int,
      gmii_rx_er           => gmii_rx_er_int,
      gmii_isolate         => open,

      -- Management: MDIO Interface
      -----------------------------

      mdc                  => mdc,
      mdio_i               => mdio_i,
      mdio_o               => mdio_o,
      mdio_t               => mdio_t,
      phyaddr              => phyaddr,
      configuration_vector => configuration_vector,
      configuration_valid  => configuration_valid,

      -- General IO's
      ---------------
      status_vector        => status_vector,
      reset                => reset,
      
      signal_detect        => signal_detect,

      gt0_qplloutclk_in     => gt0_qplloutclk,
      gt0_qplloutrefclk_in  => gt0_qplloutrefclk
      );

  core_resets_i : gig_ethernet_pcs_pma_resets
    port map(
      reset                    => reset,
      independent_clock_bufg   => independent_clock,
      pma_reset                => pma_reset
      );

  -----------------------------------------------------------------------------
  -- GMII transmitter data logic
  -----------------------------------------------------------------------------
  
  -- Reclock onto regional clock routing.
  process (gmii_tx_clk)
  begin
    if gmii_tx_clk'event and gmii_tx_clk = '1' then
      gmii_txd_reg    <= gmii_txd;
      gmii_tx_en_reg  <= gmii_tx_en;
      gmii_tx_er_reg  <= gmii_tx_er;

    end if;
  end process;

  -- Component Instantiation for the Transmitter Elastic Buffer
  tx_elastic_buffer_inst : gig_ethernet_pcs_pma_tx_elastic_buffer
    port map (
      reset            => reset,
      
      gmii_tx_clk_wr   => gmii_tx_clk,
      gmii_txd_wr      => gmii_txd_reg,
      gmii_tx_en_wr    => gmii_tx_en_reg,
      gmii_tx_er_wr    => gmii_tx_er_reg,
      gmii_tx_clk_rd   => userclk2,
      gmii_txd_rd      => gmii_txd_fifo,
      gmii_tx_en_rd    => gmii_tx_en_fifo,
      gmii_tx_er_rd    => gmii_tx_er_fifo
      );



  -----------------------------------------------------------------------------
  -- GMII receiver data logic
  -----------------------------------------------------------------------------
  gmii_rx_clk   <= userclk2;

  -- Drive Rx GMII signals through IOB output flip-flops (inferred).
  process (userclk2)
  begin
    if userclk2'event and userclk2 = '1' then
      gmii_rxd   <= gmii_rxd_int;
      gmii_rx_dv <= gmii_rx_dv_int;
      gmii_rx_er <= gmii_rx_er_int;

    end if;
  end process;

end wrapper;
