-- Clubio — pruebas de fn_ingresos y fn_ingresos_mensuales
--
-- Corre despues de las migraciones 0001-0006 y las semillas. Todo dentro de
-- una transaccion que termina en rollback. Usa un club nuevo y vacio para
-- que los numeros no dependan de lo que haya en El Molino, y una fecha de
-- corte fija (2026-08-20) para que no dependan del dia.

begin;

insert into clubes (id, nombre, slug) values
  ('33333333-3333-4333-8333-333333333333', 'Club Prueba Ingresos', 'prueba-ingresos');
insert into espacios (id, club_id, nombre) values
  ('3a000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-333333333333', 'Piso 1');
insert into deportes (id, club_id, nombre, duracion_min) values
  ('3d000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-333333333333', 'Futbol', 60),
  ('3d000000-0000-4000-8000-000000000002', '33333333-3333-4333-8333-333333333333', 'Padel', 90);
insert into canchas (id, club_id, deporte_id, nombre) values
  ('3c000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-333333333333', '3d000000-0000-4000-8000-000000000001', 'F'),
  ('3c000000-0000-4000-8000-000000000002', '33333333-3333-4333-8333-333333333333', '3d000000-0000-4000-8000-000000000002', 'P');
insert into cancha_espacios (club_id, cancha_id, espacio_id) values
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000001', '3a000000-0000-4000-8000-000000000001');
insert into espacios (id, club_id, nombre) values
  ('3a000000-0000-4000-8000-000000000002', '33333333-3333-4333-8333-333333333333', 'Piso 2');
insert into cancha_espacios (club_id, cancha_id, espacio_id) values
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000002', '3a000000-0000-4000-8000-000000000002');
insert into clientes (id, club_id, nombre, telefono) values
  ('3e000000-0000-4000-8000-000000000001', '33333333-3333-4333-8333-333333333333', 'Uno', '+5493425550301');

-- Julio: 2 futbol normal (10000 c/u). Agosto hasta el 20: 1 futbol fijo
-- (8000), 1 padel clase (9000), 1 padel normal (7000). Agosto despues del
-- 20: 1 futbol normal (10000) que no entra en el corte. Uno cancelado y uno
-- futuro que no cuentan nunca.
insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio, cancelado_por, cancelado_en) values
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000001', '3e000000-0000-4000-8000-000000000001', 'normal', 'confirmado', '2026-07-05 20:00-03', '2026-07-05 21:00-03', 10000, null, null),
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000001', '3e000000-0000-4000-8000-000000000001', 'normal', 'confirmado', '2026-07-12 20:00-03', '2026-07-12 21:00-03', 10000, null, null),
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000001', '3e000000-0000-4000-8000-000000000001', 'fijo',   'confirmado', '2026-08-01 20:00-03', '2026-08-01 21:00-03',  8000, null, null),
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000002', '3e000000-0000-4000-8000-000000000001', 'clase',  'confirmado', '2026-08-04 18:00-03', '2026-08-04 19:30-03',  9000, null, null),
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000002', '3e000000-0000-4000-8000-000000000001', 'normal', 'confirmado', '2026-08-19 18:00-03', '2026-08-19 19:30-03',  7000, null, null),
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000001', '3e000000-0000-4000-8000-000000000001', 'normal', 'confirmado', '2026-08-25 20:00-03', '2026-08-25 21:00-03', 10000, null, null),
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000001', '3e000000-0000-4000-8000-000000000001', 'normal', 'cancelado', '2026-08-10 20:00-03', '2026-08-10 21:00-03', 10000, 'cliente', '2026-08-09 10:00-03'),
  ('33333333-3333-4333-8333-333333333333', '3c000000-0000-4000-8000-000000000001', '3e000000-0000-4000-8000-000000000001', 'normal', 'confirmado', '2027-03-01 20:00-03', '2027-03-01 21:00-03', 10000, null, null);

do $$
declare hist numeric; mes numeric; fijos numeric; clases numeric; padel_mes numeric;
begin
  select sum(total) filter (where periodo = 'historico'),
         sum(total) filter (where periodo = 'mes'),
         sum(total) filter (where periodo = 'historico' and tipo = 'fijo'),
         sum(total) filter (where periodo = 'historico' and tipo = 'clase'),
         sum(total) filter (where periodo = 'mes' and deporte = 'Padel')
    into hist, mes, fijos, clases, padel_mes
    from fn_ingresos('33333333-3333-4333-8333-333333333333', '2026-08-20');

  if hist <> 44000 then
    raise exception 'FALLO 1: historico hasta el 20/8 deberia ser 44000 (sin el del 25, el cancelado ni el futuro), dio %', hist;
  end if;
  if mes <> 24000 then
    raise exception 'FALLO 1: el mes hasta el 20/8 deberia ser 24000, dio %', mes;
  end if;
  if fijos <> 8000 or clases <> 9000 then
    raise exception 'FALLO 1: fijos y clases deberian ser 8000 y 9000, dieron % y %', fijos, clases;
  end if;
  if padel_mes <> 16000 then
    raise exception 'FALLO 1: padel del mes deberia ser 16000, dio %', padel_mes;
  end if;
  raise notice 'OK 1 — historico, mes corriente, por deporte y por tipo cierran con el corte';
end $$;

do $$
declare julio numeric; agosto numeric;
begin
  select sum(total) filter (where mes = '2026-07-01'),
         sum(total) filter (where mes = '2026-08-01')
    into julio, agosto
    from fn_ingresos_mensuales('33333333-3333-4333-8333-333333333333', 24);

  if julio <> 20000 or agosto <> 34000 then
    raise exception 'FALLO 2: julio y agosto deberian ser 20000 y 34000, dieron % y %', julio, agosto;
  end if;
  raise notice 'OK 2 — la serie mensual cierra mes a mes';
end $$;

-- Un club sin turnos jugados devuelve vacio, no error.
do $$
declare n integer;
begin
  select count(*) into n from fn_ingresos('22222222-2222-4222-8222-222222222222', '2026-01-01');
  if n <> 0 then
    raise exception 'FALLO 3: un club sin ingresos hasta esa fecha deberia dar vacio, dio % filas', n;
  end if;
  raise notice 'OK 3 — sin ingresos, vacio';
end $$;

rollback;
