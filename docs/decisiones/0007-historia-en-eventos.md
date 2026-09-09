# 0007 — Cancelar no borra: la historia se guarda como eventos

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

En el sistema anterior, cancelar un turno era vaciar los campos de la fila. El
turno volvía a estar libre y del cliente que lo había tomado no quedaba nada.

El brief pide, al mismo tiempo, dos cosas que ese borrado hace imposibles:
saber si canceló el cliente o el club, y tener un ranking de los que más
cancelan. También pide un contador de canceladas por cliente, que es la forma
en que uno naturalmente imagina el dato, y que es justamente donde estas cosas
se rompen: un contador que se incrementa a mano se desincroniza el día que
alguien corrige un registro por fuera de la aplicación, y a partir de ahí nadie
sabe cuál de los dos números es el bueno.

## Decisión

El turno cancelado sigue existiendo. Cambia de estado, y guarda cuándo se
canceló y quién lo hizo —el cliente o el club—, que es la pregunta que el
encargado responde en el momento de cancelar.

Además, cada turno tiene una bitácora de eventos: se creó, se editó, se
canceló, se le cambió el precio, con la marca de tiempo, el usuario que lo hizo
y el detalle de lo que cambió. Son eventos de negocio, no un volcado de
columnas.

Los números por cliente —turnos jugados, cuánto dejó, cuántas veces canceló—
**se calculan** a partir de los turnos. No hay contadores guardados. Si alguna
de esas consultas se vuelve lenta, la respuesta es un índice o una vista
materializada con su refresco, no una columna que alguien tiene que acordarse
de actualizar.

Y la consecuencia práctica en la pantalla: el horario de un turno cancelado
queda libre para vender, pero el registro sigue. Son dos cosas distintas y solo
la primera le importa a la grilla.

## Alternativas descartadas

**Contadores en la tabla de clientes.** Una lectura instantánea a cambio de un
dato que solo es correcto mientras todas las escrituras pasen por el mismo
camino. Nunca pasan.

**Borrar la reserva al cancelar**, como antes. Es lo más simple y elimina la
evidencia de todo lo que el club quiere medir. Además impide entender el
propio sistema: cuando algo sale mal, la única forma de reconstruir qué ocurrió
es la historia.

**Auditoría genérica por trigger sobre todas las tablas.** Registra cada
`update` de cada columna y produce un volumen de ruido en el que la pregunta
del club —quién canceló y por qué— queda enterrada. Los eventos explícitos son
menos y significan algo.

## Costo asumido

Cada operación escribe más de una fila, y la bitácora crece sin techo. Para el
volumen de un club es despreciable —el sistema anterior, con dos años de uso,
no llegaba a cuatro megabytes— pero hay que definir una política de retención
antes de que sea un problema y no después.

Las estadísticas pasan a ser consultas de agregación sobre el historial
completo, más caras que leer una columna. Es un intercambio deliberado:
correcto y más lento antes que rápido y dudoso.

El estado del turno pasa a ser parte del modelo mental de quien escriba
consultas: casi todas necesitan filtrar por turnos confirmados, y olvidarse es
la fuente de error más probable de este diseño. Por eso conviene que las
consultas de negocio pasen por vistas que ya filtren, y no por la tabla cruda.
