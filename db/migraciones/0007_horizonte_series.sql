-- Clubio — el horizonte de las series se empuja solo
--
-- ADR 0004: las series se materializan con horizonte rodante, y ese
-- horizonte lo refresca una tarea periodica. Esta es la tarea.
--
-- fn_materializar_todas recorre las series vigentes de todos los clubes y
-- llama a fn_materializar_serie para cada una, de hoy a hoy + p_dias. Es
-- idempotente: lo que ya existe sale como ya_existia y no se toca; lo que
-- choca sale como conflicto y no se pisa. Devuelve un resumen por serie
-- para que quede en el log de pg_cron que paso.
--
-- Corre como security definer porque pg_cron ejecuta sin usuario de
-- Supabase: auth.uid() es null y RLS no dejaria ver ninguna serie. El
-- search_path fijo evita que alguien la desvie a otro esquema.
--
-- El modo de falla es el que se eligio en el ADR: si el cron se cae, el
-- club ve menos semanas generadas en la grilla, pero fn_disponibilidad
-- sigue reservando el horario de las series aunque no esten materializadas.

create type resumen_materializacion as (
  serie_id   uuid,
  club_id    uuid,
  creados    bigint,
  existian   bigint,
  conflictos bigint,
  otros      bigint
);

create or replace function fn_materializar_todas(p_dias integer default 56)
returns setof resumen_materializacion
language plpgsql
security definer
set search_path = public
as $$
declare
  s record;
  r resumen_materializacion;
begin
  for s in
    select se.id, se.club_id, c.zona_horaria
      from series se
      join clubes c on c.id = se.club_id
     where c.activo
       and (se.vigente_hasta is null or se.vigente_hasta >= current_date)
     order by se.club_id, se.id
  loop
    select s.id, s.club_id,
           count(*) filter (where m.resultado = 'creado'),
           count(*) filter (where m.resultado = 'ya_existia'),
           count(*) filter (where m.resultado in ('conflicto', 'conflicto_serie')),
           count(*) filter (where m.resultado not in ('creado', 'ya_existia', 'conflicto', 'conflicto_serie'))
      into r
      from fn_materializar_serie(
             s.id,
             (now() at time zone s.zona_horaria)::date,
             (now() at time zone s.zona_horaria)::date + p_dias,
             false) m;

    return next r;
  end loop;
end;
$$;

-- Que no la llame cualquiera: es security definer y toca todos los clubes.
revoke execute on function fn_materializar_todas(integer) from public, anon, authenticated;

-- Todos los dias a las 4 de la maniana (hora del servidor, UTC). Si pg_cron
-- no esta disponible en este entorno, la funcion queda y se puede llamar a
-- mano o desde otro planificador.
do $$
begin
  create extension if not exists pg_cron;
  perform cron.unschedule('clubio_horizonte_series')
    where exists (select 1 from cron.job where jobname = 'clubio_horizonte_series');
  perform cron.schedule('clubio_horizonte_series', '0 4 * * *', 'select fn_materializar_todas()');
  raise notice 'pg_cron: clubio_horizonte_series programado';
exception
  when others then
    raise notice 'pg_cron no disponible (%); fn_materializar_todas queda para llamar a mano', sqlerrm;
end $$;
