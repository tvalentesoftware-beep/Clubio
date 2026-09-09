# 0003 — Las canchas se componen de espacios, y el choque lo impide la base

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

En el club del caso, la cancha de fútbol 8 es el mismo pasto que las tres de
fútbol 5. Cuatro canchas vendibles sobre tres pedazos de piso. La regla
—vender una deja las otras sin lugar— la sostenía el encargado de memoria,
ayudado por un trigger que escribía una segunda fila con el nombre
`BLOQUEADO`. Ni la pantalla ni el bot conocían la regla, así que la consulta de
disponibilidad podía ofrecer la cancha grande con las tres chicas vendidas.

Que nunca se haya vendido dos veces el mismo pasto —lo verifiqué sobre toda la
tabla, sin una sola excepción— es mérito de la persona, no del sistema. Un
producto no puede depender de eso.

No es un caso raro: pasa con canchas de tenis que se dividen en dos de pádel,
con salones que se separan con panel, con la cancha techada que también es el
gimnasio.

## Decisión

Se separa lo que se vende de lo que se ocupa. La **cancha** es la unidad
comercial; el **espacio** es el pedazo de piso. Una tabla intermedia declara
qué espacios ocupa cada cancha: la de fútbol 8 ocupa los tres, cada una de
fútbol 5 ocupa el suyo.

Cada reserva confirmada deja, por trigger, una fila de **ocupación** por cada
espacio que usa, con el rango de tiempo que dura. Sobre esa tabla hay una
restricción de exclusión de PostgreSQL:

```sql
exclude using gist (espacio_id with =, durante with &&)
```

Dos ocupaciones del mismo espacio con tiempos que se superponen no pueden
coexistir. No es una validación: es una restricción. Un `insert` que la viole
falla, venga del panel, de un script o de lo que sea que exista mañana.

Un club sin canchas combinables declara un espacio por cancha y no se entera de
que esto existe.

## Alternativas descartadas

**El trigger que escribe la reserva espejo**, como en el sistema anterior.
Funciona hacia adelante pero duplica el dato: cada turno de fútbol 8 genera
tres filas más que no son turnos, ensucian cualquier estadística de ocupación y
obligan a filtrarlas en todas las consultas. Y sobre todo, no impide nada: si
una inserción entra sin pasar por el trigger, o si el trigger cubre un sentido
y no el otro, la doble venta ocurre igual.

**Validar en la aplicación antes de insertar.** Es la solución que todo el
mundo escribe primero y falla por una razón que no se ve en desarrollo: dos
pedidos simultáneos consultan, los dos ven libre, los dos insertan. Con un club
chico pasa poco, y por eso cuando pasa nadie entiende qué ocurrió.

**Modelar una jerarquía cancha padre / cancha hija.** Alcanza para el caso del
fútbol y se rompe en el primero que no sea jerárquico: dos canchas de pádel que
juntas hacen una de tenis no son padre e hija, son un conjunto. La relación
muchos a muchos cubre los dos casos con la misma estructura.

## Costo asumido

Aparece un concepto más en la configuración del club, y es un concepto que el
encargado no tiene en la cabeza: nadie piensa en "espacios". La pantalla de
alta de canchas tiene que resolverlo sin nombrarlo —crear una cancha simple
debería crear su espacio sola, y solo al declarar canchas combinables hay que
preguntar algo.

La tabla de ocupaciones es dato derivado, y el dato derivado se puede
desincronizar. La única escritura sobre ella tiene que ser el trigger, nunca la
aplicación.

Requiere la extensión `btree_gist` en la base, que Supabase soporta pero que
hay que acordarse de habilitar en la primera migración.

Mover un turno de horario deja de ser un `update` a una columna: hay que
recalcular las ocupaciones, y por eso también eso vive en el trigger.
