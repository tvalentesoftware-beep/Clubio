-- Clubio — pruebas de las vistas de clientes
--
-- Corre despues de las migraciones 0001-0005 y las semillas. Todo dentro de
-- una transaccion que termina en rollback. Los turnos de prueba se insertan
-- en fechas pasadas fijas para que el resultado no dependa del dia.

begin;

-- Un cliente nuevo con historia: dos de futbol jugados, uno de padel jugado,
-- uno futuro, uno que cancelo el y uno que cancelo el club.
insert into clientes (id, club_id, nombre, telefono)
values ('1e000000-0000-4000-8000-0000000000ee', '11111111-1111-4111-8111-111111111111', 'Cliente Historia', '+5493425559999');

insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio, cancelado_por, cancelado_en) values
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000001', '1e000000-0000-4000-8000-0000000000ee',
   'normal', 'confirmado', '2026-08-03 20:00-03', '2026-08-03 21:00-03', 18000, null, null),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000001', '1e000000-0000-4000-8000-0000000000ee',
   'normal', 'confirmado', '2026-08-10 20:00-03', '2026-08-10 21:00-03', 18000, null, null),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000005', '1e000000-0000-4000-8000-0000000000ee',
   'normal', 'confirmado', '2026-08-12 19:00-03', '2026-08-12 20:30-03', 14000, null, null),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000001', '1e000000-0000-4000-8000-0000000000ee',
   'normal', 'confirmado', '2027-01-04 20:00-03', '2027-01-04 21:00-03', 18000, null, null),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000001', '1e000000-0000-4000-8000-0000000000ee',
   'normal', 'cancelado', '2026-08-17 20:00-03', '2026-08-17 21:00-03', 18000, 'cliente', '2026-08-16 10:00-03'),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000001', '1e000000-0000-4000-8000-0000000000ee',
   'normal', 'cancelado', '2026-08-24 20:00-03', '2026-08-24 21:00-03', 18000, 'club', '2026-08-23 10:00-03');

do $$
declare r vw_clientes_resumen;
begin
  select * into r from vw_clientes_resumen where id = '1e000000-0000-4000-8000-0000000000ee';

  if r.turnos_jugados <> 3 then
    raise exception 'FALLO 1: jugados deberia ser 3 (el futuro y los cancelados no cuentan), dio %', r.turnos_jugados;
  end if;
  if r.total_aportado <> 50000 then
    raise exception 'FALLO 1: aportado deberia ser 50000, dio %', r.total_aportado;
  end if;
  if r.cancelados <> 1 then
    raise exception 'FALLO 1: cancelados por el cliente deberia ser 1 (el del club no cuenta), dio %', r.cancelados;
  end if;
  if r.turnos_futuros <> 1 then
    raise exception 'FALLO 1: futuros deberia ser 1, dio %', r.turnos_futuros;
  end if;
  if not (r.deportes @> array['Futbol 5', 'Padel'] and array_length(r.deportes, 1) = 2) then
    raise exception 'FALLO 1: deportes deberia ser Futbol 5 y Padel, dio %', r.deportes;
  end if;
  raise notice 'OK 1 — jugados, aportado, cancelados y deportes salen de los turnos con la definicion de la vista';
end $$;

do $$
declare n integer; f numeric; p numeric;
begin
  select count(*),
         min(total_aportado) filter (where deporte = 'Futbol 5'),
         min(total_aportado) filter (where deporte = 'Padel')
    into n, f, p
    from vw_clientes_por_deporte where cliente_id = '1e000000-0000-4000-8000-0000000000ee';
  if n <> 2 or f <> 36000 or p <> 14000 then
    raise exception 'FALLO 2: por deporte deberia dar futbol 36000 y padel 14000, dio % filas, %/%', n, f, p;
  end if;
  raise notice 'OK 2 — el desglose por deporte cierra con el total';
end $$;

-- Un cliente sin turnos aparece igual, en cero: la tabla de clientes es de
-- clientes, no de clientes con turnos.
do $$
declare r vw_clientes_resumen;
begin
  select * into r from vw_clientes_resumen where id = '1e000000-0000-4000-8000-000000000005';  -- Bruno, lista negra
  if r.id is null or r.turnos_jugados <> 0 or r.total_aportado <> 0 or not r.en_lista_negra then
    raise exception 'FALLO 3: un cliente sin turnos deberia salir en cero y con su lista negra';
  end if;
  raise notice 'OK 3 — un cliente sin turnos aparece en cero, con su marca de lista negra';
end $$;

-- RLS atraviesa la vista: como usuario de El Molino no se ve a Belgrano.
select set_config('request.jwt.claims',
                  format('{"sub":"%s","role":"authenticated"}', (select id from auth.users where email = 'tvalente.software@gmail.com')),
                  true);
set local role authenticated;

do $$
declare n integer;
begin
  select count(*) into n from vw_clientes_resumen where club_id = '22222222-2222-4222-8222-222222222222';
  if n <> 0 then
    raise exception 'FALLO 4: la vista dejo ver clientes del otro club (security_invoker no esta funcionando)';
  end if;
  select count(*) into n from vw_clientes_resumen;
  if n < 5 then
    raise exception 'FALLO 4: el usuario deberia ver los clientes de El Molino, ve %', n;
  end if;
  raise notice 'OK 4 — la vista respeta RLS: corre con los permisos de quien consulta';
end $$;

reset role;
rollback;
