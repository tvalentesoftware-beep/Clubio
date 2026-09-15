-- Clubio — pruebas de fn_disponibilidad
--
-- Corre despues de las migraciones 0001 y 0002 y de la semilla 0001. Todo
-- dentro de una transaccion que termina en rollback.
--
-- Fechas de referencia en la semilla: el sabado 2026-09-12 tiene la reserva
-- de "La grande" a las 21; el fijo de Cancha 2 es los sabados a las 20; la
-- clase de Padel 1 es los martes a las 18; el jueves 2026-09-10 hay un turno
-- cancelado en Cancha 1 a las 20.

begin;

-- Un atajo para leer un slot puntual de El Molino.
create function pg_temp.slot(p_cancha uuid, p_inicio timestamptz)
returns slot_disponibilidad
language sql stable
as $$
  select d
    from fn_disponibilidad(
           '11111111-1111-4111-8111-111111111111',
           (p_inicio at time zone 'America/Argentina/Buenos_Aires')::date,
           (p_inicio at time zone 'America/Argentina/Buenos_Aires')::date,
           p_cancha) d
   where d.inicio = p_inicio;
$$;

-- ---------------------------------------------------------------------------
-- ADR 0003 — la ocupacion cruza canchas que comparten espacio
-- ---------------------------------------------------------------------------

do $$
declare r slot_disponibilidad;
begin
  r := pg_temp.slot('1c000000-0000-4000-8000-000000000001', '2026-09-12 21:00-03');
  if r.estado is distinct from 'ocupado'
     or r.turno_cancha_id is distinct from '1c000000-0000-4000-8000-000000000004' then
    raise exception 'FALLO 1: Cancha 1 a las 21 deberia estar ocupada por La grande, dio % / %', r.estado, r.turno_cancha_id;
  end if;
  raise notice 'OK 1 — la reserva de La grande deja Cancha 1 ocupada, y la funcion dice por quien';

  r := pg_temp.slot('1c000000-0000-4000-8000-000000000004', '2026-09-12 21:00-03');
  if r.estado is distinct from 'ocupado'
     or r.turno_id is distinct from '1b000000-0000-4000-8000-000000000001' then
    raise exception 'FALLO 2: La grande a las 21 deberia mostrar su propio turno';
  end if;
  raise notice 'OK 2 — La grande a las 21 muestra su propio turno';
end $$;

-- ---------------------------------------------------------------------------
-- ADR 0004 — la serie bloquea aunque no este materializada
-- ---------------------------------------------------------------------------

do $$
declare r slot_disponibilidad;
begin
  r := pg_temp.slot('1c000000-0000-4000-8000-000000000002', '2026-09-12 20:00-03');
  if r.estado is distinct from 'serie'
     or r.serie_id is distinct from '1f000000-0000-4000-8000-000000000001' then
    raise exception 'FALLO 3: Cancha 2 el sabado a las 20 deberia estar tomada por el fijo, dio %', r.estado;
  end if;
  raise notice 'OK 3 — el fijo de los sabados bloquea sin estar materializado';

  -- y como Cancha 2 es parte de La grande, el fijo tambien la bloquea
  r := pg_temp.slot('1c000000-0000-4000-8000-000000000004', '2026-09-12 20:00-03');
  if r.estado is distinct from 'serie' then
    raise exception 'FALLO 4: La grande a las 20 deberia estar bloqueada por el fijo de Cancha 2, dio %', r.estado;
  end if;
  raise notice 'OK 4 — el fijo de Cancha 2 tambien bloquea La grande';

  r := pg_temp.slot('1c000000-0000-4000-8000-000000000002', '2026-09-12 22:00-03');
  if r.estado is distinct from 'libre' then
    raise exception 'FALLO 5: Cancha 2 a las 22 deberia estar libre, dio %', r.estado;
  end if;
  raise notice 'OK 5 — el slot siguiente al fijo esta libre';
end $$;

-- Una clase a las 18 con slots de 17:30 y 19:00 bloquea los dos.
do $$
declare a slot_disponibilidad; b slot_disponibilidad;
begin
  a := pg_temp.slot('1c000000-0000-4000-8000-000000000005', '2026-09-15 17:30-03');
  b := pg_temp.slot('1c000000-0000-4000-8000-000000000005', '2026-09-15 19:00-03');
  if a.estado is distinct from 'serie' or b.estado is distinct from 'serie' then
    raise exception 'FALLO 6: la clase de las 18 deberia tomar 17:30 y 19:00, dio % y %', a.estado, b.estado;
  end if;
  raise notice 'OK 6 — una serie desalineada con la grilla bloquea los dos slots que toca';
end $$;

-- Si el turno de la serie ya existe para ese dia -aunque este cancelado-
-- manda el turno, no la serie: faltar un sabado libera el horario.
do $$
declare r slot_disponibilidad;
begin
  insert into turnos (club_id, cancha_id, cliente_id, serie_id, tipo, estado,
                      inicio, fin, precio, cancelado_por, cancelado_en)
  values ('11111111-1111-4111-8111-111111111111',
          '1c000000-0000-4000-8000-000000000002',
          '1e000000-0000-4000-8000-000000000001',
          '1f000000-0000-4000-8000-000000000001',
          'fijo', 'cancelado',
          '2026-09-12 20:00-03', '2026-09-12 21:00-03', 15000,
          'cliente', now());

  r := pg_temp.slot('1c000000-0000-4000-8000-000000000002', '2026-09-12 20:00-03');
  if r.estado is distinct from 'libre' then
    raise exception 'FALLO 7: con el turno del fijo cancelado, el slot deberia estar libre, dio %', r.estado;
  end if;
  raise notice 'OK 7 — el fijo que falta un sabado libera ese sabado';
end $$;

-- ---------------------------------------------------------------------------
-- ADR 0007 — un turno cancelado no ocupa
-- ---------------------------------------------------------------------------

do $$
declare r slot_disponibilidad;
begin
  r := pg_temp.slot('1c000000-0000-4000-8000-000000000001', '2026-09-10 20:00-03');
  if r.estado is distinct from 'libre' then
    raise exception 'FALLO 8: el turno cancelado del jueves deberia dejar el slot libre, dio %', r.estado;
  end if;
  raise notice 'OK 8 — el turno cancelado del jueves no ocupa';
end $$;

-- ---------------------------------------------------------------------------
-- ADR 0002 — la grilla sale de las franjas, con el paso del deporte
-- ---------------------------------------------------------------------------

do $$
declare n integer; primera time;
begin
  -- Padel 2 no abre los domingos
  select count(*) into n
    from fn_disponibilidad('11111111-1111-4111-8111-111111111111', '2026-09-13', '2026-09-13',
                           '1c000000-0000-4000-8000-000000000006');
  if n <> 0 then
    raise exception 'FALLO 9: Padel 2 no abre los domingos y devolvio % slots', n;
  end if;

  -- Padel 1 los lunes arranca a las 15, no a las 14:30
  select min(inicio at time zone 'America/Argentina/Buenos_Aires')::time into primera
    from fn_disponibilidad('11111111-1111-4111-8111-111111111111', '2026-09-14', '2026-09-14',
                           '1c000000-0000-4000-8000-000000000005');
  if primera <> '15:00' then
    raise exception 'FALLO 9: Padel 1 el lunes deberia arrancar a las 15, arranco a las %', primera;
  end if;

  -- Un sabado completo de El Molino: 4 canchas de futbol x 8 slots + 5 + 5 de padel
  select count(*) into n
    from fn_disponibilidad('11111111-1111-4111-8111-111111111111', '2026-09-12', '2026-09-12');
  if n <> 42 then
    raise exception 'FALLO 9: un sabado de El Molino deberia tener 42 slots, tiene %', n;
  end if;

  raise notice 'OK 9 — los slots salen de las franjas de cada cancha, con el paso de su deporte';
end $$;

-- ---------------------------------------------------------------------------
-- Cierres, y su precedencia frente a lo demas
-- ---------------------------------------------------------------------------

do $$
declare r slot_disponibilidad;
begin
  insert into cierres (club_id, cancha_id, durante, motivo)
  values ('11111111-1111-4111-8111-111111111111', null,
          tstzrange('2026-09-12 15:00-03', '2026-09-12 18:00-03', '[)'),
          'Lluvia');

  r := pg_temp.slot('1c000000-0000-4000-8000-000000000003', '2026-09-12 15:00-03');
  if r.estado is distinct from 'cerrado' then
    raise exception 'FALLO 10: con el club cerrado, Cancha 3 a las 15 deberia dar cerrado, dio %', r.estado;
  end if;

  r := pg_temp.slot('1c000000-0000-4000-8000-000000000005', '2026-09-12 20:30-03');
  if r.estado is distinct from 'libre' then
    raise exception 'FALLO 10: el cierre de la tarde no deberia afectar a la noche, dio %', r.estado;
  end if;

  raise notice 'OK 10 — un cierre del club cierra todas las canchas, solo en su rango';
end $$;

-- ---------------------------------------------------------------------------
-- ADR 0001 — cada club ve solo sus canchas
-- ---------------------------------------------------------------------------

do $$
declare n integer;
begin
  select count(*) into n
    from fn_disponibilidad('22222222-2222-4222-8222-222222222222', '2026-09-12', '2026-09-12') d
   where d.cancha_id in (select id from canchas where club_id = '11111111-1111-4111-8111-111111111111');
  if n <> 0 then
    raise exception 'FALLO 11: la disponibilidad de Belgrano trajo canchas de El Molino';
  end if;

  -- y el turno de Belgrano a las 21 no aparece como ocupacion en El Molino
  select count(*) into n
    from fn_disponibilidad('11111111-1111-4111-8111-111111111111', '2026-09-12', '2026-09-12') d
   where d.turno_id = '2f000000-0000-4000-8000-000000000001';
  if n <> 0 then
    raise exception 'FALLO 11: un turno de Belgrano aparecio ocupando El Molino';
  end if;

  raise notice 'OK 11 — la disponibilidad de un club no mezcla nada del otro';
end $$;

rollback;
