library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defCDCM.all;
use mylib.defMikumari.all;

entity MikumariRx is
  generic
  (
    -- CBT --
    kNumEncodeBits   : integer:= 2;
    -- Scrambler --
    enScrambler      : boolean:= true;
    -- DEBUG --
    enDEBUG          : boolean:= false
  );
  port
  (
    -- SYSTEM port --
    srst        : in std_logic; -- Asynchronous assert, synchronous de-assert reset. (active high)
    clkPar      : in std_logic; -- From BUFG

    -- Status --
    cbtUpIn     : in std_logic;  -- Cbt lane up signal
    mikuRxUp    : out std_logic; -- Mikumari RX is up.

    -- Data I/F --
    dataOut     : out CbtUDataType; -- User data output.
    validOut    : out std_logic;    -- Indicate current dataOut is valid.
    frameLast   : out std_logic;    -- Indicate current dataOut is the last data in a normal frame.
    checksumErr : out std_logic;    -- Check-sum error is happened in the present normal frame.

    pulseOut    : out std_logic;    -- Reproduced one-shot pulse output.
    pulseType   : out MikumariPulseType; -- Short message accompanying the pulse.

    -- Back channel --
    instRx      : out MikumariBackChannelType;

    -- Cbt ports --
    isKtypeIn   : in std_logic;     -- Connect to CbtRx.
    cbtDataIn   : in CbtUDataType;  -- Connect to CbtRx.
    cbtValidIn  : in std_logic      -- Connect to CbtRx.

  );
end MikumariRx;

architecture RTL of MikumariRx is

  -- System --
  signal mikumari_rx_up       : std_logic;

  -- Cbt --
  signal cbt_up               : std_logic;
  signal data_in              : CbtUDataType;
  signal descranble_data_in   : CbtUDataType;
  signal valid_in             : std_logic;
  signal is_ktype             : std_logic;

  -- Data I/F --
  signal frame_end            : std_logic;
  signal reg_data_st1, reg_data_st2, reg_data_st3     : CbtUDataType;
  signal reg_valid_st1, reg_valid_st2, reg_valid_st3   : std_logic;
  signal checksum_error       : std_logic;
  signal reg_check_sum        : std_logic_vector(kWidthCheckSum-1 downto 0);

  -- pulse --
  signal pulse_out, reg_pulse_out  : std_logic;
  signal reg_pulse_type       : MikumariPulseType;
  signal reg_pulse_timing     : std_logic_vector(kWidthPulseCount-1 downto 0);
  signal sr_pulse             : std_logic_vector(kWidthPulseSr-1 downto 0);

  -- Initialize --
  signal mikumari_inst        : MikumariBackChannelType;
  signal first_fsk_recv       : std_logic;

   -- Scrambler --
   signal set_seed             : std_logic;
   signal en_prbs_clk          : std_logic;
   constant kPrbsLength        : positive:= 16;
   signal prbs_out             : std_logic_vector(kPrbsLength-1 downto 0);
   signal state_seed           : SetSeedType;

  -- debug --
  attribute mark_debug  : boolean;
  attribute mark_debug  of frame_end          : signal is enDEBUG;
  attribute mark_debug  of reg_check_sum      : signal is enDEBUG;
  attribute mark_debug  of checksum_error     : signal is enDEBUG;
  attribute mark_debug  of pulse_out          : signal is enDEBUG;
  attribute mark_debug  of reg_pulse_timing   : signal is enDEBUG;
  attribute mark_debug  of mikumari_inst      : signal is enDEBUG;
  attribute mark_debug  of en_prbs_clk        : signal is enDEBUG;
  attribute mark_debug  of state_seed         : signal is enDEBUG;

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  cbt_up    <= cbtUpIn;
  mikuRxUp  <= mikumari_rx_up and first_fsk_recv;

  instRx    <= mikumari_inst;

  dataOut   <= reg_data_st3;
  validOut  <= reg_valid_st3;
  frameLast <= frame_end;
  checksumErr   <= checksum_error;

  pulseOut  <= reg_pulse_out;
  pulseType <= reg_pulse_type;

  gen_noscrambler : if enScrambler = false generate
  begin
    descranble_data_in <= cbtDataIn;
  end generate;

  data_in   <= cbtDataIn;
  valid_in  <= cbtValidIn;
  is_ktype  <= isKtypeIn;

  u_output_reg : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst = '1') then
        reg_valid_st1   <= '0';
        reg_valid_st2   <= '0';
        reg_valid_st3   <= '0';
        checksum_error  <= '0';

      elsif(valid_in = '1' and mikumari_rx_up = '1' and isPulseChar(data_in, is_ktype)='0') then
        if(is_ktype = '0') then
          --reg_data_st1    <= data_in;
          reg_data_st1    <= descranble_data_in;
          reg_valid_st1   <= '1';
        elsif(is_ktype = '1') then
          reg_valid_st1   <= '0';
        end if;

        if(is_ktype = '1' and data_in = kMikumariFek) then
          reg_valid_st2   <= '0';
          frame_end       <= '1';

          if(reg_check_sum = X"FF") then
            checksum_error  <= '0';
          else
            checksum_error  <= '1';
          end if;

        else
          reg_data_st2    <= reg_data_st1;
          reg_valid_st2   <= reg_valid_st1;
          frame_end   <= '0';
        end if;

        reg_data_st3    <= reg_data_st2;
        reg_valid_st3   <= reg_valid_st2;
      else
        reg_valid_st3   <= '0';
        frame_end       <= '0';
      end if;
    end if;
  end process;

  u_checksum : process(clkPar, srst, mikumari_rx_up)
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst = '1' or mikumari_rx_up = '0') then
        reg_check_sum <= (others => '0');
      else
        if(valid_in = '1' and mikumari_rx_up = '1')then
          if(is_ktype = '0') then
            reg_check_sum   <= std_logic_vector(unsigned(reg_check_sum) + unsigned(descranble_data_in));
          elsif(is_ktype = '1' and data_in = kMikumariFsk) then
            reg_check_sum   <= (others => '0');
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Cbt port --

  -- Link up process --
  u_init_sm : process(clkPar, srst)
    constant  kNumCount   : integer:= 63;
    variable  count   : integer range 0 to kNumCount:= 0;
    variable  reserve : std_logic:= '0';
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst = '1') then
        mikumari_inst   <= WaitCbtUp;
        mikumari_rx_up  <= '0';
        count           := 0;
        reserve         := '0';
      else
        case mikumari_inst is
          when WaitCbtUp =>
            mikumari_rx_up  <= '0';
            count           := 0;
            reserve         := '0';
            if(cbt_up = '1') then
              mikumari_inst   <= SendInitK1;
            end if;

          when SendInitK1 =>
            if(valid_in = '1') then
              if(data_in = GetInitK1(kNumEncodeBits)) then
                reserve   := '1';
              end if;

              if(cbt_up = '0') then
                mikumari_inst   <= WaitCbtUp;
              elsif(count = kNumCount-1 and reserve = '1') then
                count           := 0;
                reserve         := '0';
                mikumari_inst   <= SendInitK2;
              end if;

              if(count /= kNumCount-1) then
                count   := count +1;
              end if;
            end if;

          when SendInitK2 =>
            if(valid_in = '1') then
              if(data_in = GetInitK2(kNumEncodeBits)) then
                reserve   := '1';
              end if;

              if(cbt_up = '0') then
                mikumari_inst   <= WaitCbtUp;
              elsif(count > 0 and reserve = '1') then
                count           := 0;
                reserve         := '0';
                mikumari_inst   <= MikumariRxUp;
              end if;

              if(count /= kNumCount-1) then
                count   := count +1;
              end if;
            end if;

          when MikumariRxUp =>
            mikumari_rx_up  <= '1';
            if(cbt_up = '0') then
              mikumari_inst   <= WaitCbtUp;
            end if;

        end case;
      end if;
    end if;
  end process;

  -- Pulse recovery --
  u_pulse_recovery : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(valid_in = '1' and isPulseChar(data_in, is_ktype) = '1') then
        reg_pulse_type    <= decodePulseType(data_in);
        reg_pulse_timing  <= data_in(kWidthPulseCount-1 downto 0);
        sr_pulse          <= sr_pulse(kWidthPulseSr-2 downto 0) & '1';
      else
        sr_pulse          <= sr_pulse(kWidthPulseSr-2 downto 0) & '0';
      end if;

      reg_pulse_out   <= pulse_out;
    end if;
  end process;

  pulse_out   <= sr_pulse(to_integer(unsigned(reg_pulse_timing)));

  u_set_seed : process(clkPar, srst)
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst = '1') then
        first_fsk_recv  <= '0';
        set_seed        <= '0';
        state_seed      <= WaitLinkUp;
      else
        case state_seed is
          when WaitLinkUp =>
            first_fsk_recv  <= '0';
            set_seed        <= '0';
            if(mikumari_rx_up = '1') then
              state_seed  <= WaitFirstFsk;
            end if;

          when WaitFirstFsk =>
            if(mikumari_rx_up = '0') then
              state_seed  <= WaitLinkUp;
            elsif(valid_in = '1' and is_ktype = '1' and data_in = kMikumariFsk) then
              state_seed  <= SetSeed;
            end if;

          when SetSeed =>
            set_seed    <= '1';
            state_seed  <= SeedIsSet;

          when SeedIsSet =>
            set_seed        <= '0';
            first_fsk_recv  <= '1';
            if(mikumari_rx_up = '0') then
              state_seed  <= WaitLinkUp;
            end if;

          when others =>
            null;

        end case;
      end if;
    end if;
  end process;

  -- Scrambler --
  gen_scrambler : if enScrambler = true generate
  begin

    u_prbs_en : process(clkPar)
    begin
      if(clkPar'event and clkPar = '1') then
        if(is_ktype = '0' and valid_in = '1' and state_seed = SeedIsSet) then
          en_prbs_clk   <= '1';
        else
          en_prbs_clk   <= '0';
        end if;
      end if;
    end process;

    u_prbs : entity mylib.PRBS16
      port map
      (
        setSeed   => set_seed,
        clk       => clkPar,
        enClk     => en_prbs_clk,
        dataOut   => prbs_out
      );

      descranble_data_in <= cbtDataIn xor prbs_out(data_in'range);
  end generate;

end RTL;
