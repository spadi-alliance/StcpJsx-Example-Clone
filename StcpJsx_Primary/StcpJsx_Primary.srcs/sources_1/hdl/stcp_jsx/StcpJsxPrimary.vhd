library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defStcpJsx.all;
use mylib.defMikumari.all;
use mylib.defCDCM.all;

entity StcpJsxPrimary is
  generic
  (
    enDebug         : boolean:= false
  );
  port
  (
    -- system --
    rst             : in std_logic;
    clkPar          : in std_logic;
    linkUpIn        : in std_logic;

    busyPulseSend   : out std_logic;
    busyCommandSend : out std_logic;

    -- Pulse input --
    stcpPulseIn     : in StcpJsxPulseType;
    pulseError      : out std_logic;

    -- Command input --
    stcpCommandIn   : in StcpJsxCommandType;
    commandError    : out std_logic;

    hbNumber        : in HbNumberType;
    gateNumber      : in GateNumberType;

    -- Slave flag output --
    stcpFlagOut     : out StcpJsxFlagType;


    -- MIKUMARI IF --
    dataOutTx       : out CbtUDataType;
    validOutTx      : out std_logic;
    frameLastOutTx  : out std_logic;
    txAck           : in std_logic;

    pulseOut        : out std_logic;
    pulseTypeOut    : out MikumariPulseType;
    busyPulseTx     : in std_logic;

    dataInRx        : in CbtUDataType;
    validInRx       : in std_logic;
    frameLastRx     : in std_logic

  );
end StcpJsxPrimary;

architecture RTL of StcpJsxPrimary is
  attribute mark_debug  : boolean;

  -- System --
  -- Sychronous reset for clkPar
  signal sync_reset           : std_logic;

  -- pulse --
  signal pulse_vector, oneshot_vector : StcpJsxPulseType;
  signal busy_pulse_send      : std_logic;
  signal pulse_out            : std_logic;
  signal pulse_type           : MikumariPulseType;
  signal pulse_error          : std_logic;

  -- Command --
  signal command_vector       : StcpJsxCommandType;
  signal data_tx              : CbtUDataType;
  signal valid_tx             : std_logic;
  signal frame_last_tx        : std_logic;
  signal busy_command         : std_logic;
  signal command_error        : std_logic;

  signal reg_command          : CbtUDataType;
  signal reg_gatenum          : GateNumberType;
  signal reg_hbnum            : HbNumberType;
  signal reg_values           : StcpRegArray;
  constant kRegLast           : std_logic_vector(kWidthRegValue/8-1 downto 0):= "0001";

  signal state_command        : CommandSeqType;

  -- Flags --
  signal reg_flags            : StcpJsxFlagType;

  -- Debug --
  attribute mark_debug of state_command   : signal is enDebug;
  attribute mark_debug of valid_tx        : signal is enDebug;
  attribute mark_debug of data_tx         : signal is enDebug;
  attribute mark_debug of frame_last_tx   : signal is enDebug;
  attribute mark_debug of reg_command     : signal is enDebug;
  attribute mark_debug of pulse_type      : signal is enDebug;
  attribute mark_debug of pulse_vector    : signal is enDebug;
  attribute mark_debug of command_vector  : signal is enDebug;
  attribute mark_debug of busy_command    : signal is enDebug;
  attribute mark_debug of busy_pulse_send : signal is enDebug;
  attribute mark_debug of pulse_error     : signal is enDebug;
  attribute mark_debug of command_error   : signal is enDebug;


begin

  -- ======================================================================
  --                                 body
  -- ======================================================================

  -- Entity port --
  busyPulseSend     <= busy_pulse_send;
  busyCommandSend   <= busy_command;
  stcpFlagOut       <= reg_flags;

  pulseError        <= pulse_error;
  commandError      <= command_error;

  dataOutTx         <= data_tx;
  validOutTx        <= valid_tx;
  frameLastOutTx    <= frame_last_tx;

  pulseOut          <= pulse_out;
  pulseTypeOut      <= pulse_type;
  busy_pulse_send   <= busyPulseTx;
  -- Entity port --

  -- Pulse Transmission ---------------------------------------------------
  pulse_vector  <= stcpPulseIn;

  gen_edgedetector : for i in 0 to kNumPulse-1 generate
  begin
    u_edge_detector : entity mylib.EdgeDetector
      port map('0', clkPar, pulse_vector(i), oneshot_vector(i));
  end generate;

  u_pulse_type : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(unsigned(oneshot_vector) /= 0 and busy_pulse_send = '0' and linkUpIn = '1') then
        pulse_out   <= '1';
        pulse_type  <= encodeStcpPulseType(oneshot_vector);
      else
        pulse_out   <= '0';
      end if;
    end if;
  end process;

  u_pulse_error : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(pulse_out = '1' and pulse_type = kErrorPulse) then
        pulse_error   <= '1';
      else
        pulse_error   <= '0';
      end if;
    end if;
  end process;


  -- Command Transmission ---------------------------------------------------
  command_vector  <= stcpCommandIn;

  u_command_seq : process(clkPar, sync_reset)
    variable index : integer range 0 to kWidthRegValue/8 -1;
  begin
    if(sync_reset = '1') then
      index           := kWidthRegValue/8 -1;
      valid_tx        <= '0';
      frame_last_tx   <= '0';
      busy_command    <= '0';
      command_error   <= '0';
      state_command   <= WaitCommand;

    elsif(clkPar'event and clkPar = '1') then
    case state_command is
      when WaitCommand =>
        if(unsigned(command_vector) /= 0 and linkUpIn = '1') then
          reg_command   <= encodeStcpCommand(command_vector);
          reg_gatenum   <= gateNumber;
          reg_hbnum     <= hbNumber;
          busy_command  <= '1';

          state_command   <= SetRegValue;
        end if;

      when SetRegValue =>
        if(reg_command = kComGateNum) then
          reg_values(0)   <= reg_gatenum;
          reg_values(1)   <= (others => '0');
          reg_values(2)   <= (others => '0');
          reg_values(3)   <= (others => '0');
        end if;

        if(reg_command = kComHbFrameNum) then
          reg_values(0)   <= reg_hbnum(7 downto 0);
          reg_values(1)   <= reg_hbnum(15 downto 8);
          reg_values(2)   <= (others => '0');
          reg_values(3)   <= (others => '0');
        end if;

        if(reg_command = kComError) then
          command_error   <= '1';
        end if;

        valid_tx        <= '1';
        data_tx         <= reg_command;
        state_command   <= SendCommand;

      when SendCommand =>
        index           := kWidthRegValue/8 -1;
        if(txAck = '1') then
          state_command   <= SendRegValue;
        end if;

      when SendRegValue =>
        data_tx         <= reg_values(index);
        frame_last_tx   <= kRegLast(index);

        if(txAck = '1') then
          if(index = 0) then
            valid_tx        <= '0';
            state_command   <= FinalizeCommand;
          end if;

          index   := index -1;
        end if;

      when FinalizeCommand =>
        busy_command    <= '0';
        frame_last_tx   <= '0';
        command_error   <= '0';
        state_command   <= WaitCommand;

      when others =>
        state_command   <= WaitCommand;

    end case;

    end if;
  end process;

  -- Flag parse ---------------------------------------------------------
  u_slave_flag : process(clkPar, sync_reset)
  begin
    if(sync_reset = '1') then
      reg_flags   <= (others => '0');
    elsif(clkPar'event and clkPar = '1') then
      if(validInRx = '1' and frameLastRx = '1') then
        reg_flags   <= dataInRx;
      end if;
    end if;
  end process;

  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clkPar, sync_reset);

end RTL;