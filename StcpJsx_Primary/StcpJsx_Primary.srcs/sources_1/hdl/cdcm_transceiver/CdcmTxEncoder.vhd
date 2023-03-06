library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defCDCM.all;

entity CdcmTxEncoder is
  generic
  (
    kNumEncodeBits  : integer:= 2; -- 1:CDCM-10-1.5 or 2:CDCM-10-2.5
    kNumCharBits    : integer:= 10
  );
  port
  (
    -- SYSTEM port --
    srst      : in std_logic; -- Asynchronous assert, synchronous de-assert reset. (active high)
    clkPar    : in std_logic; -- From BUFG

    -- Data I/F --
    charIn      : in std_logic_vector(kNumCharBits-1 downto 0); -- Character in
    validIn     : in std_logic; -- 1: charIn is valid. Encode and send it to CDCM-TX.
                                -- 0: Send idle pattern;
    encoderBeat : out std_logic; -- Indicates a character sending cycle is started.
                                 -- charIn and validIn are captured.
                                 -- This signal is a request of a new character to upstream a module.
    dataAck     : out std_logic; -- Acknowledge to validIn

    -- CDCM ports --
    wfPattern   : out CdcmPatternType

  );
end CdcmTxEncoder;

architecture RTL of CdcmTxEncoder is
  attribute mark_debug          : string;

  -- System --
  constant kMaxLoop   : integer:= kNumCharBits/kNumEncodeBits;

  signal reg_valid    : std_logic;
  type DataArrayType is array(integer range kMaxLoop-1 downto 0)
    of std_logic_vector(kNumEncodeBits-1 downto 0);
  signal data_array   : DataArrayType;
  signal payload      : std_logic_vector(kWidthPayload-1 downto 0);
  signal index_array  : integer range 0 to kMaxLoop;
  signal reg_data     : std_logic_vector(charIn'range);

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  gen_array : for i in 0 to kMaxLoop-1 generate
  begin
    data_array(i)   <= reg_data(kNumEncodeBits*(i+1)-1 downto kNumEncodeBits*i);
  end generate;

  -- Generate encoder ------------------------------------------------------------------
  gen_cdcm_10b_1p5b : if kNumEncodeBits = 1 generate
  begin
    payload   <=  "0011" when(reg_valid = '0') else
                  "0001" when(reg_valid = '1' and data_array(index_array) = "0") else
                  "0111" when(reg_valid = '1' and data_array(index_array) = "1") else
                  "0011";
  end generate;

  gen_cdcm_10b_2p5b : if kNumEncodeBits = 2 generate
  begin
    payload   <=  "0011" when(reg_valid = '0') else
                  "0000" when(reg_valid = '1' and data_array(index_array) = "00") else
                  "0001" when(reg_valid = '1' and data_array(index_array) = "01") else
                  "0111" when(reg_valid = '1' and data_array(index_array) = "10") else
                  "1111" when(reg_valid = '1' and data_array(index_array) = "11") else
                  "0011";
  end generate;

  -- Generate encoder ------------------------------------------------------------------
  u_index : process(srst, clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst = '1') then
        reg_valid     <= '0';
        reg_data      <= (others => '0');
        index_array   <= 0;
        encoderBeat    <= '0';
      else
        if(index_array = kMaxLoop-1) then
          index_array   <=0;
          encoderBeat   <= '1';

          if(validIn = '1') then
            reg_valid   <= validIn;
            reg_data    <= charIn;
            dataAck     <= '1';
          else
            reg_valid   <= '0';
          end if;
        else
          encoderBeat   <= '0';
          dataAck       <= '0';
          index_array   <= index_array + 1;
        end if;
      end if;
    end if;
  end process;

  u_outbuf : process(clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      wfPattern  <= "000" & payload & "111";
    end if;
  end process;

end RTL;
