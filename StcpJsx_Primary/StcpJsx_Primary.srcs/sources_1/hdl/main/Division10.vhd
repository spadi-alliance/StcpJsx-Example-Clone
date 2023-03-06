library IEEE, mylib;
use IEEE.STD_LOGIC_1164.ALL;

entity Division10 is
    port (
        rst         : in std_logic;
        clk         : in std_logic;
        clkDiv10    : out std_logic
    );
end Division10;

architecture RTL of Division10 is
    -- signal decralation -----------------------------------------------------
    signal clk_inv  : std_logic;
    signal q_jk     : std_logic_vector(3 downto 0);
    signal in_jk    : std_logic_vector(3 downto 0);

begin
    -- ========================================= body ===========================================
    clkDiv10    <= q_jk(3);
    
    clk_inv     <= NOT clk;
    in_jk(0)    <= '1';
    in_jk(1)    <= q_jk(0) AND (NOT q_jk(3));
    in_jk(2)    <= q_jk(0) AND q_jk(1);
    in_jk(3)    <= (q_jk(0) AND q_jk(1) AND q_jk(2)) OR (q_jk(0) AND q_jk(3));

    gen_jkff : for i in 0 to 3 generate
        u_JK : entity mylib.JKFF port map(arst=>rst, J=>in_jk(i), K=>in_jk(i), CLK=>clk_inv, Q=>q_jk(i));
    end generate;

end RTL;
