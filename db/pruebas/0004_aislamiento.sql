-- Clubio — pruebas de aislamiento entre clubes (RLS)
--
-- Corre despues de las migraciones, la semilla 0001 y la semilla 0002 (que
-- necesita un usuario real en auth.users). Todo dentro de una transaccion
-- que termina en rollback.
--
-- Las otras pruebas corren como duenio de la base, que ignora RLS. Esta es
-- la unica que se pone en el lugar de un usuario: asume el rol authenticated
-- con el JWT del usuario de El Molino, y comprueba que Padel Belgrano no
-- existe para el. Despues hace lo mismo como anonimo, que no debe ver nada.

begin;

-- El id del usuario se lee antes de soltar los privilegios.
select set_config('prueba.uid', u.id::text, true)
  from auth.users u
 where u.email = 'tvalente.software@gmail.com';

select set_config('request.jwt.claims',
                  format('{"sub":"%s","role":"authenticated"}', current_setting('prueba.uid')),
                  true);

set local role authenticated;

do $$
declare n integer;
begin
  if current_setting('prueba.uid', true) is null or current_setting('prueba.uid') = '' then
    raise exception 'FALLO 0: falta el usuario en auth.users; correr la semilla 0002 despues de crearlo';
  end if;

  select count(*) into n from clubes;
  if n <> 1 then
    raise exception 'FALLO 1: el usuario deberia ver exactamente 1 club, ve %', n;
  end if;

  select count(*) into n from clubes where id = '22222222-2222-4222-8222-222222222222';
  if n <> 0 then
    raise exception 'FALLO 1: Padel Belgrano no deberia existir para este usuario';
  end if;
  raise notice 'OK 1 — el usuario ve su club y no ve el otro';

  select count(*) into n from canchas;
  if n <> 6 then
    raise exception 'FALLO 2: deberia ver las 6 canchas de El Molino, ve %', n;
  end if;

  select count(*) into n from turnos where club_id = '22222222-2222-4222-8222-222222222222';
  if n <> 0 then
    raise exception 'FALLO 2: se filtraron turnos de Belgrano';
  end if;

  select count(*) into n from clientes where telefono = '+5493425550101';
  if n <> 1 then
    raise exception 'FALLO 2: el mismo telefono existe en los dos clubes, pero solo uno deberia verse; ve %', n;
  end if;
  raise notice 'OK 2 — canchas, turnos y clientes filtran por club';

  select count(*) into n
    from fn_disponibilidad('22222222-2222-4222-8222-222222222222', '2026-09-12', '2026-09-12');
  if n <> 0 then
    raise exception 'FALLO 3: fn_disponibilidad del otro club deberia devolver nada, devolvio % slots', n;
  end if;

  select count(*) into n
    from fn_disponibilidad('11111111-1111-4111-8111-111111111111', '2026-09-12', '2026-09-12');
  if n <> 42 then
    raise exception 'FALLO 3: fn_disponibilidad del propio club deberia dar 42 slots, dio %', n;
  end if;
  raise notice 'OK 3 — las funciones respetan RLS: corren con los permisos del usuario';
end $$;

-- Escribir en el club ajeno tiene que fallar, aunque se conozcan los ids.
do $$
begin
  begin
    insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio)
    values ('22222222-2222-4222-8222-222222222222',
            '2c000000-0000-4000-8000-000000000002',
            '2e000000-0000-4000-8000-000000000001',
            'normal', 'confirmado',
            '2026-09-13 10:00-03', '2026-09-13 11:30-03', 16000);
    raise exception 'FALLO 4: se pudo escribir un turno en un club ajeno';
  exception
    when insufficient_privilege then
      raise notice 'OK 4 — escribir en el club ajeno falla aunque se conozcan los ids';
  end;
end $$;

-- Y escribir en el propio funciona, con el usuario como autor.
do $$
declare autor uuid;
begin
  insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio, creado_por)
  values ('11111111-1111-4111-8111-111111111111',
          '1c000000-0000-4000-8000-000000000006',
          '1e000000-0000-4000-8000-000000000004',
          'normal', 'confirmado',
          '2026-09-18 19:00-03', '2026-09-18 20:30-03', 14000, auth.uid())
  returning creado_por into autor;

  if autor is null or autor::text <> current_setting('prueba.uid') then
    raise exception 'FALLO 5: el turno deberia quedar firmado por el usuario';
  end if;
  raise notice 'OK 5 — escribir en el propio club funciona y queda firmado';
end $$;

-- Un anonimo no ve nada de nadie.
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;

do $$
declare n integer;
begin
  select count(*) into n from clubes;
  if n <> 0 then
    raise exception 'FALLO 6: un anonimo ve % clubes', n;
  end if;
  select count(*) into n from turnos;
  if n <> 0 then
    raise exception 'FALLO 6: un anonimo ve % turnos', n;
  end if;
  raise notice 'OK 6 — sin sesion no se ve nada';
end $$;

reset role;
rollback;
