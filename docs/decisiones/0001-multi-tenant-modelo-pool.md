# 0001 — Un solo esquema para todos los clubes, aislado por `club_id` y RLS

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

Clubio es un producto que se vende varias veces, no un desarrollo a medida. El
sistema anterior tenía la estructura del club horneada adentro: los deportes,
la cantidad de canchas y hasta los tres patrones distintos de horarios del
pádel vivían en el código que generaba la grilla. Vender eso a un segundo club
era copiar el proyecto y editarlo, y a partir de ahí mantener dos.

El costo del aislamiento se paga una vez, al principio, y no se puede agregar
después sin reescribir todas las consultas.

## Decisión

Un solo esquema PostgreSQL para todos los clubes. Cada tabla de negocio lleva
`club_id`, y el aislamiento se sostiene con Row Level Security de Postgres: la
política filtra por los clubes a los que pertenece el usuario autenticado.

Además, las claves foráneas son **compuestas**. Cada tabla declara
`unique (id, club_id)`, y quien la referencia lo hace por el par: una reserva
apunta a `(cancha_id, club_id)`, no solo a `cancha_id`. Así, un bug que intente
enganchar la cancha de un club con el cliente de otro no falla en silencio:
falla contra una restricción de integridad.

## Alternativas descartadas

**Una base de datos por club.** Es el aislamiento más fuerte que existe y no
depende de que las políticas estén bien escritas. Se descarta por el costo
operativo: cada club nuevo es una base que aprovisionar, migrar y respaldar, y
cualquier consulta que mire el conjunto —cuántos clubes hay activos, cuánto se
usa el producto— deja de ser una consulta. Para un producto que recién arranca
y que va a tener decenas de clientes, no cientos de miles, el costo llega
mucho antes que el beneficio.

**Un esquema por club dentro de la misma base.** Punto intermedio, pero hereda
lo peor de los dos lados: hay que aplicar cada migración N veces y el código
tiene que resolver a qué esquema apunta antes de cada consulta, sin ganar el
aislamiento real de una base separada.

## Costo asumido

El aislamiento pasa a depender de que las políticas de RLS estén bien: un
`select` sin política, o una política mal escrita, expone datos de todos los
clubes a la vez. Eso obliga a una disciplina fija —RLS activado en cada tabla
desde su creación, nunca "después"— y a probar el aislamiento como se prueba
una funcionalidad.

Una migración se aplica sobre todos los clubes al mismo tiempo: no hay forma de
actualizar a uno y dejar a otro atrás.

Revertir hacia bases separadas es posible y hasta prolijo —el `club_id` ya
define el corte— pero implica rehacer la capa de acceso a datos entera.
