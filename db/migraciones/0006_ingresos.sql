-- Clubio — ingresos
--
-- Las estadisticas de ingresos del brief: cuanto dejo el club en el mes
-- corriente hasta hoy, cuanto historicamente hasta hoy, cada deporte, y
-- cuanto viene de fijos y clases.
--
-- Un ingreso es el precio congelado de un turno confirmado que ya termino
-- (ADR 0005 y 0007). Un turno de manana no es ingreso todavia; un turno
-- cancelado no lo es nunca. Es la misma definicion de "jugado" que usan
-- las vistas de clientes: la plata que dejo un cliente y la plata que entro
-- al club son el mismo numero mirado de dos lados.
--
-- "Hasta hoy" se resuelve en la zona horaria del club, no del servidor: el
-- mes corriente arranca el 1 a las 00:00 hora del club.
--
-- Dos funciones y no vistas porque necesitan el club y la fecha de corte
-- como parametro, y porque agrupan: PostgREST no agrupa. Corren con los
-- permisos de quien llama, asi que RLS aplica.

-- Una fila por (periodo, deporte, tipo). periodo es 'mes' o 'historico'.
create type fila_ingresos as (
  periodo   text,
  deporte   text,
  tipo      text,
  turnos    bigint,
  total     numeric
);

create or replace function fn_ingresos(
  p_club  uuid,
  p_hasta date default null   -- por defecto, hoy en la zona del club
)
returns setof fila_ingresos
language sql
stable
set search_path = public
as $$
  with club as (
    select zona_horaria as tz from clubes where id = p_club
  ),
  corte as (
    select coalesce(p_hasta, (now() at time zone club.tz)::date) as hasta, club.tz
      from club
  ),
  jugados as (
    select d.nombre as deporte,
           t.tipo,
           t.precio,
           (t.inicio at time zone corte.tz)::date as dia
      from turnos t
      join canchas  c on c.id = t.cancha_id
      join deportes d on d.id = c.deporte_id
      cross join corte
     where t.club_id = p_club
       and t.estado = 'confirmado'
       and t.fin <= now()
       and (t.inicio at time zone corte.tz)::date <= corte.hasta
  )
  select 'historico', deporte, tipo, count(*), sum(precio)
    from jugados
   group by deporte, tipo
  union all
  select 'mes', deporte, tipo, count(*), sum(precio)
    from jugados, corte
   where dia >= date_trunc('month', corte.hasta)::date
   group by deporte, tipo;
$$;

-- Los ultimos meses, mes a mes, por deporte y tipo. Para el grafico.
create type fila_ingresos_mes as (
  mes       date,
  deporte   text,
  tipo      text,
  turnos    bigint,
  total     numeric
);

create or replace function fn_ingresos_mensuales(
  p_club   uuid,
  p_meses  integer default 12
)
returns setof fila_ingresos_mes
language sql
stable
set search_path = public
as $$
  with club as (
    select zona_horaria as tz from clubes where id = p_club
  )
  select date_trunc('month', t.inicio at time zone club.tz)::date as mes,
         d.nombre,
         t.tipo,
         count(*),
         sum(t.precio)
    from turnos t
    join canchas  c on c.id = t.cancha_id
    join deportes d on d.id = c.deporte_id
    cross join club
   where t.club_id = p_club
     and t.estado = 'confirmado'
     and t.fin <= now()
     and t.inicio >= (date_trunc('month', now() at time zone club.tz) - make_interval(months => p_meses - 1)) at time zone club.tz
   group by 1, 2, 3
   order by 1, 2, 3;
$$;
