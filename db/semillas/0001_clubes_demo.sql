-- Clubio — clubes de demostracion
--
-- Dos clubes ficticios. No es relleno: cada uno existe para ejercitar algo
-- que el otro no puede (ADR 0009).
--
--   El Molino     — el caso dificil. Cuatro canchas de futbol sobre tres
--                   espacios, padel con horarios distintos segun el dia,
--                   una tarifa vencida y otra vigente, un fijo, una clase
--                   y un turno cancelado.
--   Padel Belgrano — el caso comun, y sobre todo el segundo club: sin el,
--                   el aislamiento entre clubes no se puede probar.
--
-- Ningun dato viene de un club real. Los telefonos son ficticios.
-- Este archivo no se corre en produccion.

-- ---------------------------------------------------------------------------
-- Club 1 — El Molino
-- ---------------------------------------------------------------------------

insert into clubes (id, nombre, slug, color_primario, color_secundario) values
  ('11111111-1111-4111-8111-111111111111', 'Club El Molino', 'el-molino', '#1D7BF0', '#35CFEA');

-- Los espacios: cinco pedazos de piso.
insert into espacios (id, club_id, nombre) values
  ('1a000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'Pasto norte'),
  ('1a000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'Pasto centro'),
  ('1a000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'Pasto sur'),
  ('1a000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'Cancha de padel A'),
  ('1a000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'Cancha de padel B');

insert into deportes (id, club_id, nombre, duracion_min) values
  ('1d000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'Futbol 5', 60),
  ('1d000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'Futbol 8', 60),
  ('1d000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'Padel', 90);

-- Seis canchas vendibles sobre cinco espacios: la de futbol 8 es el mismo
-- pasto que las tres de futbol 5.
insert into canchas (id, club_id, deporte_id, nombre, orden) values
  ('1c000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000001', 'Cancha 1', 1),
  ('1c000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000001', 'Cancha 2', 2),
  ('1c000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000001', 'Cancha 3', 3),
  ('1c000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000002', 'La grande',  4),
  ('1c000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000003', 'Padel 1',    5),
  ('1c000000-0000-4000-8000-000000000006', '11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000003', 'Padel 2',    6);

-- Aca vive la regla entera: "La grande" ocupa los tres pastos.
insert into cancha_espacios (club_id, cancha_id, espacio_id) values
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000001', '1a000000-0000-4000-8000-000000000001'),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000002', '1a000000-0000-4000-8000-000000000002'),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000003', '1a000000-0000-4000-8000-000000000003'),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000004', '1a000000-0000-4000-8000-000000000001'),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000004', '1a000000-0000-4000-8000-000000000002'),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000004', '1a000000-0000-4000-8000-000000000003'),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000005', '1a000000-0000-4000-8000-000000000004'),
  ('11111111-1111-4111-8111-111111111111', '1c000000-0000-4000-8000-000000000006', '1a000000-0000-4000-8000-000000000005');

-- Futbol: todos los dias de 15 a 23.
insert into franjas_apertura (club_id, cancha_id, dia_semana, hora_desde, hora_hasta, vigente_desde)
select '11111111-1111-4111-8111-111111111111', c.id, d, '15:00', '23:00', '2026-01-01'
  from (values
        ('1c000000-0000-4000-8000-000000000001'::uuid),
        ('1c000000-0000-4000-8000-000000000002'::uuid),
        ('1c000000-0000-4000-8000-000000000003'::uuid),
        ('1c000000-0000-4000-8000-000000000004'::uuid)) as c(id),
       generate_series(0, 6) as d;

-- Padel: los horarios varian por dia y por cancha, como en el club real que
-- dio origen a esto. Padel 1 abre mas tarde los lunes; Padel 2 no abre los
-- domingos.
insert into franjas_apertura (club_id, cancha_id, dia_semana, hora_desde, hora_hasta, vigente_desde)
select '11111111-1111-4111-8111-111111111111',
       '1c000000-0000-4000-8000-000000000005', d,
       case when d = 1 then time '15:00' else time '14:30' end,
       '22:30', '2026-01-01'
  from generate_series(0, 6) as d;

insert into franjas_apertura (club_id, cancha_id, dia_semana, hora_desde, hora_hasta, vigente_desde)
select '11111111-1111-4111-8111-111111111111',
       '1c000000-0000-4000-8000-000000000006', d, '14:30', '22:00', '2026-01-01'
  from generate_series(1, 6) as d;

-- Tarifas: la del ano pasado queda cerrada, no editada. El fijo paga menos.
insert into tarifas (club_id, deporte_id, tipo_turno, precio, vigente_desde, vigente_hasta) values
  ('11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000001', null,     12000, '2025-01-01', '2025-12-31'),
  ('11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000001', 'normal', 18000, '2026-01-01', null),
  ('11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000001', 'fijo',   15000, '2026-01-01', null),
  ('11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000002', null,     32000, '2026-01-01', null),
  ('11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000003', 'normal', 14000, '2026-01-01', null),
  ('11111111-1111-4111-8111-111111111111', '1d000000-0000-4000-8000-000000000003', 'clase',  16000, '2026-01-01', null);

insert into clientes (id, club_id, nombre, telefono, en_lista_negra, motivo_lista_negra, lista_negra_desde) values
  ('1e000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111', 'Ramiro Ferrer',   '+5493425550101', false, null, null),
  ('1e000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111', 'Carla Ibanez',    '+5493425550102', false, null, null),
  ('1e000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111', 'MARTIN OVIEDO',   '+5493425550103', false, null, null),
  ('1e000000-0000-4000-8000-000000000004', '11111111-1111-4111-8111-111111111111', 'Sofia Retamar',   '+5493425550104', false, null, null),
  ('1e000000-0000-4000-8000-000000000005', '11111111-1111-4111-8111-111111111111', 'Bruno Cardozo',   '+5493425550105', true,
   'Rompio dos paletas del club y no respondio los mensajes', '2026-06-14 10:00-03');

-- Un fijo de los sabados y una clase de los martes. Los turnos concretos los
-- va a generar fn_materializar_serie cuando exista; por ahora la regla queda
-- declarada, que es justamente el punto del ADR 0004.
insert into series (id, club_id, cancha_id, cliente_id, tipo, dia_semana, hora_inicio, duracion_min, vigente_desde) values
  ('1f000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
   '1c000000-0000-4000-8000-000000000002', '1e000000-0000-4000-8000-000000000001',
   'fijo', 6, '20:00', 60, '2026-03-07'),
  ('1f000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111',
   '1c000000-0000-4000-8000-000000000005', '1e000000-0000-4000-8000-000000000004',
   'clase', 2, '18:00', 90, '2026-04-01');

-- Turnos. El primero es el caso interesante: una reserva de "La grande" el
-- sabado a las 21 deja los tres pastos ocupados.
insert into turnos (id, club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio) values
  ('1b000000-0000-4000-8000-000000000001', '11111111-1111-4111-8111-111111111111',
   '1c000000-0000-4000-8000-000000000004', '1e000000-0000-4000-8000-000000000002',
   'normal', 'confirmado', '2026-09-12 21:00-03', '2026-09-12 22:00-03', 32000),

  ('1b000000-0000-4000-8000-000000000002', '11111111-1111-4111-8111-111111111111',
   '1c000000-0000-4000-8000-000000000005', '1e000000-0000-4000-8000-000000000003',
   'normal', 'confirmado', '2026-09-09 19:00-03', '2026-09-09 20:30-03', 14000);

-- Un turno cancelado: el horario vuelve a estar libre, el registro queda.
insert into turnos (id, club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio, cancelado_por, cancelado_en) values
  ('1b000000-0000-4000-8000-000000000003', '11111111-1111-4111-8111-111111111111',
   '1c000000-0000-4000-8000-000000000001', '1e000000-0000-4000-8000-000000000005',
   'normal', 'cancelado', '2026-09-10 20:00-03', '2026-09-10 21:00-03', 18000,
   'cliente', '2026-09-09 12:30-03');

insert into turno_eventos (club_id, turno_id, tipo, detalle) values
  ('11111111-1111-4111-8111-111111111111', '1b000000-0000-4000-8000-000000000003', 'creado', '{}'),
  ('11111111-1111-4111-8111-111111111111', '1b000000-0000-4000-8000-000000000003', 'cancelado',
   '{"por": "cliente", "aviso_horas_antes": 31}');

-- ---------------------------------------------------------------------------
-- Club 2 — Padel Belgrano
--
-- El caso comun: un espacio por cancha, horarios parejos, una sola tarifa.
-- Existe sobre todo para que haya dos clubes: el aislamiento no se puede
-- probar con uno solo.
-- ---------------------------------------------------------------------------

insert into clubes (id, nombre, slug, color_primario) values
  ('22222222-2222-4222-8222-222222222222', 'Padel Belgrano', 'padel-belgrano', '#0F9D58');

insert into espacios (id, club_id, nombre) values
  ('2b000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', 'Cancha 1'),
  ('2b000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', 'Cancha 2');

insert into deportes (id, club_id, nombre, duracion_min) values
  ('2d000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', 'Padel', 90);

insert into canchas (id, club_id, deporte_id, nombre, orden) values
  ('2c000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', '2d000000-0000-4000-8000-000000000001', 'Cancha 1', 1),
  ('2c000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', '2d000000-0000-4000-8000-000000000001', 'Cancha 2', 2);

insert into cancha_espacios (club_id, cancha_id, espacio_id) values
  ('22222222-2222-4222-8222-222222222222', '2c000000-0000-4000-8000-000000000001', '2b000000-0000-4000-8000-000000000001'),
  ('22222222-2222-4222-8222-222222222222', '2c000000-0000-4000-8000-000000000002', '2b000000-0000-4000-8000-000000000002');

insert into franjas_apertura (club_id, cancha_id, dia_semana, hora_desde, hora_hasta, vigente_desde)
select '22222222-2222-4222-8222-222222222222', c.id, d, '09:00', '23:00', '2026-01-01'
  from (values
        ('2c000000-0000-4000-8000-000000000001'::uuid),
        ('2c000000-0000-4000-8000-000000000002'::uuid)) as c(id),
       generate_series(0, 6) as d;

insert into tarifas (club_id, deporte_id, precio, vigente_desde) values
  ('22222222-2222-4222-8222-222222222222', '2d000000-0000-4000-8000-000000000001', 16000, '2026-01-01');

insert into clientes (id, club_id, nombre, telefono) values
  ('2e000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222', 'Lucia Frank',   '+5493425550201'),
  ('2e000000-0000-4000-8000-000000000002', '22222222-2222-4222-8222-222222222222', 'Ramiro Ferrer', '+5493425550101');
  -- ^ mismo nombre y mismo telefono que un cliente de El Molino, y aun asi
  --   es otro cliente, con otro historial: ADR 0006.

insert into turnos (id, club_id, cancha_id, cliente_id, tipo, estado, inicio, fin, precio) values
  ('2f000000-0000-4000-8000-000000000001', '22222222-2222-4222-8222-222222222222',
   '2c000000-0000-4000-8000-000000000001', '2e000000-0000-4000-8000-000000000001',
   'normal', 'confirmado', '2026-09-12 21:00-03', '2026-09-12 22:30-03', 16000);
  -- ^ mismo horario que el turno de "La grande" en El Molino, y no choca:
  --   son espacios distintos.

-- ---------------------------------------------------------------------------
-- Pendiente, y a proposito: usuarios_club.
--
-- La tabla apunta a auth.users, asi que no se puede sembrar sin crear antes
-- los usuarios en Supabase. Una vez creados, el insert es:
--
--   insert into usuarios_club (club_id, usuario_id, rol) values
--     ('11111111-1111-4111-8111-111111111111', '<uuid del usuario>', 'dueno');
--
-- Hasta que eso exista, RLS deja estos datos invisibles para cualquier
-- usuario autenticado, que es exactamente lo que tiene que pasar.
-- ---------------------------------------------------------------------------
