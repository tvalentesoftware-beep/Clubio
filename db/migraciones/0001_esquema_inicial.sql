-- Clubio — esquema inicial
--
-- Convenciones que valen para todo el archivo:
--
--   * Toda tabla de negocio lleva club_id y RLS activo (ADR 0001).
--   * Toda tabla declara unique (id, club_id) para que quien la referencie
--     pueda hacerlo por el par y sea imposible cruzar datos de dos clubes.
--   * Los estados son text con check y no enums: agregar un valor a un enum
--     en Postgres es una migracion incomoda, y estos conjuntos van a crecer.
--   * Los instantes son timestamptz. La hora local del club sale de su
--     zona horaria, nunca de la del servidor.

create extension if not exists btree_gist;

-- ---------------------------------------------------------------------------
-- 1. Quien entra
-- ---------------------------------------------------------------------------

create table clubes (
  id                uuid primary key default gen_random_uuid(),
  nombre            text        not null,
  slug              text        not null unique,
  zona_horaria      text        not null default 'America/Argentina/Buenos_Aires',
  moneda            text        not null default 'ARS',
  logo_url          text,
  color_primario    text,
  color_secundario  text,
  activo            boolean     not null default true,
  creado_en         timestamptz not null default now()
);

create table usuarios_club (
  club_id     uuid        not null references clubes (id) on delete cascade,
  usuario_id  uuid        not null references auth.users (id) on delete cascade,
  rol         text        not null check (rol in ('dueno', 'encargado', 'lector')),
  activo      boolean     not null default true,
  creado_en   timestamptz not null default now(),
  primary key (club_id, usuario_id)
);

-- Resuelve la pertenencia sin volver a pasar por RLS: si la politica de
-- usuarios_club se evaluara aca, la consulta se llamaria a si misma.
create or replace function es_miembro(p_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from usuarios_club uc
     where uc.club_id = p_club
       and uc.usuario_id = auth.uid()
       and uc.activo
  );
$$;

-- ---------------------------------------------------------------------------
-- 2. Como es el club
-- ---------------------------------------------------------------------------

create table deportes (
  id            uuid    primary key default gen_random_uuid(),
  club_id       uuid    not null references clubes (id) on delete cascade,
  nombre        text    not null,
  duracion_min  integer not null check (duracion_min between 15 and 480),
  activo        boolean not null default true,
  unique (id, club_id),
  unique (club_id, nombre)
);

-- El pedazo de piso. No se vende ni se muestra: es contra lo que se
-- resuelven los conflictos (ADR 0003).
create table espacios (
  id       uuid primary key default gen_random_uuid(),
  club_id  uuid not null references clubes (id) on delete cascade,
  nombre   text not null,
  unique (id, club_id),
  unique (club_id, nombre)
);

-- Lo que se vende.
create table canchas (
  id          uuid    primary key default gen_random_uuid(),
  club_id     uuid    not null references clubes (id) on delete cascade,
  deporte_id  uuid    not null,
  nombre      text    not null,
  orden       integer not null default 0,
  activa      boolean not null default true,
  unique (id, club_id),
  unique (club_id, deporte_id, nombre),
  foreign key (deporte_id, club_id) references deportes (id, club_id)
);

-- Que espacios ocupa cada cancha. La cancha de futbol 8 tiene tres filas
-- aca; cada cancha de futbol 5, una. Un club sin canchas combinables tiene
-- una fila por cancha y nunca se entera de que esto existe.
create table cancha_espacios (
  club_id     uuid not null references clubes (id) on delete cascade,
  cancha_id   uuid not null,
  espacio_id  uuid not null,
  primary key (cancha_id, espacio_id),
  foreign key (cancha_id, club_id)  references canchas  (id, club_id) on delete cascade,
  foreign key (espacio_id, club_id) references espacios (id, club_id) on delete cascade
);

-- Reemplaza a la grilla pre-generada (ADR 0002).
create table franjas_apertura (
  id             uuid     primary key default gen_random_uuid(),
  club_id        uuid     not null references clubes (id) on delete cascade,
  cancha_id      uuid     not null,
  dia_semana     smallint not null check (dia_semana between 0 and 6),  -- 0 = domingo
  hora_desde     time     not null,
  hora_hasta     time     not null,
  vigente_desde  date     not null default current_date,
  vigente_hasta  date,
  unique (id, club_id),
  check (hora_hasta > hora_desde),
  check (vigente_hasta is null or vigente_hasta >= vigente_desde),
  foreign key (cancha_id, club_id) references canchas (id, club_id) on delete cascade
);

-- Una decision del club: vacaciones, mantenimiento, lluvia, evento privado.
-- cancha_id en nulo alcanza al club entero. No es un turno (ADR 0007).
create table cierres (
  id          uuid        primary key default gen_random_uuid(),
  club_id     uuid        not null references clubes (id) on delete cascade,
  cancha_id   uuid,
  durante     tstzrange   not null,
  motivo      text        not null,
  creado_por  uuid        references auth.users (id),
  creado_en   timestamptz not null default now(),
  unique (id, club_id),
  check (not isempty(durante)),
  foreign key (cancha_id, club_id) references canchas (id, club_id) on delete cascade
);

create index on cierres using gist (durante);

-- Aumentar no es editar: se cierra la vigente y se abre una nueva (ADR 0005).
-- cancha_id y tipo_turno en nulo significan "toda cancha" y "todo tipo".
create table tarifas (
  id             uuid          primary key default gen_random_uuid(),
  club_id        uuid          not null references clubes (id) on delete cascade,
  deporte_id     uuid          not null,
  cancha_id      uuid,
  tipo_turno     text          check (tipo_turno in ('normal', 'fijo', 'clase')),
  precio         numeric(12,2) not null check (precio >= 0),
  vigente_desde  date          not null,
  vigente_hasta  date,
  unique (id, club_id),
  check (vigente_hasta is null or vigente_hasta >= vigente_desde),
  foreign key (deporte_id, club_id) references deportes (id, club_id) on delete cascade,
  foreign key (cancha_id, club_id)  references canchas  (id, club_id) on delete cascade
);

-- ---------------------------------------------------------------------------
-- 3. Quien juega
-- ---------------------------------------------------------------------------

-- telefono en formato internacional, normalizado en la escritura (ADR 0006).
-- Sin contadores: turnos jugados, aportado y canceladas se calculan (ADR 0007).
create table clientes (
  id                   uuid        primary key default gen_random_uuid(),
  club_id              uuid        not null references clubes (id) on delete cascade,
  nombre               text        not null,
  telefono             text        not null,
  notas                text,
  en_lista_negra       boolean     not null default false,
  motivo_lista_negra   text,
  lista_negra_desde    timestamptz,
  creado_en            timestamptz not null default now(),
  unique (id, club_id),
  unique (club_id, telefono),
  check (telefono ~ '^\+[1-9][0-9]{7,14}$'),
  check (not en_lista_negra or motivo_lista_negra is not null)
);

-- ---------------------------------------------------------------------------
-- 4. Que pasa en las canchas
-- ---------------------------------------------------------------------------

-- La regla del fijo o la clase (ADR 0004). Los turnos se materializan a
-- partir de esto; terminar la serie da de baja el fijo.
create table series (
  id             uuid        primary key default gen_random_uuid(),
  club_id        uuid        not null references clubes (id) on delete cascade,
  cancha_id      uuid        not null,
  cliente_id     uuid        not null,
  tipo           text        not null check (tipo in ('fijo', 'clase')),
  dia_semana     smallint    not null check (dia_semana between 0 and 6),
  hora_inicio    time        not null,
  duracion_min   integer     not null check (duracion_min between 15 and 480),
  vigente_desde  date        not null,
  vigente_hasta  date,
  creado_en      timestamptz not null default now(),
  unique (id, club_id),
  check (vigente_hasta is null or vigente_hasta >= vigente_desde),
  foreign key (cancha_id, club_id)  references canchas  (id, club_id),
  foreign key (cliente_id, club_id) references clientes (id, club_id)
);

create table turnos (
  id             uuid          primary key default gen_random_uuid(),
  club_id        uuid          not null references clubes (id) on delete cascade,
  cancha_id      uuid          not null,
  cliente_id     uuid          not null,
  serie_id       uuid,
  tipo           text          not null check (tipo in ('normal', 'fijo', 'clase')),
  estado         text          not null default 'confirmado'
                               check (estado in ('confirmado', 'cancelado')),
  inicio         timestamptz   not null,
  fin            timestamptz   not null,
  precio         numeric(12,2) not null check (precio >= 0),
  notas          text,
  cancelado_por  text          check (cancelado_por in ('cliente', 'club')),
  cancelado_en   timestamptz,
  creado_por     uuid          references auth.users (id),
  creado_en      timestamptz   not null default now(),
  unique (id, club_id),
  check (fin > inicio),
  -- cancelado y con constancia de quien y cuando, o ninguna de las tres cosas
  check (
    (estado = 'cancelado' and cancelado_en is not null and cancelado_por is not null)
    or
    (estado = 'confirmado' and cancelado_en is null and cancelado_por is null)
  ),
  foreign key (cancha_id, club_id)  references canchas  (id, club_id),
  foreign key (cliente_id, club_id) references clientes (id, club_id),
  foreign key (serie_id, club_id)   references series   (id, club_id) on delete set null
);

create index on turnos (club_id, inicio);
create index on turnos (club_id, cliente_id) where estado = 'confirmado';
create index on turnos (serie_id) where serie_id is not null;

-- Derivada: la escribe el trigger de mas abajo y nada mas. Es la unica razon
-- por la que el modelo separa cancha de espacio (ADR 0003): esta restriccion
-- hace estructuralmente imposible vender dos veces el mismo piso.
create table ocupaciones (
  turno_id    uuid      not null,
  club_id     uuid      not null references clubes (id) on delete cascade,
  espacio_id  uuid      not null,
  durante     tstzrange not null,
  primary key (turno_id, espacio_id),
  foreign key (turno_id, club_id)   references turnos   (id, club_id) on delete cascade,
  foreign key (espacio_id, club_id) references espacios (id, club_id) on delete cascade,
  exclude using gist (espacio_id with =, durante with &&)
);

create or replace function fn_sincronizar_ocupaciones()
returns trigger
language plpgsql
as $$
begin
  delete from ocupaciones where turno_id = new.id;

  if new.estado = 'confirmado' then
    insert into ocupaciones (turno_id, club_id, espacio_id, durante)
    select new.id, new.club_id, ce.espacio_id, tstzrange(new.inicio, new.fin, '[)')
      from cancha_espacios ce
     where ce.cancha_id = new.cancha_id;
  end if;

  return new;
end;
$$;

create trigger trg_sincronizar_ocupaciones
after insert or update of estado, inicio, fin, cancha_id on turnos
for each row execute function fn_sincronizar_ocupaciones();

-- La bitacora (ADR 0007): eventos de negocio, no un volcado de columnas.
create table turno_eventos (
  id          bigserial   primary key,
  club_id     uuid        not null references clubes (id) on delete cascade,
  turno_id    uuid        not null,
  tipo        text        not null
              check (tipo in ('creado', 'editado', 'cancelado', 'precio_cambiado')),
  detalle     jsonb       not null default '{}'::jsonb,
  usuario_id  uuid        references auth.users (id),
  ocurrido_en timestamptz not null default now(),
  foreign key (turno_id, club_id) references turnos (id, club_id) on delete cascade
);

create index on turno_eventos (club_id, turno_id, ocurrido_en);

-- ---------------------------------------------------------------------------
-- 5. Aislamiento entre clubes
--
-- Se activa en la misma migracion que crea las tablas, nunca despues: una
-- tabla sin politica es una tabla que se lee entera desde cualquier cliente.
-- ---------------------------------------------------------------------------

alter table clubes            enable row level security;
alter table usuarios_club     enable row level security;
alter table deportes          enable row level security;
alter table espacios          enable row level security;
alter table canchas           enable row level security;
alter table cancha_espacios   enable row level security;
alter table franjas_apertura  enable row level security;
alter table cierres           enable row level security;
alter table tarifas           enable row level security;
alter table clientes          enable row level security;
alter table series            enable row level security;
alter table turnos            enable row level security;
alter table ocupaciones       enable row level security;
alter table turno_eventos     enable row level security;

create policy miembros_del_club on clubes
  for all using (es_miembro(id)) with check (es_miembro(id));

create policy miembros_del_club on usuarios_club
  for all using (es_miembro(club_id)) with check (es_miembro(club_id));

do $$
declare t text;
begin
  foreach t in array array[
    'deportes', 'espacios', 'canchas', 'cancha_espacios', 'franjas_apertura',
    'cierres', 'tarifas', 'clientes', 'series', 'turnos', 'ocupaciones',
    'turno_eventos'
  ] loop
    execute format(
      'create policy miembros_del_club on %I for all
         using (es_miembro(club_id)) with check (es_miembro(club_id))', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Pendiente, en su propia migracion y con sus casos de prueba:
--
--   fn_disponibilidad(club, cancha, dia) — franjas de apertura, menos
--   cierres, menos ocupaciones, menos series vigentes todavia no
--   materializadas. Es la unica definicion de "esta libre" del sistema
--   (ADR 0002) y la pieza con mas chance de estar mal.
--
--   fn_materializar_serie(serie, hasta) — genera los turnos de una serie
--   hasta el horizonte, sin pisar lo que ya exista (ADR 0004).
-- ---------------------------------------------------------------------------
