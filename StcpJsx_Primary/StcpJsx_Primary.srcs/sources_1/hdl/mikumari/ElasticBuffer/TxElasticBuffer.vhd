library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library mylib;
use mylib.defCDCM.all;
use mylib.defMikumari.all;

entity TxElasticBuffer is
  port
    (
      -- SYSTEM port --
      rst           : in std_logic; -- Asynchronous reset. (active high)
      clkPar        : in std_logic; -- From BUFG

      dataIn        : in CbtUDataType;  -- Mikumari Tx data input
      frameLastIn   : in std_logic;     -- Mikumari Tx FrameLast
      wrEn          : in std_logic;     -- Write enable to buffer
      bufferFull    : out std_logic;    -- Buffer full

      dataOut       : out CbtUDataType; -- Mikumari Tx data output
      validOut      : out std_logic;    -- Mikumari Tx Valid
      frameLastOut  : out std_logic;    -- Mikumari Tx FrameLast
      ackIn         : in std_logic      -- Acknowledge from MikumariBlock

    );
end TxElasticBuffer;

architecture RTL of TxElasticBuffer is
  attribute mark_debug : string;

  -- System --
  signal reset_shiftreg       : std_logic_vector(kWidthResetSync-1 downto 0);
  signal sync_reset           : std_logic;

  constant kLengthBuffer      : integer:= 8;
  signal read_ptr, write_ptr  : integer range 0 to kLengthBuffer-1;

  type RbDataType  is array(integer range 0 to kLengthBuffer-1) of CbtUDataType;
  signal rb_data        : RbDataType;
  signal rb_frame_last  : std_logic_vector(kLengthBuffer-1 downto 0);

begin
  -- ================================= body ===============================
  -- Entity port I/O --
  bufferFull    <= '1' when(write_ptr+1 = read_ptr) else '0';

  dataOut       <= X"00" when(read_ptr = write_ptr) else  rb_data(read_ptr);
  frameLastOut  <= '0' when(read_ptr = write_ptr) else  rb_frame_last(read_ptr);
  validOut      <= '0' when(read_ptr = write_ptr) else  '1';


  -- Ring buffer --
  u_write_buffer : process(sync_reset, clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(sync_reset = '1') then
        write_ptr   <= 0;
      elsif(wrEn = '1' and write_ptr+1 /= read_ptr) then
        rb_data(write_ptr)        <= dataIn;
        rb_frame_last(write_ptr)  <= frameLastIn;

        if(write_ptr = kLengthBuffer-1) then
          write_ptr <= 0;
        else
          write_ptr <= write_ptr +1;
        end if;
      end if;
    end if;
  end process;

  u_read_buffer : process(sync_reset, clkPar)
  begin
    if(clkPar'event and clkPar = '1') then
      if(sync_reset = '1') then
        read_ptr   <= 0;
      elsif(ackIn = '1' and read_ptr /= write_ptr) then
        if(read_ptr = kLengthBuffer-1) then
          read_ptr  <= 0;
        else
          read_ptr  <= read_ptr +1;
        end if;
      end if;
    end if;
  end process;


  -- Reset sequence --
  sync_reset  <= reset_shiftreg(kWidthResetSync-1);
  u_sync_reset : process(rst, clkPar)
  begin
    if(rst = '1') then
      reset_shiftreg  <= (others => '1');
    elsif(clkPar'event and clkPar = '1') then
      reset_shiftreg  <= reset_shiftreg(kWidthResetSync-2 downto 0) & '0';
    end if;
  end process;

end RTL;
