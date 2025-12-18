library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity comp_choque is
  Port (
    fin_carretera : in STD_LOGIC_VECTOR (6 downto 0);
    pos_coche     : in STD_LOGIC_VECTOR (6 downto 0);
    clk           : in std_logic;   -- se mantiene (no se usa)
    choque        : out STD_LOGIC
  );
end comp_choque;

architecture Behavioral of comp_choque is
  signal fin_carretera_i : std_logic_vector(2 downto 0);
  signal pos_coche_i     : std_logic_vector(2 downto 0);
  signal res_mascara     : std_logic_vector(2 downto 0);
begin

  -- Extraemos los 3 carriles que usas realmente
  fin_carretera_i <= fin_carretera(6) & fin_carretera(0) & fin_carretera(3);
  pos_coche_i     <= pos_coche(6)     & pos_coche(0)     & pos_coche(3);

  res_mascara <= fin_carretera_i and pos_coche_i;

  choque <= '1' when res_mascara /= "000" else '0';

end Behavioral;
