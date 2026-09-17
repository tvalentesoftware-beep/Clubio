-- Clubio — fn_crear_serie
--
-- Lo que el panel llama cuando el encargado marca un turno como fijo o
-- clase. Junta en una sola operacion atomica lo que de otro modo serian
-- tres viajes con una serie a medio crear en el medio: inserta la serie,
-- la simula, y decide.
--
--   * Si la simulacion no encuentra problemas, genera los turnos y devuelve
--     lo generado. Un solo paso.
--   * Si encuentra problemas -conflicto, conflicto_serie, cerrado,
--     fuera_de_horario, sin_tarifa- y p_confirmar es false, DESHACE la
--     insercion de la serie y devuelve la simulacion tal cual, con las
--     filas 'a_crear' y las problematicas. La serie no existe: el panel
--     muestra el aviso y pregunta.
--   * Si p_confirmar es true, genera igual: los dias con problema quedan
--     salteados y salen listados, los demas se crean.
--
-- Como saber que paso desde afuera: si alguna fila dice 'a_crear', fue una
-- simulacion y no se escribio nada. Si dice 'creado', la serie existe.
--
-- El deshacer se hace con un bloque de excepcion: lo que se escribio adentro
-- del bloque se revierte, pero las variables plpgsql conservan su valor, asi
-- que la simulacion sobrevive al rollback y se puede devolver.

create or replace function fn_crear_serie(
  p_club           uuid,
  p_cancha         uuid,
  p_cliente        uuid,
  p_tipo           text,
  p_dia_semana     integer,
  p_hora_inicio    time,
  p_duracion_min   integer,
  p_vigente_desde  date,
  p_hasta          date    default current_date + 56,
  p_confirmar      boolean default false
)
returns setof resultado_materializacion
language plpgsql
set search_path = public
as $$
declare
  v_serie      uuid;
  v_simulacion resultado_materializacion[];
  v_problemas  integer;
begin
  begin
    insert into series (club_id, cancha_id, cliente_id, tipo, dia_semana,
                        hora_inicio, duracion_min, vigente_desde)
    values (p_club, p_cancha, p_cliente, p_tipo, p_dia_semana,
            p_hora_inicio, p_duracion_min, p_vigente_desde)
    returning id into v_serie;

    if not p_confirmar then
      select array_agg(m), count(*) filter (where m.resultado <> 'a_crear')
        into v_simulacion, v_problemas
        from fn_materializar_serie(v_serie, p_vigente_desde, p_hasta, true) m;

      if coalesce(v_problemas, 0) > 0 then
        raise exception 'hay dias con problemas' using errcode = 'P0002';
      end if;
    end if;

    return query
      select * from fn_materializar_serie(v_serie, p_vigente_desde, p_hasta, false);
    return;

  exception
    when sqlstate 'P0002' then
      -- la serie ya no existe; se devuelve la simulacion para que el panel avise
      return query select * from unnest(v_simulacion);
      return;
  end;
end;
$$;
