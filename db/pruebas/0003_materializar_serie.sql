-- Clubio — pruebas de fn_materializar_serie y fn_precio_vigente
--
-- Corre despues de las migraciones 0001-0003 y de la semilla 0001. Todo
-- dentro de una transaccion que termina en rollback.
--
-- Series de la semilla: el fijo 1f..01 es Cancha 2 los sabados a las 20
-- (tarifa fijo 15000); la clase 1f..02 es Padel 1 los martes a las 18
-- (tarifa clase 16000). Entre el 2026-09-12 y el 2026-10-03 hay cuatro
-- sabados: 12, 19, 26 y 3.

begin;

-- ---------------------------------------------------------------------------
-- ADR 0005 — la tarifa mas especifica gana
-- ---------------------------------------------------------------------------

do $$
declare p numeric;
begin
  insert into tarifas (club_id, deporte_id, cancha_id, tipo_turno, precio, vigente_desde)
  values ('11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000001',
          '1c000000-0000-4000-8000-000000000002', 'fijo', 13000, '2026-09-01');

  p := fn_precio_vigente('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000002', 'fijo', '2026-09-19');
  if p <> 13000 then raise exception 'FALLO 1: fijo en Cancha 2 deberia costar 13000 (tarifa de la cancha), dio %', p; end if;

  p := fn_precio_vigente('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000001', 'fijo', '2026-09-19');
  if p <> 15000 then raise exception 'FALLO 1: fijo en Cancha 1 deberia costar 15000 (tarifa del deporte), dio %', p; end if;

  p := fn_precio_vigente('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000002', 'normal', '2026-09-19');
  if p <> 18000 then raise exception 'FALLO 1: normal en Cancha 2 deberia costar 18000, dio %', p; end if;

  p := fn_precio_vigente('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000002', 'fijo', '2025-06-01');
  if p <> 12000 then raise exception 'FALLO 1: en 2025 deberia regir la tarifa vieja de 12000, dio %', p; end if;

  raise notice 'OK 1 — la tarifa se resuelve por especificidad y por fecha';

  delete from tarifas where cancha_id = '1c000000-0000-4000-8000-000000000002';
end $$;

-- ---------------------------------------------------------------------------
-- Dos series sobre el mismo espacio: la segunda se entera de la primera
-- ---------------------------------------------------------------------------

do $$
declare n integer; ok boolean;
begin
  insert into series (id, club_id, cancha_id, cliente_id, tipo, dia_semana, hora_inicio, duracion_min, vigente_desde)
  values ('1f000000-0000-4000-8000-0000000000aa', '11111111-1111-4111-8111-111111111111',
          '1c000000-0000-4000-8000-000000000004',   -- La grande, que contiene a Cancha 2
          '1e000000-0000-4000-8000-000000000002', 'fijo', 6, '20:00', 60, '2026-09-01');

  select count(*), bool_and(referencia_id = '1f000000-0000-4000-8000-000000000001') into n, ok
    from fn_materializar_serie('1f000000-0000-4000-8000-0000000000aa', '2026-09-12', '2026-10-03', true)
   where resultado = 'conflicto_serie';

  if n <> 4 or not ok then
    raise exception 'FALLO 2: un fijo en La grande deberia chocar los 4 sabados con el fijo de Cancha 2, dio % filas', n;
  end if;
  raise notice 'OK 2 — un fijo nuevo avisa que choca con otro fijo aunque ninguno este materializado';

  delete from series where id = '1f000000-0000-4000-8000-0000000000aa';
end $$;

-- ---------------------------------------------------------------------------
-- Simular no escribe
-- ---------------------------------------------------------------------------

do $$
declare antes integer; despues integer; n integer; p numeric;
begin
  select count(*) into antes from turnos;

  select count(*), min(detalle::numeric) into n, p
    from fn_materializar_serie('1f000000-0000-4000-8000-000000000001', '2026-09-12', '2026-10-03', true)
   where resultado = 'a_crear';

  select count(*) into despues from turnos;

  if n <> 4 or p <> 15000 or antes <> despues then
    raise exception 'FALLO 3: simular deberia dar 4 a_crear a 15000 sin escribir; dio % filas, precio %, turnos % -> %', n, p, antes, despues;
  end if;
  raise notice 'OK 3 — simular muestra los 4 sabados a crear con su precio y no escribe nada';
end $$;

-- ---------------------------------------------------------------------------
-- ADR 0004 — materializar avisa del conflicto y no pisa el turno existente
-- ---------------------------------------------------------------------------

do $$
declare
  creados integer; conflictos integer; n integer;
  c resultado_materializacion;
begin
  -- alguien ya reservo La grande el 19 a las 20: ocupa el espacio de Cancha 2
  insert into turnos (id, club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio)
  values ('1b000000-0000-4000-8000-0000000000bb', '11111111-1111-4111-8111-111111111111',
          '1c000000-0000-4000-8000-000000000004', '1e000000-0000-4000-8000-000000000002',
          'normal', 'confirmado', '2026-09-19 20:00-03', '2026-09-19 21:00-03', 32000);

  create temp table res as
    select * from fn_materializar_serie('1f000000-0000-4000-8000-000000000001', '2026-09-12', '2026-10-03');

  select count(*) filter (where resultado = 'creado'),
         count(*) filter (where resultado = 'conflicto')
    into creados, conflictos from res;

  select * into c from res where fecha = '2026-09-19';

  if creados <> 3 or conflictos <> 1
     or c.resultado <> 'conflicto'
     or c.referencia_id <> '1b000000-0000-4000-8000-0000000000bb'
     or c.detalle not like 'Carla Ibanez en La grande%' then
    raise exception 'FALLO 4: esperaba 3 creados y 1 conflicto el 19 con la reserva de Carla; dio %/% y "%"', creados, conflictos, c.detalle;
  end if;

  select count(*) into n from turnos
   where serie_id = '1f000000-0000-4000-8000-000000000001'
     and tipo = 'fijo' and estado = 'confirmado' and precio = 15000;
  if n <> 3 then
    raise exception 'FALLO 4: deberia haber 3 turnos del fijo, confirmados y a 15000; hay %', n;
  end if;

  select count(*) into n from turno_eventos e
    join turnos t on t.id = e.turno_id
   where t.serie_id = '1f000000-0000-4000-8000-000000000001'
     and e.tipo = 'creado' and e.detalle ->> 'origen' = 'serie';
  if n <> 3 then
    raise exception 'FALLO 4: cada turno generado deberia tener su evento de creacion con origen serie';
  end if;

  raise notice 'OK 4 — genera los sabados libres, avisa del ocupado diciendo de quien es, y no lo pisa';
end $$;

-- Correr de nuevo no duplica nada.
do $$
declare existian integer; creados integer;
begin
  select count(*) filter (where resultado = 'ya_existia'),
         count(*) filter (where resultado = 'creado')
    into existian, creados
    from fn_materializar_serie('1f000000-0000-4000-8000-000000000001', '2026-09-12', '2026-10-03');

  if existian <> 3 or creados <> 0 then
    raise exception 'FALLO 5: la segunda corrida deberia dar 3 ya_existia y 0 creados, dio % y %', existian, creados;
  end if;
  raise notice 'OK 5 — volver a materializar es idempotente';
end $$;

-- Faltar un sabado: el turno cancelado no se regenera.
do $$
declare r text; e text;
begin
  update turnos
     set estado = 'cancelado', cancelado_por = 'cliente', cancelado_en = now()
   where serie_id = '1f000000-0000-4000-8000-000000000001'
     and (inicio at time zone 'America/Argentina/Buenos_Aires')::date = '2026-09-26';

  select resultado into r
    from fn_materializar_serie('1f000000-0000-4000-8000-000000000001', '2026-09-26', '2026-09-26');

  select estado into e
    from fn_disponibilidad('11111111-1111-4111-8111-111111111111', '2026-09-26', '2026-09-26',
                           '1c000000-0000-4000-8000-000000000002')
   where inicio = '2026-09-26 20:00-03';

  if r <> 'ya_existia' or e <> 'libre' then
    raise exception 'FALLO 6: el sabado que el fijo falto deberia quedar ya_existia y libre, dio % y %', r, e;
  end if;
  raise notice 'OK 6 — el sabado que el fijo falto no se regenera y queda libre para vender';
end $$;

-- ---------------------------------------------------------------------------
-- Cierres, horarios y tarifas: lo que no se genera, y por que
-- ---------------------------------------------------------------------------

do $$
declare creados integer; cerrado resultado_materializacion; p numeric;
begin
  insert into cierres (club_id, cancha_id, durante, motivo)
  values ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000005',
          tstzrange('2026-09-22 00:00-03', '2026-09-23 00:00-03', '[)'), 'Arreglo del cesped');

  create temp table res_clase as
    select * from fn_materializar_serie('1f000000-0000-4000-8000-000000000002', '2026-09-15', '2026-09-29');

  select count(*) filter (where resultado = 'creado'), min(detalle::numeric)
    into creados, p from res_clase where resultado = 'creado';
  select * into cerrado from res_clase where fecha = '2026-09-22';

  if creados <> 2 or p <> 16000 or cerrado.resultado <> 'cerrado' or cerrado.detalle <> 'Arreglo del cesped' then
    raise exception 'FALLO 7: la clase deberia generar 2 martes a 16000 y saltear el cerrado con su motivo';
  end if;
  raise notice 'OK 7 — la clase se genera con su tarifa y saltea el dia cerrado diciendo por que';
end $$;

do $$
declare r text;
begin
  -- Padel 2 no abre los domingos
  insert into series (id, club_id, cancha_id, cliente_id, tipo, dia_semana, hora_inicio, duracion_min, vigente_desde)
  values ('1f000000-0000-4000-8000-0000000000cc', '11111111-1111-4111-8111-111111111111',
          '1c000000-0000-4000-8000-000000000006', '1e000000-0000-4000-8000-000000000003',
          'clase', 0, '18:00', 90, '2026-09-01');

  select resultado into r
    from fn_materializar_serie('1f000000-0000-4000-8000-0000000000cc', '2026-09-13', '2026-09-13', true);
  if r <> 'fuera_de_horario' then
    raise exception 'FALLO 8: una serie fuera del horario de apertura deberia avisarlo, dio %', r;
  end if;

  -- Padel no tiene tarifa de fijo en la semilla: solo normal y clase
  insert into series (id, club_id, cancha_id, cliente_id, tipo, dia_semana, hora_inicio, duracion_min, vigente_desde)
  values ('1f000000-0000-4000-8000-0000000000dd', '11111111-1111-4111-8111-111111111111',
          '1c000000-0000-4000-8000-000000000006', '1e000000-0000-4000-8000-000000000003',
          'fijo', 6, '16:00', 90, '2026-09-01');

  select resultado into r
    from fn_materializar_serie('1f000000-0000-4000-8000-0000000000dd', '2026-09-12', '2026-09-12', true);
  if r <> 'sin_tarifa' then
    raise exception 'FALLO 8: una serie sin tarifa vigente no deberia generar turnos, dio %', r;
  end if;

  raise notice 'OK 8 — fuera de horario y sin tarifa se avisan en vez de generar un turno malo';
end $$;

rollback;
