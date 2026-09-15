-- Clubio — fn_disponibilidad
--
-- La unica definicion de "esta libre" que hay en el sistema (ADR 0002).
-- Devuelve, para un club y un rango de dias, todos los slots de todas las
-- canchas con su estado. Es lo que la grilla semanal pinta, en una sola
-- consulta, sin que la aplicacion tenga que saber ninguna regla.
--
-- Como se arma un slot:
--
--   * Se parte de las franjas de apertura vigentes para la cancha ese dia
--     de la semana, y se corta en pasos iguales a la duracion del deporte.
--     Padel de 90 minutos abriendo a las 14:30 da 14:30, 16:00, 17:30...
--     El paso es la duracion y no una grilla de media hora: es lo que el
--     club vende y lo que el encargado espera ver.
--
--   * La hora local sale de la zona horaria del club. Los slots se devuelven
--     como timestamptz, listos para comparar con turnos y ocupaciones.
--
-- Como se decide el estado, en este orden de precedencia:
--
--   ocupado   hay una ocupacion sobre alguno de los espacios de la cancha.
--             Puede venir de un turno de OTRA cancha que comparte espacio;
--             turno_cancha_id lo dice, para que la pantalla explique
--             "no disponible por reserva en La grande" (ADR 0003).
--   cerrado   hay un cierre vigente sobre la cancha o sobre el club.
--   serie     una serie activa cae sobre el slot y todavia no se
--             materializo para ese dia. Si ya existe el turno de la serie
--             para ese dia -confirmado o cancelado- manda el turno, no la
--             serie (ADR 0004). Una serie que no esta alineada con la grilla
--             -clase a las 18:00 con slots de 17:30 y 19:00- bloquea los
--             dos slots que toca, que es lo correcto: el espacio no esta.
--   libre     nada de lo anterior.
--
-- La funcion corre con los permisos de quien la llama, asi que RLS aplica:
-- un usuario solo ve slots de sus clubes.

-- Un tipo con nombre, y no "returns table", para que las pruebas y la
-- aplicacion puedan declarar variables de este tipo.
create type slot_disponibilidad as (
  cancha_id        uuid,
  inicio           timestamptz,
  fin              timestamptz,
  estado           text,
  turno_id         uuid,
  turno_cancha_id  uuid,
  cierre_id        uuid,
  serie_id         uuid
);

create or replace function fn_disponibilidad(
  p_club   uuid,
  p_desde  date,
  p_hasta  date,
  p_cancha uuid default null
)
returns setof slot_disponibilidad
language sql
stable
set search_path = public
as $$
with club as (
  select id, zona_horaria as tz
    from clubes
   where id = p_club
),
dias as (
  select d::date as dia
    from generate_series(p_desde, p_hasta, interval '1 day') as d
),
slots as (
  select c.id                               as cancha_id,
         club.tz,
         s                                  as inicio,
         s + make_interval(mins => dep.duracion_min) as fin,
         dias.dia
    from canchas c
    join club          on club.id = c.club_id
    join deportes dep  on dep.id = c.deporte_id
    cross join dias
    join franjas_apertura f
      on f.cancha_id = c.id
     and f.dia_semana = extract(dow from dias.dia)
     and f.vigente_desde <= dias.dia
     and (f.vigente_hasta is null or f.vigente_hasta >= dias.dia)
    cross join lateral generate_series(
      (dias.dia + f.hora_desde) at time zone club.tz,
      (dias.dia + f.hora_hasta) at time zone club.tz - make_interval(mins => dep.duracion_min),
      make_interval(mins => dep.duracion_min)
    ) as s
   where c.club_id = p_club
     and c.activa
     and (p_cancha is null or c.id = p_cancha)
)
select s.cancha_id,
       s.inicio,
       s.fin,
       case
         when o.turno_id is not null then 'ocupado'
         when ci.id      is not null then 'cerrado'
         when se.id      is not null then 'serie'
         else 'libre'
       end as estado,
       o.turno_id,
       o.turno_cancha_id,
       ci.id as cierre_id,
       se.id as serie_id
  from slots s

  -- ocupado: cualquier espacio de esta cancha, tomado por cualquier turno
  left join lateral (
    select t.id as turno_id, t.cancha_id as turno_cancha_id
      from cancha_espacios ce
      join ocupaciones oc on oc.espacio_id = ce.espacio_id
      join turnos t       on t.id = oc.turno_id
     where ce.cancha_id = s.cancha_id
       and oc.durante && tstzrange(s.inicio, s.fin, '[)')
     order by (t.cancha_id = s.cancha_id) desc   -- si hay varios, el propio primero
     limit 1
  ) o on true

  -- cerrado: sobre esta cancha o sobre el club entero
  left join lateral (
    select c.id
      from cierres c
     where c.club_id = p_club
       and (c.cancha_id is null or c.cancha_id = s.cancha_id)
       and c.durante && tstzrange(s.inicio, s.fin, '[)')
     limit 1
  ) ci on true

  -- serie: activa ese dia, sobre un espacio compartido, sin turno materializado
  left join lateral (
    select se.id
      from series se
      join cancha_espacios ce_serie on ce_serie.cancha_id = se.cancha_id
      join cancha_espacios ce_slot  on ce_slot.cancha_id = s.cancha_id
                                   and ce_slot.espacio_id = ce_serie.espacio_id
     where se.club_id = p_club
       and se.dia_semana = extract(dow from s.dia)
       and se.vigente_desde <= s.dia
       and (se.vigente_hasta is null or se.vigente_hasta >= s.dia)
       and tstzrange(s.inicio, s.fin, '[)') && tstzrange(
             (s.dia + se.hora_inicio) at time zone s.tz,
             (s.dia + se.hora_inicio) at time zone s.tz + make_interval(mins => se.duracion_min),
             '[)')
       and not exists (
             select 1
               from turnos t
              where t.serie_id = se.id
                and (t.inicio at time zone s.tz)::date = s.dia
           )
     limit 1
  ) se on true

 order by s.cancha_id, s.inicio;
$$;
