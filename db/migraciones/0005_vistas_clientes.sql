-- Clubio — vistas de clientes
--
-- Los numeros por cliente -turnos jugados, cuanto dejo, cuantas veces
-- cancelo- se calculan sobre los turnos y no se guardan (ADR 0007). Estas
-- vistas son la unica definicion de esos numeros: la pantalla de clientes,
-- el detalle y los rankings leen de aca, asi que "turnos jugados" significa
-- lo mismo en todos lados.
--
-- Definiciones:
--   jugado     turno confirmado cuyo fin ya paso. Un turno de la semana que
--              viene todavia no dejo plata.
--   aportado   suma del precio congelado de los turnos jugados.
--   cancelado  turno cancelado por el cliente. Los que cancelo el club no
--              cuentan en contra de nadie.
--
-- security_invoker: una vista corre por defecto con los permisos de quien la
-- creo, que es el duenio de la base y ve todos los clubes. Con esta opcion
-- corre con los del usuario que consulta, y RLS filtra como en las tablas.

create view vw_clientes_resumen
with (security_invoker = true)
as
select cl.id,
       cl.club_id,
       cl.nombre,
       cl.telefono,
       cl.notas,
       cl.en_lista_negra,
       cl.motivo_lista_negra,
       cl.lista_negra_desde,
       cl.creado_en,
       count(t.id) filter (where t.estado = 'confirmado' and t.fin <= now())            as turnos_jugados,
       coalesce(sum(t.precio) filter (where t.estado = 'confirmado' and t.fin <= now()), 0) as total_aportado,
       count(t.id) filter (where t.estado = 'cancelado' and t.cancelado_por = 'cliente') as cancelados,
       count(t.id) filter (where t.estado = 'confirmado' and t.inicio > now())          as turnos_futuros,
       max(t.inicio) filter (where t.estado = 'confirmado' and t.fin <= now())          as ultimo_turno,
       coalesce(
         array_agg(distinct d.nombre) filter (where t.estado = 'confirmado' and t.fin <= now()),
         '{}'
       ) as deportes
  from clientes cl
  left join turnos   t on t.cliente_id = cl.id
  left join canchas  c on c.id = t.cancha_id
  left join deportes d on d.id = c.deporte_id
 group by cl.id;

-- Lo mismo abierto por deporte, para los rankings "por deporte" y para el
-- detalle del cliente.
create view vw_clientes_por_deporte
with (security_invoker = true)
as
select cl.club_id,
       cl.id            as cliente_id,
       d.id             as deporte_id,
       d.nombre         as deporte,
       count(*)         as turnos_jugados,
       sum(t.precio)    as total_aportado
  from turnos t
  join clientes cl on cl.id = t.cliente_id
  join canchas  c  on c.id = t.cancha_id
  join deportes d  on d.id = c.deporte_id
 where t.estado = 'confirmado'
   and t.fin <= now()
 group by cl.club_id, cl.id, d.id, d.nombre;
