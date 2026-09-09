-- Clubio — pruebas de las reglas del modelo
--
-- Corre despues de la migracion 0001 y de la semilla 0001. Todo pasa dentro
-- de una transaccion que termina en rollback: no deja nada.
--
-- Cada bloque comprueba una promesa concreta de un ADR. Si el esquema esta
-- bien, la salida es una lista de OK; si algo se rompio, el script corta con
-- un FALLO que dice cual.
--
--   psql "$DATABASE_URL" -f db/pruebas/0001_reglas_del_modelo.sql

begin;

-- ---------------------------------------------------------------------------
-- ADR 0003 — un turno ocupa todos los espacios de su cancha
-- ---------------------------------------------------------------------------

do $$
declare n integer;
begin
  select count(*) into n
    from ocupaciones
   where turno_id = '1b000000-0000-4000-8000-000000000001';

  if n <> 3 then
    raise exception 'FALLO 1: "La grande" dejo % ocupaciones, se esperaban 3', n;
  end if;
  raise notice 'OK 1 — un turno de la cancha grande ocupa los tres pastos';
end $$;

-- ---------------------------------------------------------------------------
-- ADR 0003 — la doble venta del mismo piso es imposible, no improbable
-- ---------------------------------------------------------------------------

do $$
begin
  begin
    insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio)
    values ('11111111-1111-4111-8111-111111111111',
            '1c000000-0000-4000-8000-000000000001',   -- Cancha 1 de futbol 5
            '1e000000-0000-4000-8000-000000000003',
            'normal', 'confirmado',
            '2026-09-12 21:00-03', '2026-09-12 22:00-03', 18000);

    raise exception 'FALLO 2: se pudo vender futbol 5 sobre un turno de futbol 8';
  exception
    when exclusion_violation then
      raise notice 'OK 2 — la base rechaza futbol 5 encima de la cancha grande';
  end;
end $$;

-- Y en el otro sentido, que es el que el sistema anterior no cubria.
do $$
begin
  begin
    insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio)
    values ('11111111-1111-4111-8111-111111111111',
            '1c000000-0000-4000-8000-000000000004',   -- la grande
            '1e000000-0000-4000-8000-000000000003',
            'normal', 'confirmado',
            '2026-09-09 19:30-03', '2026-09-09 20:30-03', 32000);
    raise notice 'OK 3 — la grande entra cuando los tres pastos estan libres';
  exception
    when exclusion_violation then
      raise exception 'FALLO 3: se rechazo un turno que no chocaba con nada';
  end;
end $$;

-- ---------------------------------------------------------------------------
-- ADR 0007 — cancelar libera el horario pero no borra el turno
-- ---------------------------------------------------------------------------

do $$
declare n integer;
begin
  -- El turno cancelado que trae la semilla no debe estar ocupando nada.
  select count(*) into n
    from ocupaciones
   where turno_id = '1b000000-0000-4000-8000-000000000003';
  if n <> 0 then
    raise exception 'FALLO 4: un turno cancelado sigue ocupando el espacio';
  end if;

  -- Y sin embargo el turno existe, con constancia de quien lo cancelo.
  perform 1 from turnos
   where id = '1b000000-0000-4000-8000-000000000003'
     and estado = 'cancelado'
     and cancelado_por = 'cliente';
  if not found then
    raise exception 'FALLO 4: se perdio el registro del turno cancelado';
  end if;

  raise notice 'OK 4 — el turno cancelado libera el horario y conserva su historia';
end $$;

-- Cancelar la reserva de la cancha grande tiene que liberar los tres pastos.
do $$
declare n integer;
begin
  update turnos
     set estado = 'cancelado', cancelado_por = 'club', cancelado_en = now()
   where id = '1b000000-0000-4000-8000-000000000001';

  select count(*) into n
    from ocupaciones
   where turno_id = '1b000000-0000-4000-8000-000000000001';
  if n <> 0 then
    raise exception 'FALLO 5: cancelar la grande dejo % ocupaciones vivas', n;
  end if;

  insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio)
  values ('11111111-1111-4111-8111-111111111111',
          '1c000000-0000-4000-8000-000000000001',
          '1e000000-0000-4000-8000-000000000003',
          'normal', 'confirmado',
          '2026-09-12 21:00-03', '2026-09-12 22:00-03', 18000);

  raise notice 'OK 5 — al cancelar la grande, el futbol 5 vuelve a poder venderse';
end $$;

-- ---------------------------------------------------------------------------
-- ADR 0001 — las claves compuestas impiden cruzar datos de dos clubes
-- ---------------------------------------------------------------------------

do $$
begin
  begin
    insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio)
    values ('11111111-1111-4111-8111-111111111111',
            '1c000000-0000-4000-8000-000000000006',        -- cancha de El Molino
            '2e000000-0000-4000-8000-000000000001',        -- cliente de Belgrano
            'normal', 'confirmado',
            '2026-09-11 19:00-03', '2026-09-11 20:30-03', 14000);

    raise exception 'FALLO 6: se cargo un turno con el cliente de otro club';
  exception
    when foreign_key_violation then
      raise notice 'OK 6 — no se puede mezclar la cancha de un club con el cliente de otro';
  end;
end $$;

-- Y dos clubes pueden usar el mismo horario sin estorbarse.
do $$
declare n integer;
begin
  select count(*) into n
    from turnos
   where inicio = '2026-09-12 21:00-03'
     and estado = 'confirmado';
  if n < 2 then
    raise exception 'FALLO 7: los clubes no pudieron compartir el mismo horario';
  end if;
  raise notice 'OK 7 — dos clubes reservan el mismo horario sin conflicto';
end $$;

-- ---------------------------------------------------------------------------
-- Reglas de datos: lo que el modelo se niega a guardar
-- ---------------------------------------------------------------------------

do $$
begin
  begin
    insert into clientes (club_id, nombre, telefono, en_lista_negra)
    values ('11111111-1111-4111-8111-111111111111', 'Sin motivo', '+543425550999', true);
    raise exception 'FALLO 8: se acepto una lista negra sin justificar';
  exception
    when check_violation then
      raise notice 'OK 8 — la lista negra exige motivo escrito';
  end;

  begin
    insert into clientes (club_id, nombre, telefono)
    values ('11111111-1111-4111-8111-111111111111', 'Mal cargado', '15 5550-999');
    raise exception 'FALLO 9: se acepto un telefono sin normalizar';
  exception
    when check_violation then
      raise notice 'OK 9 — el telefono entra solo en formato internacional';
  end;

  begin
    insert into turnos (club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio)
    values ('11111111-1111-4111-8111-111111111111',
            '1c000000-0000-4000-8000-000000000006',
            '1e000000-0000-4000-8000-000000000001',
            'normal', 'cancelado',
            '2026-09-11 19:00-03', '2026-09-11 20:30-03', 14000);
    raise exception 'FALLO 10: se cancelo un turno sin decir quien ni cuando';
  exception
    when check_violation then
      raise notice 'OK 10 — no hay cancelacion sin constancia de quien y cuando';
  end;
end $$;

rollback;

-- ---------------------------------------------------------------------------
-- Lo que estas pruebas todavia no cubren:
--
--   * El aislamiento por RLS. Estas consultas corren como duenio de la base,
--     que ignora las politicas. Probarlo de verdad necesita dos usuarios en
--     auth.users y correr las mismas consultas como cada uno.
--   * La disponibilidad y la materializacion de series: las funciones no
--     existen todavia.
-- ---------------------------------------------------------------------------
