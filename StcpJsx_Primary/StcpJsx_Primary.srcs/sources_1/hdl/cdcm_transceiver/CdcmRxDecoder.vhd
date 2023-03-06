library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defCDCM.all;

entity CdcmRxDecoder is
  generic
  (
    kNumEncodeBits  : integer:= 2;  -- 1:CDCM-10-1.5 or 2:CDCM-10-2.5
    kNumCharBits    : integer:= 10;
    kRefPattern     : std_logic_vector(kNumCharBits-1 downto 0):= kTTypeCharInit1_2P5
                                        -- Used as a reference bit pattern to align decoded data
  );
  port
  (
    -- SYSTEM port --
    srst        : in std_logic; -- Asynchronous assert, synchronous de-assert reset. (active high)
    clkPar      : in std_logic; -- From BUFG
    enBitAlign  : in std_logic; -- Check wether decoded character is matched with kRefPattern or not.
                                -- If not, perform bit slip.

    -- Status --
    bitAligned  : out std_logic; -- Decoder bit-slip is completed.

    -- Data I/F --
    charOut     : out std_logic_vector(kNumCharBits-1 downto 0); -- Character output
    validOut    : out std_logic; -- When high, data on charOut is valid.
    isIdle      : out std_logic; -- When high, cdcm patterns are idle.
    isCollapsed : out std_logic; -- Broken payload pattern is found in current data on charOut.
    decoderBeat : out std_logic; -- Indicates a character decoding cycle is started.

    -- CDCM ports --
    payloadIn   : in std_logic_vector(kPaylowdPos'length-1 downto 0) -- From CdcmRx.
  );
end CdcmRxDecoder;

architecture RTL of CdcmRxDecoder is
  -- System --
  constant kMaxLoop           : integer:= kNumCharBits/kNumEncodeBits;

  -- Data I/F --
  signal is_idle              : std_logic;
  signal is_collapsed         : std_logic;
  signal reg_is_idle          : std_logic;
  signal reg_dvalid           : std_logic;
  signal reg_beat             : std_logic;
  signal mem_collapsed        : std_logic;
  signal reg_collapsed        : std_logic;
  signal check_flag           : std_logic;

  -- Bit align --
  signal en_align_process     : std_logic;
  signal reg_bit_align        : std_logic;
  signal en_increment         : std_logic;

  -- Decode  --
  signal decoded_payload      : std_logic_vector(kNumEncodeBits-1 downto 0);
  type DataArrayType is array(integer range kMaxLoop-1 downto 0)
    of std_logic_vector(kNumEncodeBits-1 downto 0);
  signal data_array   : DataArrayType;
  signal payload      : std_logic_vector(kWidthPayload-1 downto 0);
  signal index_array  : integer range 0 to kMaxLoop;
  signal reg_dout     : std_logic_vector(charOut'range);

begin
  -- ======================================================================
  --                                 body
  -- ======================================================================

  validOut      <= reg_dvalid;
  isIdle        <= reg_is_idle;
  isCollapsed   <= reg_collapsed;
  decoderBeat   <= reg_beat;
  bitAligned    <= reg_bit_align;
  charOut       <= reg_dout;

  payload           <= payloadIn;
  en_align_process  <= enBitAlign;

  -- Generate decoder ------------------------------------------------------------------
  gen_cdcm_10b_1p5b : if kNumEncodeBits = 1 generate
  begin
    decoded_payload   <=  "0" when(payload = "0001") else
                          "1" when(payload = "0111") else
                          "0";

    is_idle           <=  '1' when(payload = "0011") else '0';

    is_collapsed      <=  '0' when(payload = "0011") else
                          '0' when(payload = "0001") else
                          '0' when(payload = "0111") else
                          '1';
  end generate;

  gen_cdcm_10b_2p5b : if kNumEncodeBits = 2 generate
  begin
    decoded_payload   <=  "00" when(payload = "0000") else
                          "01" when(payload = "0001") else
                          "10" when(payload = "0111") else
                          "11" when(payload = "1111") else
                          "00";

    is_idle           <=  '1' when(payload = "0011") else '0';

    is_collapsed      <=  '0' when(payload = "0011") else
                          '0' when(payload = "0000") else
                          '0' when(payload = "0001") else
                          '0' when(payload = "0111") else
                          '0' when(payload = "1111") else
                          '1';
  end generate;

  -- Generate decoder ------------------------------------------------------------------
  u_index : process(srst, clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst = '1') then
        mem_collapsed <= '0';
        reg_collapsed <= '0';
        check_flag    <= '0';
        index_array   <= 0;
      else
        if(en_increment = '1') then
          if(index_array = kMaxLoop-1) then
            reg_is_idle   <= is_idle and reg_bit_align;
            reg_collapsed <= (mem_collapsed or is_collapsed) and reg_bit_align;
            reg_dvalid    <= (not is_idle) and reg_bit_align;
            reg_beat      <= reg_bit_align;
            mem_collapsed <= '0';
            index_array   <= 0;
            check_flag    <= not check_flag;
          else
            mem_collapsed <= mem_collapsed or is_collapsed;
            reg_is_idle   <= '0';
            reg_dvalid    <= '0';
            reg_beat      <= '0';
            index_array   <= index_array + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  u_timingshift : process(srst, clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(srst = '1') then
        reg_bit_align  <= '0';
        en_increment   <= '0';
      else
        if(en_align_process = '1' and is_idle = '0' and index_array = kMaxLoop-1) then
          if(check_flag = '1') then
            if(reg_dout = kRefPattern) then
              reg_bit_align <= '1';
            else
              en_increment  <= '0';
            end if;
          end if;
        else
          en_increment  <= '1';
        end if;
      end if;
    end if;
  end process;

  u_outbuf : process(srst, clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      data_array(index_array)  <= decoded_payload;
    end if;
  end process;

  gen_dout : for i in 0 to kMaxLoop-1 generate
  begin
    reg_dout(kNumEncodeBits*(i+1)-1 downto kNumEncodeBits*i) <= data_array(i);
  end generate;

end RTL;
