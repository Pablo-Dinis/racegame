library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
  Port (
    b_inicio    : in  STD_LOGIC;
    modo        : in  STD_LOGIC_VECTOR (1 downto 0); -- SW[1:0]
    reset_n     : in  STD_LOGIC;  -- ACTIVO BAJO
    arriba      : in  STD_LOGIC;
    abajo       : in  STD_LOGIC;
    CLK         : in  STD_LOGIC;

    hitazo      : in std_logic; -- se queda para pruebas (no se usa aquí)

    inf_displays: out STD_LOGIC_VECTOR (6 downto 0);
    sel_displays: out STD_LOGIC_VECTOR (7 downto 0)
  );
end top;

architecture Behavioral of top is

  component SYNCHRNZR is
    Port ( CLK : in STD_LOGIC; ASYNC_IN : in STD_LOGIC; SYNC_OUT : out STD_LOGIC );
  end component;

  component EDGEDTCTR is
    Port ( CLK : in STD_LOGIC; SYNC_IN : in STD_LOGIC; EDGE : out STD_LOGIC );
  end component;

  component coche is
    Port (
      up      : in  STD_LOGIC;
      down    : in  STD_LOGIC;
      clk     : in  STD_LOGIC;
      empezar : in  std_logic;
      code    : out std_logic_vector(6 downto 0);
      display : out std_logic
    );
  end component;

  component DECODER_MODE is
    port(
      entrada_sw   : in  std_logic_vector (1 downto 0);
      modo_facil   : out std_logic;
      modo_medio   : out std_logic;
      modo_dificil : out std_logic
    );
  end component;

  component comparador is
    Port (
      n_flancos : in integer;
      modo_f    : in std_logic;
      modo_m    : in std_logic;
      modo_d    : in std_logic;
      modo_div  : out integer
    );
  end component;

  component div_freq is
    Port (
      clk      : in STD_LOGIC;
      reset    : in std_logic;     -- activo bajo en tu código
      modo_f   : in std_logic;
      modo_m   : in std_logic;
      modo_d   : in std_logic;
      modo_div : in integer;
      tick     : out std_logic
    );
  end component;

  component carretera is
    generic ( ROAD_LENGTH: natural := 8; segment : natural := 7 );
    Port (
      clk         : in  STD_LOGIC;
      rst         : in  STD_LOGIC;      -- activo bajo en tu código
      CE          : in  STD_LOGIC;
      modo_f      : in  STD_LOGIC;
      modo_m      : in  STD_LOGIC;
      modo_d      : in  STD_LOGIC;
      road        : out std_logic_vector(55 downto 0);
      s_toggle_out: out STD_LOGIC
    );
  end component;

  component mult_road is
    Port (
      CLK           : in  STD_LOGIC;
      RST           : in  STD_LOGIC; -- activo bajo
      ROAD_ARRAY_IN : in  STD_LOGIC_VECTOR(55 downto 0);
      SEGMENTS_OUT  : out STD_LOGIC_VECTOR(6 downto 0);
      ANODES_OUT    : out STD_LOGIC_VECTOR(7 downto 0)
    );
  end component;

  component comp_choque is
    Port (
      fin_carretera : in STD_LOGIC_VECTOR (6 downto 0);
      pos_coche     : in STD_LOGIC_VECTOR (6 downto 0);
      clk           : in std_logic;
      choque        : out STD_LOGIC
    );
  end component;

  component FSM is
    port (
      clk              : in  std_logic;
      reset_n          : in  std_logic;
      init_pulse       : in  std_logic;
      hit              : in  std_logic;
      tick_1s          : in  std_logic;
      modo_facil       : in  std_logic;
      modo_medio       : in  std_logic;
      modo_dificil     : in  std_logic;
      enable_coche     : out std_logic;
      enable_obstaculos: out std_logic;
      winner           : out std_logic;
      looser           : out std_logic
    );
  end component;

  -- Señales de botones
  signal s_up_sync, s_dn_sync, s_in_sync : std_logic;
  signal up_pulse, dn_pulse, init_pulse  : std_logic;

  -- Modo
  signal modo_f, modo_m, modo_d : std_logic;

  -- Juego
  signal en_coche, en_obs : std_logic;
  signal winner_s, looser_s : std_logic;

  -- Tick 1s
  signal tick_1s : std_logic;
  signal cnt_1s  : unsigned(26 downto 0) := (others => '0'); -- 0..99_999_999

  -- "Fase" para velocidad
  signal sec_count : integer := 0;
  signal modo_div  : integer := 0;

  -- Movimiento obstáculos
  signal move_tick : std_logic;
  signal ce_move   : std_logic;

  -- Road + coche
  signal road56        : std_logic_vector(55 downto 0);
  signal toggle_blink  : std_logic;
  signal car_code      : std_logic_vector(6 downto 0);
  signal car_disp      : std_logic;

  -- Choque: combinacional + pulso sincronizado a avance
  signal choque_raw_comb : std_logic;
  signal ce_move_d       : std_logic;
  signal hit_pulse       : std_logic;

  -- Mux a displays
  signal an_mux   : std_logic_vector(7 downto 0);
  signal disp56   : std_logic_vector(55 downto 0);

  -- Mensajes 7seg (ACTIVO ALTO interno, mult_road invierte al final)
  subtype seg7 is std_logic_vector(6 downto 0);
  type msg8_t is array(7 downto 0) of seg7;

  constant S_BLANK : seg7 := "0000000";
  constant S_A     : seg7 := "1110111";
  constant S_E     : seg7 := "1001111";
  constant S_G     : seg7 := "1011111";
  constant S_O     : seg7 := "1111110";
  constant S_R     : seg7 := "0000101";
  constant S_V     : seg7 := "0111110";
  constant S_I     : seg7 := "0110000";
  constant S_N     : seg7 := "0010101";
  constant S_M     : seg7 := "0010101";
  constant S_W     : seg7 := "0111110";

  constant MSG_GAMEOVER : msg8_t := (
    7 => S_G, 6 => S_A, 5 => S_M, 4 => S_E,
    3 => S_O, 2 => S_V, 1 => S_E, 0 => S_R
  );

  constant MSG_WINNER : msg8_t := (
    7 => S_BLANK, 6 => S_W, 5 => S_I, 4 => S_N,
    3 => S_N, 2 => S_E, 1 => S_R, 0 => S_BLANK
  );

  function pack_msg(m : msg8_t) return std_logic_vector is
    variable v : std_logic_vector(55 downto 0);
  begin
    v := m(7) & m(6) & m(5) & m(4) & m(3) & m(2) & m(1) & m(0);
    return v;
  end function;

begin

  -- Sync + edge botones
  U1: SYNCHRNZR port map(CLK=>CLK, ASYNC_IN=>arriba,   SYNC_OUT=>s_up_sync);
  U2: SYNCHRNZR port map(CLK=>CLK, ASYNC_IN=>abajo,    SYNC_OUT=>s_dn_sync);
  U3: SYNCHRNZR port map(CLK=>CLK, ASYNC_IN=>b_inicio, SYNC_OUT=>s_in_sync);

  E1: EDGEDTCTR port map(CLK=>CLK, SYNC_IN=>s_up_sync, EDGE=>up_pulse);
  E2: EDGEDTCTR port map(CLK=>CLK, SYNC_IN=>s_dn_sync, EDGE=>dn_pulse);
  E3: EDGEDTCTR port map(CLK=>CLK, SYNC_IN=>s_in_sync, EDGE=>init_pulse);

  -- Decoder modo
  D0: DECODER_MODE port map(
    entrada_sw=>modo,
    modo_facil=>modo_f,
    modo_medio=>modo_m,
    modo_dificil=>modo_d
  );

  -- Tick 1 segundo (100MHz)
  process(CLK, reset_n)
  begin
    if reset_n='0' then
      cnt_1s <= (others=>'0');
      tick_1s <= '0';
    elsif rising_edge(CLK) then
      if cnt_1s = to_unsigned(100000000-1, cnt_1s'length) then
        cnt_1s <= (others=>'0');
        tick_1s <= '1';
      else
        cnt_1s <= cnt_1s + 1;
        tick_1s <= '0';
      end if;
    end if;
  end process;

  -- Contador de "segundos jugados" para acelerar (solo mientras JUGANDO)
  process(CLK, reset_n)
  begin
    if reset_n='0' then
      sec_count <= 0;
    elsif rising_edge(CLK) then
      if en_obs='1' then
        if tick_1s='1' then
          sec_count <= sec_count + 1;
        end if;
      else
        sec_count <= 0;
      end if;
    end if;
  end process;

  -- Comparador para elegir fase de velocidad (modo_div)
  C0: comparador port map(
    n_flancos => sec_count,
    modo_f    => modo_f,
    modo_m    => modo_m,
    modo_d    => modo_d,
    modo_div  => modo_div
  );

  -- Divisor velocidad obstáculos
  V0: div_freq port map(
    clk      => CLK,
    reset    => reset_n,
    modo_f   => modo_f,
    modo_m   => modo_m,
    modo_d   => modo_d,
    modo_div => modo_div,
    tick     => move_tick
  );

  -- FSM: hit SOLO cuando toca (hit_pulse)
  F0: FSM port map(
    clk               => CLK,
    reset_n           => reset_n,
    init_pulse        => init_pulse,
    hit               => hit_pulse,    -- <- CLAVE
    tick_1s           => tick_1s,
    modo_facil        => modo_f,
    modo_medio        => modo_m,
    modo_dificil      => modo_d,
    enable_coche      => en_coche,
    enable_obstaculos => en_obs,
    winner            => winner_s,
    looser            => looser_s
  );

  -- Coche
  CAR: coche port map(
    up      => up_pulse,
    down    => dn_pulse,
    clk     => CLK,
    empezar => en_coche,
    code    => car_code,
    display => car_disp
  );

  -- Mover carretera SOLO con pulso y enable
  ce_move <= en_obs and move_tick;

  ROAD: carretera port map(
    clk          => CLK,
    rst          => reset_n,
    CE           => ce_move,
    modo_f       => modo_f,
    modo_m       => modo_m,
    modo_d       => modo_d,
    road         => road56,
    s_toggle_out => toggle_blink
  );

  -- Choque combinacional contra el display AN1 (antes del coche que está en AN0)
  HIT: comp_choque port map(
    fin_carretera => road56(13 downto 7),
    pos_coche     => car_code,
    clk           => CLK,
    choque        => choque_raw_comb
  );

  -- Generar hit SOLO cuando hubo avance de carretera
  -- (se evalúa 1 ciclo después del ce_move, cuando road56 ya está actualizado)
  process(CLK, reset_n)
  begin
    if reset_n='0' then
      ce_move_d <= '0';
      hit_pulse <= '0';
    elsif rising_edge(CLK) then
      ce_move_d <= ce_move;

      if ce_move_d='1' then
        hit_pulse <= choque_raw_comb;
      else
        hit_pulse <= '0';
      end if;
    end if;
  end process;

  -- Mux de lo que se manda a los 7seg
  process(winner_s, looser_s, road56, car_code)
  begin
    if winner_s='1' then
      disp56 <= pack_msg(MSG_WINNER);
    elsif looser_s='1' then
      disp56 <= pack_msg(MSG_GAMEOVER);
    else
      disp56 <= road56(55 downto 7) & car_code; -- carretera + coche en AN0
    end if;
  end process;

  -- Driver de displays
  DISP: mult_road port map(
    CLK           => CLK,
    RST           => reset_n,
    ROAD_ARRAY_IN => disp56,
    SEGMENTS_OUT  => inf_displays,
    ANODES_OUT    => an_mux
  );

  -- Parpadeo SOLO en modo medio y SOLO jugando (sin borrar WIN/LOSE)
  sel_displays <= (others => '1')
                  when (toggle_blink='1' and modo_m='1' and en_obs='1' and winner_s='0' and looser_s='0')
                  else an_mux;

end Behavioral;

