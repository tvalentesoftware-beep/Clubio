-- Clubio — fn_precio_vigente y fn_materializar_serie
--
-- La segunda mitad del ADR 0004: la serie es la regla, y esta funcion genera
-- los turnos concretos hasta un horizonte, sin pisar nada de lo que ya
-- exista.
--
-- Para cada fecha de la serie en el rango, devuelve una fila que dice que
-- paso. Es la respuesta a "avisar si ya hay algo donde iria el fijo":
--
--   creado            se genero el turno.
--   a_crear           (solo simulando) se generaria.
--   ya_existia        ya hay un turno de esta serie ese dia, confirmado o
--                     cancelado. Manda el turno: si el cliente falto ese
--                     sabado, no se le vuelve a generar.
--   conflicto         un turno ocupa alguno de los espacios de la cancha en
--                     ese horario. referencia_id es ese turno y detalle dice
--                     de quien es y en que cancha. No se toca.
--   conflicto_serie   otra serie activa cae sobre ese horario y todavia no
--                     se materializo. referencia_id es la otra serie.
--   cerrado           hay un cierre del club o de la cancha ese dia.
--   fuera_de_horario  la cancha no abre a esa hora ese dia de la semana.
--   sin_tarifa        no hay precio vigente para esa fecha; el turno no se
--                     crea porque el precio se congela al crearlo (ADR 0005).
--
-- Con p_simular = true no escribe nada: el panel llama primero simulando,
-- muestra los conflictos, y recien si el encargado confirma llama en serio.
--
-- Para decidir si el horario esta libre no reinventa nada: le pregunta a
-- fn_disponibilidad, que es la unica definicion de "esta libre" (ADR 0002).
-- Y aunque esa consulta diga libre, el insert queda protegido por la
-- restriccion de exclusion: si alguien se adelanta entre la consulta y el
-- insert, la fila sale como conflicto en vez de fallar.
--
-- Solo genera desde p_desde (por defecto hoy): el pasado no se materializa.

-- ---------------------------------------------------------------------------
-- La regla de precedencia de tarifas, en un solo lugar (ADR 0005):
-- la mas especifica gana. Cancha y tipo > cancha > tipo > general.
-- ---------------------------------------------------------------------------

create or replace function fn_precio_vigente(
  p_club   uuid,
  p_cancha uuid,
  p_tipo   text,
  p_fecha  date
)
returns numeric
language sql
stable
set search_path = public
as $$
  select t.precio
    from canchas c
    join tarifas t on t.club_id = c.club_id and t.deporte_id = c.deporte_id
   where c.id = p_cancha
     and c.club_id = p_club
     and (t.cancha_id  is null or t.cancha_id  = p_cancha)
     and (t.tipo_turno is null or t.tipo_turno = p_tipo)
     and t.vigente_desde <= p_fecha
     and (t.vigente_hasta is null or t.vigente_hasta >= p_fecha)
   order by (t.cancha_id is not null) desc,
            (t.tipo_turno is not null) desc,
            t.vigente_desde desc
   limit 1;
$$;

-- ---------------------------------------------------------------------------

create type resultado_materializacion as (
  fecha          date,
  resultado      text,
  turno_id       uuid,
  referencia_id  uuid,
  detalle        text
);

create or replace function fn_materializar_serie(
  p_serie    uuid,
  p_desde    date    default current_date,
  p_hasta    date    default current_date + 56,
  p_simular  boolean default false
)
returns setof resultado_materializacion
language plpgsql
set search_path = public
as $$
declare
  s         series%rowtype;
  r         resultado_materializacion;
  d         record;
  f         date;
  v_tz      text;
  v_ini     timestamptz;
  v_fin     timestamptz;
  v_precio  numeric;
  v_nuevo   uuid;
begin
  select * into s from series where id = p_serie;
  if not found then
    raise exception 'la serie % no existe', p_serie;
  end if;

  select zona_horaria into v_tz from clubes where id = s.club_id;

  for f in
    select g::date
      from generate_series(
             greatest(p_desde, s.vigente_desde),
             least(p_hasta, coalesce(s.vigente_hasta, p_hasta)),
             interval '1 day') as g
     where extract(dow from g) = s.dia_semana
  loop
    r.fecha         := f;
    r.resultado     := null;
    r.turno_id      := null;
    r.referencia_id := null;
    r.detalle       := null;

    v_ini := (f + s.hora_inicio) at time zone v_tz;
    v_fin := v_ini + make_interval(mins => s.duracion_min);

    -- Ya materializado ese dia, confirmado o cancelado: manda el turno.
    select t.id into r.turno_id
      from turnos t
     where t.serie_id = s.id
       and (t.inicio at time zone v_tz)::date = f
     limit 1;

    if found then
      r.resultado := 'ya_existia';
      return next r;
      continue;
    end if;

    -- Que dice la disponibilidad sobre ese rango, en la cancha de la serie.
    select count(*)                                                        as n,
           bool_or(x.estado = 'ocupado')                                   as ocupado,
           (array_agg(x.turno_id)  filter (where x.estado = 'ocupado'))[1] as turno_id,
           bool_or(x.estado = 'cerrado')                                   as cerrado,
           (array_agg(x.cierre_id) filter (where x.estado = 'cerrado'))[1] as cierre_id,
           bool_or(x.estado = 'serie' and x.serie_id <> s.id)              as otra_serie,
           (array_agg(x.serie_id)  filter (where x.estado = 'serie'
                                             and x.serie_id <> s.id))[1]   as otra_serie_id
      into d
      from fn_disponibilidad(s.club_id, f, f, s.cancha_id) x
     where tstzrange(x.inicio, x.fin, '[)') && tstzrange(v_ini, v_fin, '[)');

    if d.n = 0 then
      r.resultado := 'fuera_de_horario';

    elsif d.ocupado then
      r.resultado     := 'conflicto';
      r.referencia_id := d.turno_id;
      select format('%s en %s, %s a %s',
                    cl.nombre, ca.nombre,
                    to_char(t.inicio at time zone v_tz, 'HH24:MI'),
                    to_char(t.fin    at time zone v_tz, 'HH24:MI'))
        into r.detalle
        from turnos t
        join clientes cl on cl.id = t.cliente_id
        join canchas  ca on ca.id = t.cancha_id
       where t.id = d.turno_id;

    elsif d.cerrado then
      r.resultado     := 'cerrado';
      r.referencia_id := d.cierre_id;
      select motivo into r.detalle from cierres where id = d.cierre_id;

    elsif d.otra_serie then
      r.resultado     := 'conflicto_serie';
      r.referencia_id := d.otra_serie_id;
      select format('%s de %s en %s, %s',
                    initcap(o.tipo), cl.nombre, ca.nombre,
                    to_char(o.hora_inicio, 'HH24:MI'))
        into r.detalle
        from series o
        join clientes cl on cl.id = o.cliente_id
        join canchas  ca on ca.id = o.cancha_id
       where o.id = d.otra_serie_id;

    else
      v_precio := fn_precio_vigente(s.club_id, s.cancha_id, s.tipo, f);

      if v_precio is null then
        r.resultado := 'sin_tarifa';

      elsif p_simular then
        r.resultado := 'a_crear';
        r.detalle   := v_precio::text;

      else
        begin
          insert into turnos (club_id, cancha_id, cliente_id, serie_id, tipo,
                              estado, inicio, fin, precio, creado_por)
          values (s.club_id, s.cancha_id, s.cliente_id, s.id, s.tipo,
                  'confirmado', v_ini, v_fin, v_precio, auth.uid())
          returning id into v_nuevo;

          insert into turno_eventos (club_id, turno_id, tipo, detalle, usuario_id)
          values (s.club_id, v_nuevo, 'creado',
                  jsonb_build_object('origen', 'serie', 'serie_id', s.id),
                  auth.uid());

          r.resultado := 'creado';
          r.turno_id  := v_nuevo;
          r.detalle   := v_precio::text;

        exception
          when exclusion_violation then
            -- alguien ocupo el espacio entre la consulta y el insert
            r.resultado := 'conflicto';
            r.detalle   := 'el espacio se ocupo mientras se generaba';
        end;
      end if;
    end if;

    return next r;
  end loop;
end;
$$;
