-----------------------------------------------------------------------------------------------
-- Local Bus Controller
-- Originally designed by S. Ajimura
-- Reused by R. Honda
-----------------------------------------------------------------------------------------------
library ieee, mylib;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use mylib.defBCT.all;
use mylib.defSiTCP.all;

entity BusController is
  Port(
    rstSys                : in  std_logic;
    rstFromBus            : out std_logic;
    reConfig              : out std_logic;
    clk	                  : in  std_logic;
    -- Local Bus --
    addrLocalBus	        : out LocalAddressType;
    dataFromUserModules	  : in DataArray;
    dataToUserModules	    : out LocalBusInType;
    reLocalBus		        : out ControlRegArray;
    weLocalBus		        : out ControlRegArray;
    readyLocalBus	        : in  ControlRegArray;
    -- RBCP --
    addrRBCP              : in std_logic_vector(kWidthAddrRBCP-1 downto 0); -- address [31:0]
    wdRBCP                : in std_logic_vector(kWidthDataRBCP-1 downto 0);  -- data from host [7:0]
    weRBCP                : in std_logic; 		    -- RBCP write enable
    reRBCP                : in std_logic; 		    -- RBCP read enable
    ackRBCP	              : out std_logic; 		    -- RBCP acknowledge
    rdRBCP                : out std_logic_vector(kWidthDataRBCP-1 downto 0)  -- data to host [7:0]
    );
end BusController;

architecture RTL of BusController is
  attribute keep : string;

  -- System --
  signal sync_reset       : std_logic;

  -- internal signal ---------------------------------------------------
  signal state_bus              : BusControlProcessType;
  signal i_module               : ModuleID := -1;
  signal reg_data_local_bus     : DataArray;
  signal reg_ready_local_bus    : ControlRegArray;
  signal rst_from_bus           : std_logic := '0';
  signal re_config              : std_logic := '1';

  attribute keep of rst_from_bus  : signal is "true";

  -- external bus -------------------------------------------------------
  signal mid_ext_bus            : std_logic_vector(kMidBCT'range);
  signal addr_ext_bus           : LocalAddressType;
  signal data_ext_bus_in	      : LocalBusInType;
  signal data_ext_bus_out	      : LocalBusOutType;
  signal ack_ext_bus, re_ext_bus, we_ext_bus	: std_logic;

-- =============================== body ===============================
begin
  -- Bus latch --
  u_BusLatchProcess : process(clk)
  begin
    if(clk'event and clk = '1') then
      for i in 0 to kNumModules-1 loop
        reg_data_local_bus(i)	  <= dataFromUserModules(i);
        reg_ready_local_bus(i)	<= readyLocalBus(i);
      end loop;
    end if;
  end process u_BusLatchProcess;

  -- RBCP connection --
  rdRBCP	    <= data_ext_bus_out;
  ackRBCP	    <= ack_ext_bus;
  rstFromBus  <= rst_from_bus;
  reConfig	  <= re_config;

  -- Bus control process --
  u_BusControlProcess : process (clk, rstSys)
  begin
    if(rstSys = '1') then
      for i in 0 to kNumModules-1 loop
        reLocalBus(i) <= '0';
        weLocalBus(i) <= '0';
      end loop;
      re_ext_bus	      <= '0';
      we_ext_bus	      <= '0';
      data_ext_bus_out  <= x"00";
      ack_ext_bus	      <= '0';
      rst_from_bus	    <= '0';
      re_config         <= '1';
      state_bus	        <= Init;
    elsif(clk'event and clk = '1') then
      case state_bus is
        when Init =>
          for i in 0 to kNumModules-1 loop
            reLocalBus(i) <= '0';
            weLocalBus(i) <= '0';
          end loop;
          re_ext_bus		    <= '0';
          we_ext_bus		    <= '0';
          data_ext_bus_out  <= x"00";
          ack_ext_bus		    <= '0';
          rst_from_bus	    <= '0';
          re_config   	    <= '1';
          state_bus		      <= Idle;

        when Idle =>
          if(reRBCP = '1' or weRBCP = '1') then
            re_ext_bus		<= reRBCP;
            we_ext_bus		<= weRBCP;
            mid_ext_bus		<= addrRBCP(kMid'range);
            addr_ext_bus	<= addrRBCP(kLocalAddr'range);
            data_ext_bus_in	<= wdRBCP;
            state_bus		  <= GetDest;
          end if;

        when GetDest =>
          if(mid_ext_bus = kMidBct) then -- Do in this module
            if(re_ext_bus = '1') then
              if(addr_ext_bus(kNonMultiByte'range) = kBctVersion(kNonMultiByte'range)) then --version info
                case addr_ext_bus(kMultiByte'range) is
                  when k1stByte => data_ext_bus_out	<= kCurrentVersion(7 downto 0);
                  when k2ndByte => data_ext_bus_out	<= kCurrentVersion(15 downto 8);
                  when k3rdByte => data_ext_bus_out	<= kCurrentVersion(23 downto 16);
                  when others => data_ext_bus_out	<= kCurrentVersion(31 downto 24);
                end case;
              end if;
            elsif(we_ext_bus = '1') then
              if(addr_ext_bus(kNonMultiByte'range) = kBctReset(kNonMultiByte'range)) then -- software reset
                rst_from_bus	<= '1';
              elsif(addr_ext_bus(kNonMultiByte'range) = kBctReConfig(kNonMultiByte'range)) then -- reconfig by SPI
                re_config       <= '0';
              end if;
            end if;
            state_bus	<= Done;
          else -- Go to external user modules
            case mid_ext_bus is
              when kMidC6C  => i_module <= kC6C.ID;
              when kMidSDS  => i_module <= kSDS.ID;
              when kMidFMP  => i_module <= kFMP.ID;
              when others   => i_module <= kDummy.ID;
            end case;
            state_bus	<= SetBus;
          end if;

        when SetBus =>
          if(i_module = -1) then
					-- error state --
            data_ext_bus_out	<= x"fe";
            state_bus		<= Done;
          else
            addrLocalBus	    <= addr_ext_bus;
            dataToUserModules	<= data_ext_bus_in;
            state_bus		      <= Connect;
          end if;

        when Connect =>
          if(we_ext_bus = '1') then
            weLocalBus(i_module) <= '1';
          else
            reLocalBus(i_module) <= '1';
          end if;
          -- wait ready from user modules --
          if(reg_ready_local_bus(i_module) = '1') then
            state_bus	      <= Finalize;
          end if;

        when Finalize =>
          -- data valid end of process --
          data_ext_bus_out	<= reg_data_local_bus(i_module);
          state_bus		      <= Done;

        when Done =>
          weLocalBus(i_module)  <= '0';
          reLocalBus(i_module)  <= '0';
          ack_ext_bus           <= '1';
          state_bus		          <= Init;

      end case;
    end if;
  end process u_BusControlProcess;

  -- Reset sequence --
  u_reset_gen_sys   : entity mylib.ResetGen
    port map(rstSys, clk, sync_reset);

end RTL;

