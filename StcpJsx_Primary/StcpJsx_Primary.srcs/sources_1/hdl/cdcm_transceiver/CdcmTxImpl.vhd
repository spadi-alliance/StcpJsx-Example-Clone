library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

library UNIMACRO;
use UNIMACRO.Vcomponents.all;
--

entity CdcmTxImpl is
  generic
  (
    kSysW        : integer:= 1;  -- width of the ata for the system
    kDevW        : integer:= 10; -- width of the ata for the device
    kIoStandard  : string:= "LVDS" -- IOSTANDARD of OBUFDS
  );
  port
  (
    -- From the device to the system
    dInFromDevice   : in std_logic_vector(kDevW-1 downto 0);
    dOutToPinP      : out std_logic;
    dOutToPinN      : out std_logic;
    -- Clock and reset
    clkIn           : in std_logic;
    clkDivIn        : in std_logic;
    ioReset         : in std_logic
  );
end CdcmTxImpl;

architecture RTL of CdcmTxImpl is
  constant kMaxBit  : integer:= 14;
  signal din_oserdes  : std_logic_vector(kMaxBit-1 downto 0);
  signal ocascade_sm_d, ocascade_sm_t : std_logic;

  signal  data_out_to_pin   : std_logic;

begin

  u_Tx_OBUFDS_inst : OBUFDS
    generic map
    (
      IOSTANDARD => kIoStandard, -- Specify the output I/O standard
      SLEW       => "FAST"     -- Specify the output slew rate
    )
    port map
    (
      O  => dOutToPinP,      -- Diff_p output (connect directly to top-level port)
      OB => dOutToPinN,      -- Diff_n output (connect directly to top-level port)
      I  => data_out_to_pin  -- Buffer input
    );



  u_OSERDESE2_master : OSERDESE2
    generic map (
       DATA_RATE_OQ => "DDR",    -- DDR, SDR
       DATA_RATE_TQ => "SDR",    -- DDR, BUF, SDR
       DATA_WIDTH   => kDevW,    -- Parallel data width (2-8,10,14)
       SERDES_MODE  => "MASTER", -- MASTER, SLAVE
       TRISTATE_WIDTH => 1       -- 3-state converter width (1,4)
    )
    port map (
       OFB => open,             -- 1-bit output: Feedback path for data
       OQ => data_out_to_pin,               -- 1-bit output: Data path output
       -- SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
       SHIFTOUT1 => open,
       SHIFTOUT2 => open,
       TBYTEOUT => open,   -- 1-bit output: Byte group tristate
       TFB => open,             -- 1-bit output: 3-state control
       TQ => open,               -- 1-bit output: 3-state control
       CLK => clkIn,             -- 1-bit input: High speed clock
       CLKDIV => clkDivIn,       -- 1-bit input: Divided clock
       -- D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
       D1 => din_oserdes(13),
       D2 => din_oserdes(12),
       D3 => din_oserdes(11),
       D4 => din_oserdes(10),
       D5 => din_oserdes(9),
       D6 => din_oserdes(8),
       D7 => din_oserdes(7),
       D8 => din_oserdes(6),
       OCE => '1',             -- 1-bit input: Output data clock enable
       RST => ioReset,             -- 1-bit input: Reset
       -- SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
       SHIFTIN1 => ocascade_sm_d,
       SHIFTIN2 => ocascade_sm_t,
       -- T1 - T4: 1-bit (each) input: Parallel 3-state inputs
       T1 => '0',
       T2 => '0',
       T3 => '0',
       T4 => '0',
       TBYTEIN => '0',     -- 1-bit input: Byte group tristate
       TCE => '0'              -- 1-bit input: 3-state clock enable
    );

  u_OSERDESE2_slave : OSERDESE2
    generic map (
       DATA_RATE_OQ => "DDR",    -- DDR, SDR
       DATA_RATE_TQ => "SDR",    -- DDR, BUF, SDR
       DATA_WIDTH   => kDevW,    -- Parallel data width (2-8,10,14)
       SERDES_MODE  => "SLAVE",  -- MASTER, SLAVE
       TRISTATE_WIDTH => 1       -- 3-state converter width (1,4)
    )
    port map (
       OFB => open,             -- 1-bit output: Feedback path for data
       OQ => open,               -- 1-bit output: Data path output
       -- SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
       SHIFTOUT1 => ocascade_sm_d,
       SHIFTOUT2 => ocascade_sm_t,
       TBYTEOUT => open,   -- 1-bit output: Byte group tristate
       TFB => open,             -- 1-bit output: 3-state control
       TQ => open,               -- 1-bit output: 3-state control
       CLK => clkIn,             -- 1-bit input: High speed clock
       CLKDIV => clkDivIn,       -- 1-bit input: Divided clock
       -- D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
       D1 =>'0',
       D2 =>'0',
       D3 =>din_oserdes(5),
       D4 =>din_oserdes(4),
       D5 =>din_oserdes(3),
       D6 =>din_oserdes(2),
       D7 =>din_oserdes(1),
       D8 =>din_oserdes(0),
       OCE => '1',             -- 1-bit input: Output data clock enable
       RST => ioReset,             -- 1-bit input: Reset
       -- SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
       SHIFTIN1 => '0',
       SHIFTIN2 => '0',
       -- T1 - T4: 1-bit (each) input: Parallel 3-state inputs
       T1 => '0',
       T2 => '0',
       T3 => '0',
       T4 => '0',
       TBYTEIN => '0',     -- 1-bit input: Byte group tristate
       TCE => '0'              -- 1-bit input: 3-state clock enable
    );

  u_swap : for i in 0 to kDevW-1 generate
  begin
    din_oserdes(kMaxBit-i-1)     <= dInFromDevice(i);
  end generate;
  din_oserdes(kMaxBit-kDevW-1 downto 0)  <= (others => '0');





end RTL;