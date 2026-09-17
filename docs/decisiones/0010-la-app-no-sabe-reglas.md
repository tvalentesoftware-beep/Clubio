# 0010 — La aplicación no sabe reglas: la URL es el estado y se escribe por acciones de servidor

- **Fecha:** 2026-09-17
- **Estado:** aceptada

## Contexto

En el sistema anterior toda la lógica vivía en el navegador, hablando con la
base con la clave anónima. Eso tuvo dos consecuencias que ya están contadas
en el caso: la regla de las canchas compartidas existía solo para quien
mirara esa pantalla, y cualquier otro cliente —el bot— podía contradecirla.

Las decisiones anteriores llevaron las reglas a la base: la disponibilidad es
una función ([ADR 0002](0002-agenda-sin-grilla-pregenerada.md)), el choque de
espacios es una restricción ([ADR 0003](0003-espacios-compartidos.md)), crear
un fijo es una función que simula y avisa ([ADR 0004](0004-fijos-como-serie.md)).
La pregunta que quedaba es qué le toca hacer a la aplicación.

## Decisión

La aplicación lee y pinta; no calcula. La grilla pinta lo que
`fn_disponibilidad` dijo de cada slot y solo le agrega nombres. Los números
de clientes e ingresos salen de vistas y funciones de la base, de modo que
"turno jugado" significa lo mismo en la tabla, en el detalle y en los
rankings.

**La URL es el estado.** Cada celda de la grilla es un link:
`/turnos?semana=…&cancha=…&inicio=…` abre el panel de ese slot, y el panel se
renderiza en el servidor a partir de esos parámetros. No hay estado de
interfaz en el cliente que haya que sincronizar; recargar la página deja todo
donde estaba, y un slot se puede compartir como link.

**Las escrituras son acciones de servidor.** Cada formulario del panel invoca
una Server Action que valida lo que vino, normaliza el teléfono, resuelve el
cliente y le pide a la base que haga el resto. Si la base dice que no
—exclusión, RLS, un `check`— eso vuelve como mensaje al formulario. Nada se
escribe desde el navegador.

La sesión viaja en cookies y se refresca en un proxy; toda lectura y
escritura corre con el usuario logueado, así que RLS aplica en la
aplicación exactamente igual que en las pruebas.

## Alternativas descartadas

**Una SPA con estado en el cliente y Supabase desde el navegador.** Es el
camino más rápido y el más parecido al sistema anterior. Se descarta porque
vuelve a poner lógica del lado que no controla nada: cada validación que se
haga ahí existe solo para esa pantalla.

**Panel con estado local en React** (un modal abierto con `useState`). Menos
viajes al servidor, pero no hay deep link, el estado se pierde al recargar, y
hay que mantener sincronizado lo que muestra el modal con lo que muestra la
grilla después de escribir. Con la URL como estado, escribir y volver a la
semana es una sola operación.

## Costo asumido

Cada clic en una celda es una navegación con ida al servidor. En una red
lenta se nota; Next prefetchea los links visibles y eso lo amortigua, pero no
hay interfaz optimista: el encargado ve el turno cuando la base lo confirmó,
no antes. Es el intercambio elegido a propósito, porque lo que la base
confirma es lo único que vale.

React vacía los formularios cuando la acción responde, y un `select` solo
toma su valor por defecto al montarse. Los valores escritos tienen que
volver en el estado de la acción y el `select` se remonta por `key`; sin eso,
"crear igual" mandaba el tipo equivocado. Es un detalle chico que costó un
bug real y quedó en el commit.

Una semana de grilla son cinco lecturas en paralelo —slots, canchas, turnos,
series, cierres— porque la función devuelve ids y la aplicación agrega
nombres. Es un intercambio consciente: la función se mantiene mínima y
reutilizable, y las lecturas extra son baratas. Si alguna vez pesa, la
salida es una vista que ya traiga los nombres, no lógica en la aplicación.
