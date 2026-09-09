# 0009 — Los datos de prueba son dos clubes inventados, no un volcado real

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

El esquema promete cosas fuertes: que no se puede vender dos veces el mismo
piso, que cancelar libera el horario sin borrar la historia, que un club no
puede tocar los datos de otro. Ninguna de esas promesas vale nada hasta que se
pueda ejecutar.

Hay un atajo a mano: el club del caso tiene dos años de datos reales, con toda
la suciedad que los datos reales traen. Cargar eso y ver qué pasa es tentador.

## Decisión

Dos clubes ficticios en `db/semillas/`, elegidos para que cada uno ejercite lo
que el otro no puede.

**El Molino** es el caso difícil: cuatro canchas de fútbol sobre tres espacios
—la grande es el mismo pasto que las tres chicas—, pádel con horarios que
cambian según el día y según la cancha, una tarifa del año pasado ya cerrada y
otra vigente, un fijo, una clase y un turno cancelado.

**Pádel Belgrano** es el caso común —un espacio por cancha, horarios parejos,
una sola tarifa— y existe sobre todo por una razón: sin un segundo club, el
aislamiento no se puede probar. Reserva además el mismo horario que El Molino,
para dejar demostrado que dos clubes no se estorban.

Encima de esa semilla van las pruebas de `db/pruebas/`: diez comprobaciones que
corren en una transacción con `rollback` y que verifican, una por una, las
promesas de los ADR anteriores. Si alguna se rompe, el script corta diciendo
cuál.

## Alternativas descartadas

**Un volcado anonimizado del club real.** Aunque se cambien los nombres, los
teléfonos, los horarios y los patrones de reserva son datos de un cliente, y
este repositorio es público. El dato de un tercero no se publica porque sea
conveniente para probar.

**Generar datos al azar en volumen.** Sirve para medir rendimiento y no sirve
para nada de lo que hay que probar acá: lo interesante no es tener cien mil
turnos, es tener dos que se superponen sobre el mismo espacio.

**Un solo club de demostración.** Alcanza para casi todo y deja afuera
justamente la promesa más delicada del modelo, que es el aislamiento.

## Costo asumido

Los datos inventados son demasiado prolijos. En producción aparecen cosas que
nadie siembra: la misma persona cargada dos veces con dos números, el turno
que quedó a caballo de dos días, el horario que no cierra con la duración del
deporte. La semilla trae algo de suciedad a propósito —un nombre en
mayúsculas, una tarifa vencida, un cliente en lista negra, el mismo teléfono
en los dos clubes— pero es suciedad elegida, y la que rompe sistemas es la que
no se le ocurrió a nadie.

El rendimiento no se prueba con esto. Cuando haya que optimizar la vista
semanal va a hacer falta un generador de volumen aparte, y es un trabajo
distinto.

Y hay una prueba que la semilla no puede correr sola: RLS. Las políticas se
evalúan contra un usuario autenticado, y sembrar `usuarios_club` exige crear
antes usuarios reales en Supabase. Queda anotado en la semilla y pendiente,
que es preferible a una prueba que corre como dueño de la base y da verde
sin haber probado nada.
