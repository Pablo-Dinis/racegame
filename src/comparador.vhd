library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity comparador is
  Port (
    n_flancos : in integer;     -- en tu TOP = segundos jugados (sec_count)
    modo_f    : in std_logic;
    modo_m    : in std_logic;
    modo_d    : in std_logic;
    modo_div  : out integer     -- 0/1/2 (fase de velocidad)
  );
end comparador;

architecture Behavioral of comparador is
begin

  process(n_flancos, modo_f, modo_m, modo_d)
  begin
    -- Valor por defecto
    modo_div <= 0;

    -- FACIL: 0..9s -> 0 | 10..24s -> 1 | 25+ -> 2
    if modo_f = '1' then
      if n_flancos < 10 then
        modo_div <= 0;
      elsif n_flancos < 25 then
        modo_div <= 1;
      else
        modo_div <= 2;
      end if;

    -- MEDIO: 0..7s -> 0 | 8..19s -> 1 | 20+ -> 2
    elsif modo_m = '1' then
      if n_flancos < 8 then
        modo_div <= 0;
      elsif n_flancos < 20 then
        modo_div <= 1;
      else
        modo_div <= 2;
      end if;

    -- DIFICIL: 0..5s -> 0 | 6..14s -> 1 | 15+ -> 2
    elsif modo_d = '1' then
      if n_flancos < 6 then
        modo_div <= 0;
      elsif n_flancos < 15 then
        modo_div <= 1;
      else
        modo_div <= 2;
      end if;
    end if;

  end process;

end Behavioral;