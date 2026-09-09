# 0005 — Las tarifas tienen vigencia y el turno congela su precio

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

En el sistema anterior el ingreso de un turno se calculaba en el momento de
mirar el reporte, multiplicando por la tarifa vigente. Cuando el club aumentó
los precios, la facturación de los meses anteriores subió sola.

Un reporte que cambia hacia atrás no sirve para nada, y en un país donde los
precios se actualizan varias veces al año el problema no es teórico: aparece a
los tres meses de usar el sistema.

Hay además un requisito del negocio que la tarifa única no cubre. Al fijo se le
hace precio: paga menos que el que reserva suelto, porque garantiza el horario
todas las semanas. La clase se cobra distinto. Y el sábado a la noche no vale
lo mismo que el martes a las tres de la tarde.

## Decisión

Las tarifas son filas con vigencia: deporte, opcionalmente una cancha
específica, opcionalmente un tipo de turno, un precio y un rango de fechas
desde el cual rige. Aumentar no es editar la tarifa: es cerrar la vigente y
abrir una nueva.

Y sobre todo: **el turno guarda el precio con el que se confirmó**. Esa columna
no se recalcula nunca. Las estadísticas de ingresos suman precios guardados, no
resuelven tarifas.

## Alternativas descartadas

**Un precio por cancha, en la tabla de canchas.** Es una columna y se entiende
sola, pero es exactamente lo que había: no tiene historia, no distingue al fijo
del suelto y obliga a que el reporte mienta o a inventar una corrección aparte.

**Guardar solo la referencia a la tarifa y resolver el precio al leer.** Es
formalmente más limpio —el dato vive en un solo lugar— y se descarta por dos
motivos prácticos. Cada consulta de ingresos pasa a depender de resolver
vigencias, que es la clase de lógica que se escribe mal una vez y contamina
todos los números. Y no contempla la excepción, que en un club es habitual: al
cliente de años se le cobra distinto, y ese precio no es ninguna tarifa.

**No guardar precios y llevar la plata en una caja.** Es lo correcto el día que
Clubio tenga cobros, y está explícitamente fuera del alcance de esta versión.
El club quiere saber cuánto facturó, no llevar la contabilidad.

## Costo asumido

El precio queda escrito en dos lugares —en la tarifa y en cada turno— y pueden
diferir. Es redundancia deliberada, pero significa que cargar una tarifa
equivocada y darse cuenta a la semana obliga a corregir los turnos ya
confirmados con un `update` consciente y acotado, no con arreglar una fila.

Un turno cargado con mucha anticipación congela el precio de hoy para una fecha
en la que la tarifa va a ser otra. Para el club eso suele ser lo correcto —el
precio pactado es el del día que se reservó— pero es una decisión de negocio
que conviene que el club conozca, no un detalle técnico.

La resolución de qué tarifa aplica cuando hay varias candidatas (una general
del deporte y una específica de la cancha) necesita una regla de precedencia
explícita, escrita en un solo lugar y probada.
