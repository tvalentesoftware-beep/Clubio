-- Clubio — pruebas de fn_materializar_todas
--
-- Corre despues de las migraciones 0001-0007 y las semillas. Todo dentro de
-- una transaccion que termina en rollback.

begin;

do $$
declare v_filas integer; v_creados bigint; v_conflictos bigint; v_existian bigint;
begin
  create temp table r1 as select * from fn_materializar_todas(28);

  select count(*), sum(creados) into v_filas, v_creados from r1;
  if v_filas < 2 then
    raise exception 'FALLO 1: deberia haber recorrido al menos las 2 series de la semilla, recorrio %', v_filas;
  end if;
  raise notice 'OK 1 — recorre las series vigentes de todos los clubes (% series, % turnos creados)', v_filas, v_creados;

  -- La segunda corrida no crea nada nuevo: todo ya existia o sigue en conflicto.
  select sum(creados), sum(existian), sum(conflictos)
    into v_creados, v_existian, v_conflictos
    from fn_materializar_todas(28);
  if v_creados <> 0 then
    raise exception 'FALLO 2: la segunda corrida creo % turnos; deberia ser idempotente', v_creados;
  end if;
  raise notice 'OK 2 — correrla de nuevo es idempotente (% ya existian, % en conflicto)', v_existian, v_conflictos;
end $$;

-- Una serie terminada no se toca.
do $$
declare n integer;
begin
  update series set vigente_hasta = current_date - 1 where id = '1f000000-0000-4000-8000-000000000002';
  select count(*) into n from fn_materializar_todas(28) where serie_id = '1f000000-0000-4000-8000-000000000002';
  if n <> 0 then
    raise exception 'FALLO 3: una serie con vigente_hasta pasado no deberia recorrerse';
  end if;
  raise notice 'OK 3 — las series terminadas quedan afuera';
end $$;

-- Un usuario comun no puede llamarla.
select set_config('request.jwt.claims',
                  format('{"sub":"%s","role":"authenticated"}', (select id from auth.users where email = 'tvalente.software@gmail.com')),
                  true);
set local role authenticated;

do $$
begin
  begin
    perform fn_materializar_todas(7);
    raise exception 'FALLO 4: un usuario autenticado pudo ejecutar fn_materializar_todas';
  exception
    when insufficient_privilege then
      raise notice 'OK 4 — solo el planificador puede correrla';
  end;
end $$;

reset role;
rollback;
