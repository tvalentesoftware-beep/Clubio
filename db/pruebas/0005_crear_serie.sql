-- Clubio — pruebas de fn_crear_serie
--
-- Corre despues de las migraciones 0001-0004 y de la semilla 0001. Todo
-- dentro de una transaccion que termina en rollback.

begin;

-- ---------------------------------------------------------------------------
-- Sin problemas: un solo paso, la serie queda y los turnos tambien
-- ---------------------------------------------------------------------------

do $$
declare creados integer; n integer;
begin
  -- Cancha 3, viernes 21:00, cuatro viernes: 18/9, 25/9, 2/10, 9/10
  select count(*) filter (where resultado = 'creado') into creados
    from fn_crear_serie('11111111-1111-4111-8111-111111111111',
                        '1c000000-0000-4000-8000-000000000003',
                        '1e000000-0000-4000-8000-000000000003',
                        'fijo', 5, '21:00', 60, '2026-09-18', '2026-10-09');

  select count(*) into n from series
   where cancha_id = '1c000000-0000-4000-8000-000000000003' and dia_semana = 5;

  if creados <> 4 or n <> 1 then
    raise exception 'FALLO 1: sin conflictos deberia crear la serie y 4 turnos; dio % turnos y % series', creados, n;
  end if;
  raise notice 'OK 1 — sin conflictos, crea la serie y genera los turnos en un solo paso';
end $$;

-- ---------------------------------------------------------------------------
-- Con problemas y sin confirmar: avisa y no deja nada
-- ---------------------------------------------------------------------------

do $$
declare a_crear integer; conflictos integer; n integer; det text;
begin
  -- Un fijo en La grande los sabados a las 20 choca con el fijo de Cancha 2
  create temp table sim as
    select * from fn_crear_serie('11111111-1111-4111-8111-111111111111',
                                 '1c000000-0000-4000-8000-000000000004',
                                 '1e000000-0000-4000-8000-000000000002',
                                 'fijo', 6, '20:00', 60, '2026-09-12', '2026-10-03');

  select count(*) filter (where resultado = 'a_crear'),
         count(*) filter (where resultado = 'conflicto_serie'),
         min(detalle) filter (where resultado = 'conflicto_serie')
    into a_crear, conflictos, det from sim;

  select count(*) into n from series where cancha_id = '1c000000-0000-4000-8000-000000000004';

  if conflictos <> 4 or n <> 0 then
    raise exception 'FALLO 2: esperaba 4 conflictos y ninguna serie creada; dio % conflictos y % series', conflictos, n;
  end if;
  if det not like 'Fijo de Ramiro Ferrer en Cancha 2%' then
    raise exception 'FALLO 2: el aviso deberia decir con quien choca, dijo "%"', det;
  end if;
  raise notice 'OK 2 — con conflictos y sin confirmar, devuelve el aviso y no escribe nada';
end $$;

-- ---------------------------------------------------------------------------
-- Con problemas y confirmando: crea, saltea los dias con problema, y lista
-- ---------------------------------------------------------------------------

do $$
declare creados integer; saltados integer; n integer;
begin
  -- Padel 2, martes 17:30 (90 min); el 22/9 hay un cierre de Padel 2
  insert into cierres (club_id, cancha_id, durante, motivo)
  values ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000006',
          tstzrange('2026-09-22 00:00-03', '2026-09-23 00:00-03', '[)'), 'Pintura');

  create temp table res as
    select * from fn_crear_serie('11111111-1111-4111-8111-111111111111',
                                 '1c000000-0000-4000-8000-000000000006',
                                 '1e000000-0000-4000-8000-000000000004',
                                 'clase', 2, '17:30', 90, '2026-09-15', '2026-09-29', true);

  select count(*) filter (where resultado = 'creado'),
         count(*) filter (where resultado = 'cerrado')
    into creados, saltados from res;

  select count(*) into n from turnos t
    join series s on s.id = t.serie_id
   where s.cancha_id = '1c000000-0000-4000-8000-000000000006' and s.tipo = 'clase';

  if creados <> 2 or saltados <> 1 or n <> 2 then
    raise exception 'FALLO 3: confirmando deberia crear 2 y saltear 1; dio %/% y % turnos', creados, saltados, n;
  end if;
  raise notice 'OK 3 — confirmando, genera lo que puede y lista lo que salteo';
end $$;

rollback;
