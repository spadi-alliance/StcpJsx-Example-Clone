library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package defBCT is

  constant kCurrentVersion      : std_logic_vector(31 downto 0):= x"39010101";
  constant kNumModules          : natural:= 3;

  -- Local Bus definition
  constant kWidthLocalAddress   : positive:=12;
  constant kWidthModuleID       : positive:=4;

  subtype LocalAddressType      is std_logic_vector(kWidthLocalAddress-1 downto 0);
  subtype LocalBusInType        is std_logic_vector(7 downto 0);
  subtype LocalBusOutType       is std_logic_vector(7 downto 0);

  -- RBCP address => Local MID + Address
  subtype kMid                  is std_logic_vector(31 downto 28);
  subtype kLocalAddr            is std_logic_vector(27 downto 16);

  -- Multi-byte access
  subtype kNonMultiByte         is std_logic_vector(11 downto 4);
  subtype kMultiByte            is std_logic_vector(3 downto 0);
  constant k1stByte             : std_logic_vector(kMultiByte'range):= "0000";
  constant k2ndByte             : std_logic_vector(kMultiByte'range):= "0001";
  constant k3rdByte             : std_logic_vector(kMultiByte'range):= "0010";
  constant k4thByte             : std_logic_vector(kMultiByte'range):= "0011";
  constant k5thByte             : std_logic_vector(kMultiByte'range):= "0100";
  constant k6thByte             : std_logic_vector(kMultiByte'range):= "0101";
  constant k7thByte             : std_logic_vector(kMultiByte'range):= "0110";
  constant k8thByte             : std_logic_vector(kMultiByte'range):= "0111";

  constant kZeroVector          : std_logic_vector(7 downto 0):= "00000000";

  -- Local Module ID ------------------------------------------------------
  -- Module ID Map
  -- <Module ID : 31-28> + <Local Address 27 - 16>
  -- SiTCP:		  1111 (Reserved)

  -- Module ID
  constant kMidC6C      : std_logic_vector(kWidthModuleID-1 downto 0) := "0001";
  constant kMidSDS      : std_logic_vector(kWidthModuleID-1 downto 0) := "1100";
  constant kMidFMP      : std_logic_vector(kWidthModuleID-1 downto 0) := "1101";
  constant kMidBCT      : std_logic_vector(kWidthModuleID-1 downto 0) := "1110";

  -- Local Address  -------------------------------------------------------
  constant kBctReset   		: LocalAddressType := x"000"; -- W
  constant kBctVersion 		: LocalAddressType := x"010"; -- R, [7:0] 4 byte (0x010,011,012,013);
  constant kBctReConfig  	: LocalAddressType := x"020"; -- W, Reconfig FPGA by SPI

  -- Local Bus index ------------------------------------------------------
  subtype ModuleID is integer range -1 to kNumModules-1;
  type Leaf is record
    ID : ModuleID;
  end record;

  type Binder is array (integer range <>) of Leaf;
  constant kC6C	  : Leaf := (ID => 0);
  constant kSDS	  : Leaf := (ID => 1);
  constant kFMP   : Leaf := (ID => 2);
  constant kDummy : Leaf := (ID => -1);

  -- Local bus state machine -----------------------------------------
  type AddressArray is array (integer range kNumModules-1 downto 0)
    of std_logic_vector(LocalAddressType'range);
  type DataArray is array (integer range kNumModules-1 downto 0)
    of std_logic_vector(LocalBusInType'range);
  type ControlRegArray is array (integer range kNumModules-1 downto 0)
    of std_logic;

  type BusControlProcessType is (
    Init,
    Idle,
    GetDest,
    SetBus,
    Connect,
    Finalize,
    Done
    );

  type BusProcessType is (
    Init,
    Idle,
    Connect,
    Write,
    Read,
    Execute,
    Finalize,
    Done
    );

  type SubProcessType is (
    SubIdle,
    ExecModule,
    WaitAck,
    SubDone
    );
end package defBCT;

