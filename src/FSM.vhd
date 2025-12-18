library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FSM is
  port (
    clk            : in  std_logic;
    reset_n        : in  std_logic;   -- ACTIVO BAJO
    init_pulse     : in  std_logic;
    hit            : in  std_logic;
    tick_1s        : in  std_logic;

    modo_facil     : in  std_logic;
    modo_medio     : in  std_logic;
    modo_dificil   : in  std_logic;

    enable_coche      : out std_logic;
    enable_obstaculos : out std_logic;

    winner         : out std_logic;
    looser         : out std_logic
  );
end entity;

architecture behavioral of FSM is
  type state_type is (ESPERANDO, JUGANDO, WIN, LOSE);
  signal st, st_n : state_type;

  -- Tiempo para ganar (segundos)
  constant WIN_EASY : natural := 20;
  constant WIN_MED  : natural := 30;
  constant WIN_HARD : natural := 40;

  -- Tiempo que se muestra WIN / LOSE antes de volver a ESPERANDO
  constant END_TIME : natural := 4;

  signal play_cnt : unsigned(7 downto 0) := (others => '0');
  signal end_cnt  : unsigned(3 downto 0) := (others => '0');

  function win_target(f,m,d : std_logic) return natural is
  begin
    if d='1' then return WIN_HARD;
    elsif m='1' then return WIN_MED;
    else return WIN_EASY;
    end if;
  end function;

begin

  -- Registros (estado + contadores)
  process(clk, reset_n)
  begin
    if reset_n = '0' then
      st <= ESPERANDO;
      play_cnt <= (others => '0');
      end_cnt  <= (others => '0');
    elsif rising_edge(clk) then
      st <= st_n;

      -- contador de juego
      if st = JUGANDO then
        if tick_1s = '1' then
          play_cnt <= play_cnt + 1;
        end if;
      else
        play_cnt <= (others => '0');
      end if;

      -- contador de fin (WIN/LOSE)
      if (st = WIN) or (st = LOSE) then
        if tick_1s = '1' then
          if end_cnt < END_TIME then
          end_cnt <= end_cnt + 1;
         end if;
        end if;
      else
        end_cnt <= (others => '0');
      end if;

    end if;
  end process;

  -- Próximo estado
  process(st, init_pulse, hit, play_cnt, end_cnt, modo_facil, modo_medio, modo_dificil)
    variable target : natural;
  begin
    st_n <= st;
    target := win_target(modo_facil, modo_medio, modo_dificil);

    case st is
      when ESPERANDO =>
        if init_pulse='1' then
          st_n <= JUGANDO;
        end if;

      when JUGANDO =>
        if hit='1' then
          st_n <= LOSE;
        elsif to_integer(play_cnt) >= target then
          st_n <= WIN;
        end if;

      when WIN =>
        if to_integer(end_cnt) >= END_TIME then
          st_n <= ESPERANDO;
        end if;

      when LOSE =>
        if to_integer(end_cnt) >= END_TIME then
          st_n <= ESPERANDO;
        end if;
    end case;
  end process;

  -- Salidas
  process(st)
  begin
    enable_coche      <= '0';
    enable_obstaculos <= '0';
    winner            <= '0';
    looser            <= '0';

    case st is
      when ESPERANDO =>
        null;

      when JUGANDO =>
        enable_coche      <= '1';
        enable_obstaculos <= '1';

      when WIN =>
        winner <= '1';

      when LOSE =>
        looser <= '1';
    end case;
  end process;

end architecture;