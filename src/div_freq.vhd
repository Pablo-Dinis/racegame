library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity div_freq is
  Port (
    clk      : in  STD_LOGIC;
    reset    : in  std_logic;   -- ACTIVO BAJO (como en tu código)
    modo_f   : in  std_logic;
    modo_m   : in  std_logic;
    modo_d   : in  std_logic;
    modo_div : in  integer;     -- 0/1/2 (fase)
    tick     : out std_logic    -- pulso 1 ciclo cuando toca avanzar obstáculo
  );
end div_freq;

architecture Behavioral of div_freq is
  signal limit   : integer := 100000000-1; -- por defecto 1Hz
  signal counter : integer := 0;
begin

  process(clk)
  begin
    if rising_edge(clk) then

      if reset = '0' then
        counter <= 0;
        tick <= '0';

      else
        -- Selección del divisor (CLK=100MHz)
        -- Fácil:   1.0 Hz, 1.5 Hz, 2.0 Hz
        -- Medio:   1.5 Hz, 2.0 Hz, 3.0 Hz
        -- Difícil: 2.0 Hz, 3.0 Hz, 4.0 Hz

        if modo_f = '1' then
          case modo_div is
            when 0 => limit <= 100000000-1; -- 1.0 Hz  (1.000 s)
            when 1 => limit <= 66666667-1;  -- 1.5 Hz  (0.667 s)
            when 2 => limit <= 50000000-1;  -- 2.0 Hz  (0.500 s)
            when others => limit <= 100000000-1;
          end case;

        elsif modo_m = '1' then
          case modo_div is
            when 0 => limit <= 66666667-1;  -- 1.5 Hz  (0.667 s)
            when 1 => limit <= 50000000-1;  -- 2.0 Hz  (0.500 s)
            when 2 => limit <= 33333333-1;  -- 3.0 Hz  (0.333 s)
            when others => limit <= 66666667-1;
          end case;

        elsif modo_d = '1' then
          case modo_div is
            when 0 => limit <= 50000000-1;  -- 2.0 Hz  (0.500 s)
            when 1 => limit <= 33333333-1;  -- 3.0 Hz  (0.333 s)
            when 2 => limit <= 25000000-1;  -- 4.0 Hz  (0.250 s)
            when others => limit <= 50000000-1;
          end case;

        else
          limit <= 100000000-1; -- default
        end if;

        -- Contador
        if counter >= limit then
          counter <= 0;
          tick <= '1'; -- pulso 1 ciclo
        else
          counter <= counter + 1;
          tick <= '0';
        end if;

      end if;
    end if;
  end process;

end Behavioral;