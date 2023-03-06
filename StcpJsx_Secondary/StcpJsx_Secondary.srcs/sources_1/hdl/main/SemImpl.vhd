library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use mylib.defSEM.all;

Library UNISIM;
use UNISIM.vcomponents.all;

entity SemImpl is
  port(
    rst	                : in std_logic;
    rstCounter          : in std_logic;
    clkIcap             : in std_logic;
    
    -- module input --
    strobeErr           : in std_logic;
    addrErrInjection    : in std_logic_vector(kWidthErrAddr-1 downto 0);

    -- module output --
    statusOut           : out SemStatusType
    );
end SemImpl;

architecture RTL of SemImpl is
  attribute mark_debug        : string;
  
  -- internal signal declaration --------------------------------------
  signal reg_watchdog_alarm     : std_logic;
  signal counter_heartbeat      : std_logic_vector(kMaxCountHeartbeat'range);

  signal edge_correction        : std_logic;
  signal counter_correction     : std_logic_vector(kWidthCorrection-1 downto 0);

  signal reg_uncorrectable_alarm  : std_logic;
  
  -- sem ports signals --
  signal sem_heartbeat          : std_logic;
  signal sem_initialization     : std_logic;
  signal sem_observation        : std_logic;
  signal sem_correction         : std_logic;
  signal sem_classification     : std_logic;
  signal sem_injection          : std_logic;
  signal sem_essential          : std_logic;
  signal sem_uncorrectable      : std_logic;
                                
  constant dummy_txfull         : std_logic:= '0';
  constant dummy_rxdata         : std_logic_vector(kWidthMonData-1 downto 0):= (others => '0');
  constant dummy_rxempty        : std_logic:= '1';

--  signal error_inject_strobe    : std_logic;
--  signal error_inject_address   : std_logic_vector(kWidthErrAddr-1 downto 0);

  signal sem_icap_o             : std_logic_vector(kWidthIcapData-1 downto 0);
  signal sem_icap_csib          : std_logic;
  signal sem_icap_rdwrb         : std_logic;
  signal sem_icap_i             : std_logic_vector(kWidthIcapData-1 downto 0);
  constant sem_icap_grant       : std_logic:= '1';

  signal sem_fecc_crcerr        : std_logic;
  signal sem_fecc_eccerr        : std_logic;
  signal sem_fecc_eccerrsingle  : std_logic;
  signal sem_fecc_syndromevalid : std_logic;
  signal sem_fecc_syndrome      : std_logic_vector(kWidthSyndrome-1 downto 0);
  signal sem_fecc_far           : std_logic_vector(kWidthFar-1 downto 0);
  signal sem_fecc_synbit        : std_logic_vector(kWidthSynBit-1 downto 0);
  signal sem_fecc_synword       : std_logic_vector(kWidthSynWord-1 downto 0);

  component sem_controller
    port (
      -- status port --
      status_heartbeat        : out std_logic;
      status_initialization   : out std_logic;
      status_observation      : out std_logic;
      status_correction       : out std_logic;
      status_classification   : out std_logic;
      status_injection        : out std_logic;
      status_essential        : out std_logic;
      status_uncorrectable    : out std_logic;
      -- monitor port --
      monitor_txdata          : out std_logic_vector(kWidthMonData-1 downto 0);
      monitor_txwrite         : out std_logic;
      monitor_txfull          : in std_logic;
      monitor_rxdata          : in std_logic_vector(kWidthMonData-1 downto 0);
      monitor_rxread          : out std_logic;
      monitor_rxempty         : in std_logic;
      -- error injection port --
      inject_strobe           : in std_logic;
      inject_address          : in std_logic_vector(kWidthErrAddr-1 downto 0);
      -- icape2 port --
      icap_o                  : in std_logic_vector(kWidthIcapData-1 downto 0);
      icap_csib               : out std_logic;
      icap_rdwrb              : out std_logic;
      icap_i                  : out std_logic_vector(kWidthIcapData-1 downto 0);
      icap_clk                : in std_logic;
      icap_request            : out std_logic;
      icap_grant              : in std_logic;
      -- frame ecc port --
      fecc_crcerr             : in std_logic;
      fecc_eccerr             : in std_logic;
      fecc_eccerrsingle       : in std_logic;
      fecc_syndromevalid      : in std_logic;
      fecc_syndrome           : in std_logic_vector(kWidthSyndrome-1 downto 0);
      fecc_far                : in std_logic_vector(kWidthFar-1 downto 0);
      fecc_synbit             : in std_logic_vector(kWidthSynBit-1 downto 0);
      fecc_synword            : in std_logic_vector(kWidthSynWord-1 downto 0)
      );
  end component;
  
  -- debug --
  -- attribute mark_debug of reg_watchdog_alarm        : signal is "true";
  -- attribute mark_debug of counter_heartbeat         : signal is "true";
  -- attribute mark_debug of edge_correction           : signal is "true";
  -- attribute mark_debug of reg_uncorrectable_alarm   : signal is "true";
  -- attribute mark_debug of sem_heartbeat             : signal is "true";
  -- attribute mark_debug of sem_initialization        : signal is "true";    
  -- attribute mark_debug of sem_observation           : signal is "true";
  -- attribute mark_debug of sem_correction            : signal is "true";
  -- attribute mark_debug of sem_classification        : signal is "true";
  -- attribute mark_debug of sem_injection             : signal is "true";
  -- attribute mark_debug of sem_essential             : signal is "true";
  -- attribute mark_debug of sem_uncorrectable         : signal is "true";
  -- attribute mark_debug of sem_icap_csib             : signal is "true";

-- =============================== body ===============================
begin
  statusOut.watchdog_alarm       <= reg_watchdog_alarm;
  statusOut.counter_correction   <= counter_correction;
  statusOut.uncorrectable_alarm  <= reg_uncorrectable_alarm;
  
  -- SEM watchdog timer --
  u_Watchdog : process(clkiCap, rst)
  begin
    if(rst = '1') then
      counter_heartbeat     <= (others => '0');
      reg_watchdog_alarm    <= '0';
    elsif(clkIcap'event and clkIcap = '1') then
      if(sem_heartbeat = '1') then
        counter_heartbeat     <= (others => '0');
        reg_watchdog_alarm    <= '0';
      elsif(counter_heartbeat = kMaxCountHeartbeat) then
        reg_watchdog_alarm    <= '1';
      else
        counter_heartbeat     <= counter_heartbeat +1;
      end if;
    end if;
  end process;

  -- Counter correction --
  u_EdgeCorrection : entity mylib.EdgeDetector
    port map(
      rst  => rst,
      clk  => clkIcap,
      dIn  => sem_correction,
      dOut => edge_correction
      );

  u_CounterCorrection : process(clkIcap, rst, rstCounter)
  begin
    if(rst = '1' or rstCounter = '1') then
      counter_correction  <= (others => '0');
    elsif(clkIcap'event and clkIcap = '1') then
      if(rstCounter = '1') then
        counter_correction  <= (others => '0');
      elsif(edge_correction = '1') then
        counter_correction  <= counter_correction +1;
      end if;
    end if;
  end process;

  -- Uncorrectable error alarm --
  u_Uncorrectable : process(rst, clkIcap)
  begin
    if(rst = '1') then
      reg_uncorrectable_alarm   <= '0';
    elsif(clkIcap'event and clkIcap = '1') then
      if(sem_uncorrectable = '1') then
        reg_uncorrectable_alarm   <= '1';
      end if;
    end if;
  end process;
  
  -- ICAP --
  u_ICAPE2 : ICAPE2
   generic map (
      DEVICE_ID => X"3651093",     -- Specifies the pre-programmed Device ID
                                   -- value to be used for simulation
                                   -- purposes.
      ICAP_WIDTH => "X32",         -- Specifies the input and output data width.
      SIM_CFG_FILE_NAME => "NONE"  -- Specifies the Raw Bitstream (RBT) file to
                                   -- be parsed by the simulation
                                   -- model.
   )
   port map (
      O     => sem_icap_o,     -- 32-bit output: Configuration data output bus
      CLK   => clkIcap,        -- 1-bit input: Clock Input
      CSIB  => sem_icap_csib,  -- 1-bit input: Active-Low ICAP Enable
      I     => sem_icap_i,     -- 32-bit input: Configuration data input bus
      RDWRB => sem_icap_rdwrb  -- 1-bit input: Read/Write Select input
      );

  -- FRAME ESS --
  u_FRAME_ECCE2 : FRAME_ECCE2
   generic map (
      FARSRC => "EFAR",
      FRAME_RBT_IN_FILENAME => "NONE"
   )
   port map (
      CRCERROR        => sem_fecc_crcerr,
      ECCERROR        => sem_fecc_eccerr,
      ECCERRORSINGLE  => sem_fecc_eccerrsingle,
      FAR             => sem_fecc_far,
      SYNBIT          => sem_fecc_synbit,
      SYNDROME        => sem_fecc_syndrome,
      SYNDROMEVALID   => sem_fecc_syndromevalid,
      SYNWORD         => sem_fecc_synword
      );

  -- Instance of SEM controller --
  u_SEM : sem_controller
    port map(
      -- status port --
      status_heartbeat        => sem_heartbeat,
      status_initialization   => open,
      status_observation      => open,
      status_correction       => sem_correction,
      status_classification   => open,
      status_injection        => open,
      status_essential        => open,
      status_uncorrectable    => sem_uncorrectable,
      -- monitor port --
      monitor_txdata          => open,
      monitor_txwrite         => open,
      monitor_txfull          => dummy_txfull,
      monitor_rxdata          => dummy_rxdata,
      monitor_rxread          => open,
      monitor_rxempty         => dummy_rxempty,
      -- error injection port --
      inject_strobe           => strobeErr,
      inject_address          => addrErrInjection,
      -- icape2 port --
      icap_o                  => sem_icap_o,
      icap_csib               => sem_icap_csib,
      icap_rdwrb              => sem_icap_rdwrb,
      icap_i                  => sem_icap_i,
      icap_clk                => clkIcap,
      icap_request            => open,
      icap_grant              => sem_icap_grant,
      -- frame ecc port --
      fecc_crcerr             => sem_fecc_crcerr,
      fecc_eccerr             => sem_fecc_eccerr,
      fecc_eccerrsingle       => sem_fecc_eccerrsingle,
      fecc_syndromevalid      => sem_fecc_syndromevalid,
      fecc_syndrome           => sem_fecc_syndrome,
      fecc_far                => sem_fecc_far,
      fecc_synbit             => sem_fecc_synbit,
      fecc_synword            => sem_fecc_synword
  );



end RTL;

