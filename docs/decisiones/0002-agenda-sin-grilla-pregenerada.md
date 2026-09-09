# 0002 — La disponibilidad se calcula; no hay grilla pre-generada

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

El sistema anterior no creaba una fila al reservar: ya existía una fila por
cada combinación posible de fecha, hora, deporte y cancha, y reservar era un
`UPDATE`. Cuarenta y siete filas por día, y una extensión de la grilla que
insertó diecisiete mil filas para cubrir un año.

Eso trajo, en orden de gravedad: la grilla se termina —cuando se acerca el
borde hay que acordarse de extenderla, y si nadie se acuerda el club deja de
poder tomar reservas a futuro—; un turno que no existe y un turno libre son la
misma cosa vista desde la aplicación, así que un hueco en el molde parece
disponibilidad; el molde codifica los horarios, de modo que cambiar el horario
de verano obliga a regenerar filas; y la duración del turno queda fija en el
molde, lo cual funciona con canchas pero se rompe apenas aparece cualquier
servicio de duración variable.

Clubio, siendo multi-club, multiplica todo esto por cada cliente nuevo.

## Decisión

Una reserva es una fila que se inserta cuando alguien reserva y se marca como
cancelada cuando se cancela. No hay filas para los turnos que no existen.

La disponibilidad se calcula: se parte de las franjas de apertura declaradas
para la cancha ese día de la semana, se le restan los cierres vigentes y las
ocupaciones existentes, y lo que queda se ofrece. Ese cálculo vive en la base
de datos, como función, y no en la pantalla: es la única definición de "está
libre" que hay en el sistema.

El turno se guarda con `inicio` y `fin` como instantes (`timestamptz`), no como
fecha y hora sueltas, para que la duración pueda ser distinta por deporte sin
tocar nada estructural.

## Alternativas descartadas

**Seguir con la grilla pre-generada.** Tiene una ventaja real que no hay que
minimizar: la pantalla del encargado es la tabla, sin transformación de por
medio, y eso hace que el sistema anterior se sienta rápido y obvio. Se descarta
porque los problemas de arriba no se arreglan con más disciplina: son
estructurales, y en un producto multi-club se pagan una vez por cliente.

**Materializar los slots con un job periódico.** Suena a lo mejor de los dos
mundos, pero es la misma grilla con un cron que la mantiene: sigue habiendo un
horizonte que se termina, sigue habiendo un momento en que la configuración y
las filas materializadas están en desacuerdo, y ahora además hay un job que se
puede caer sin que nadie mire.

**Calcular la disponibilidad en el frontend.** Es lo que hacía el sistema
anterior, y es exactamente por eso que el bot de WhatsApp podía ofrecer un
horario que el panel consideraba ocupado. Toda regla que vive en una pantalla
existe solo para quien mire esa pantalla.

## Costo asumido

La vista tipo planilla ahora hay que construirla: el club sigue queriendo ver
la semana entera de un golpe, y esa grilla pasa a armarse en memoria a partir
de la configuración y de las reservas. Es más código y hay que cuidar que una
vista de una semana entera se resuelva en pocas consultas y no en una por
casilla.

Depurar se vuelve un poco menos evidente. En la grilla, "está libre" se veía
mirando la fila. Acá "está libre" es la ausencia de una fila más el resultado
de una función, así que la función tiene que estar cubierta por pruebas: es la
pieza de la que depende todo lo demás.

Aparece la zona horaria como preocupación real desde el día uno. Guardar
instantes es lo correcto, pero obliga a ser cuidadoso en cada borde entre la
base y la pantalla, donde el encargado piensa en "sábado a las 20".
