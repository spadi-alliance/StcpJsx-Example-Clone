library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defStcpJsx.all;
use mylib.defMikumari.all;
use mylib.defCDCM.all;

entity StcpJsxSecondary is
  port
  (
    -- system --
    rst             : in std_logic;
    clkPar          : in std_logic;
    linkUpIn        : in std_logic;

    -- Pulse output --
    stcpPulseOut    : out StcpJsxPulseType;
    pulseError      : out std_logic;

    -- Command output --
    stcpCommandOut  : out StcpJsxCommandType;
    commandError    : out std_logic;

    hbNumber        : out HbNumberType;
    gateNumber      : out GateNumberType;

    -- Slave flag input --
    stcpFlagIn      : in StcpJsxFlagType;

    -- MIKUMARI IF --
    dataOutTx       : out CbtUDataType;
    validOutTx      : out std_logic;
    frameLastOutTx  : out std_logic;
    txAck           : in std_logic;

    dataInRx        : in CbtUDataType;
    validInRx       : in std_logic;
    frameLastInRx   : in std_logic;
    checksumErr     : in std_logic;

    pulseIn         : in std_logic;         -- Reproduced one-shot pulse output.
    pulseTypeRx     : in MikumariPulseType  -- Short massange accompanying the pulse.

  );
end StcpJsxSecondary;

architecture RTL of StcpJsxSecondary is
  attribute mark_debug  : string;

  -- System --
  -- Sychronous reset for clkPar
  signal sync_reset           : std_logic;

  -- pulse --
  signal miku_pulse_type      : MikumariPulseType;

  signal reg_pulse_in         : std_logic;
  signal type_vector          : StcpJsxPulseType;
  signal pulse_error          : std_logic;

  signal reg_pulse_vector     : StcpJsxPulseType;
  signal reg_pulse_error      : std_logic;


  -- Command --
  signal reg_command_vector   : StcpJsxCommandType;
  signal data_rx              : CbtUDataType;
  signal valid_rx             : std_logic;
  signal frame_last_rx        : std_logic;
  signal command_error        : std_logic;

  signal reg_command          : CbtUDataType;
  signal reg_gatenum          : GateNumberType;
  signal reg_hbnum            : HbNumberType;
  signal reg_values           : StcpRegArray;

  signal state_command        : ParseSeqType;

  -- Flags --
  signal data_tx              : CbtUDataType;
  signal valid_tx             : std_logic;
  signal frame_last_tx        : std_logic;

  -- Debug --
  -- attribute mark_debug of state_command   : signal is "true";
  -- attribute mark_debug of valid_rx        : signal is "true";
  -- attribute mark_debug of data_rx         : signal is "true";
  -- attribute mark_debug of frame_last_rx   : signal is "true";
  -- attribute mark_debug of valid_tx        : signal is "true";
  -- attribute mark_debug of data_tx         : signal is "true";
  -- attribute mark_debug of frame_last_tx   : signal is "true";
  -- attribute mark_debug of reg_command     : signal is "true";
  -- attribute mark_debug of reg_pulse_vector     : signal is "true";
  -- attribute mark_debug of reg_command_vector     : signal is "true";

begin

  -- ======================================================================
  --                                 body
  -- ======================================================================

  -- Entity port --
  stcpPulseOut      <= reg_pulse_vector;
  stcpCommandOut    <= reg_command_vector;
  hbNumber          <= reg_hbnum;
  gateNumber        <= reg_gatenum;

  pulseError        <= reg_pulse_error;
  commandError      <= command_error or checksumErr;

  data_rx           <= dataInRx;
  valid_rx          <= validInRx;
  frame_last_rx     <= frameLastInRx;

  dataOutTx         <= data_tx;
  validOutTx        <= valid_tx;
  frameLastOutTx    <= frame_last_tx;
  -- Entity port --

  -- Pulse Transmission ---------------------------------------------------
  miku_pulse_type  <= pulseTypeRx;

  u_pulse_output : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(pulseIn = '1') then
        reg_pulse_in  <= pulseIn;
        type_vector   <= decodeStcpPulseType(miku_pulse_type);
        pulse_error   <= checkStcpPulseError(miku_pulse_type);
      else
        reg_pulse_in  <= '0';
      end if;
    end if;
  end process;

  u_pulse_gen : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      for i in 0 to kNumPulse-1 loop
        reg_pulse_vector(i)  <= type_vector(i) and reg_pulse_in;
      end loop;

      reg_pulse_error   <= pulse_error  and reg_pulse_in;
    end if;
  end process;


  -- Command Transmission ---------------------------------------------------
  u_command_seq : process(clkPar, sync_reset)
    variable index : integer range 0 to kWidthRegValue/8 -1;
  begin
    if(sync_reset = '1') then
      index               := kWidthRegValue/8 -1;
      reg_command_vector  <= (others => '0');
      command_error       <= '0';
      reg_hbnum           <= (others => '0');
      reg_gatenum         <= (others => '0');
      state_command       <= WaitRxData;

    elsif(clkPar'event and clkPar = '1') then
    case state_command is
      when WaitRxData =>
        if(valid_rx = '1') then
          reg_command   <= data_rx;
          index         := kWidthRegValue/8 -1;
          state_command   <= ReceiveRegValue;
        end if;

      when ReceiveRegValue =>
        if(valid_rx = '1') then
          reg_values(index)   <= data_rx;

          if(index = 0) then
            state_command   <= SetCommand;
          end if;

          index   := index -1;
        end if;

      when SetCommand =>
        reg_command_vector  <= decodeStcpCommand(reg_command);
        command_error       <= checkStcpCommandError(reg_command);

        if(reg_command = kComGateNum) then
          reg_gatenum     <= reg_values(0);
        end if;

        if(reg_command = kComHbFrameNum) then
          reg_hbnum(7 downto 0)   <= reg_values(0);
          reg_hbnum(15 downto 8)  <= reg_values(1);
        end if;

        state_command   <= FinalizeParse;

      when FinalizeParse =>
        reg_command_vector  <= (others => '0');
        command_error       <= '0';
        state_command       <= WaitRxData;

      when others =>
        state_command   <= WaitRxData;

    end case;

    end if;
  end process;

  -- Flag parse ---------------------------------------------------------
  u_send_flag : process(clkPar, sync_reset)
  begin
    if(sync_reset = '1') then
      data_tx         <= (others => '0');
      valid_tx        <= '0';
      frame_last_tx   <= '0';
    elsif(clkPar'event and clkPar = '1') then
      if(data_tx /= stcpFlagIn and linkUpIn = '1') then
        data_tx        <= stcpFlagIn;
        valid_tx       <= '1';
        frame_last_tx  <= '1';
      elsif(valid_tx = '1' and txAck = '1') then
        valid_tx        <= '0';
        frame_last_tx   <= '0';
      end if;
    end if;
  end process;

  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rst, clkPar, sync_reset);

end RTL;
