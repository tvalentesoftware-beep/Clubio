# 0004 — Un turno fijo es una regla, no cincuenta copias

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

Los fijos son el corazón del ingreso de un club: el mismo grupo, la misma
cancha, todas las semanas. En el sistema anterior no existían como concepto.
Había una casilla "fijo" y un trigger que, al tildarla, copiaba el nombre del
cliente hacia adelante hasta donde llegara la grilla en ese momento.

El resultado fue que dos clientes con el mismo acuerdo comercial quedaron con
cinco y con cincuenta y cinco apariciones, según cuándo los hubieran tildado. Y
que la mayoría de los fijos reales del club ni siquiera estaban tildados: los
cargaba el encargado a mano, semana por semana, porque una vez copiadas las
filas no había ninguna diferencia entre un fijo y cincuenta turnos sueltos que
casualmente tienen el mismo nombre. La pregunta "quiénes son mis fijos" no
tenía respuesta en la base de datos.

## Decisión

La serie es una entidad: guarda el cliente, la cancha, el día de la semana, la
hora, la duración, desde cuándo rige y —si se sabe— hasta cuándo. Los turnos
concretos se generan a partir de ella y guardan de qué serie vienen.

La generación es con horizonte rodante: se materializan las próximas semanas,
no el infinito. Se dispara al crear o editar la serie y se refresca
periódicamente.

Dos operaciones distintas, porque son dos cosas distintas: **dar de baja el
fijo** es cerrar la serie, y a partir de esa fecha no se generan más turnos;
**faltar un sábado** es cancelar ese turno, y la serie sigue.

El agujero conocido de este esquema es el borde del horizonte: un sábado más
allá de lo materializado se vería libre y se podría vender encima de un fijo
vigente. Por eso la función de disponibilidad —la única del sistema, según el
[ADR 0002](0002-agenda-sin-grilla-pregenerada.md)— consulta también las series
activas y no ofrece un horario que caiga bajo una serie vigente, esté o no
materializado. El horizonte afecta lo que se ve en la grilla, nunca lo que se
puede vender.

## Alternativas descartadas

**Copiar filas hacia adelante al tildar la casilla**, como el sistema anterior.
El alcance de la copia depende del momento en que se tildó, que es un dato sin
ningún significado para el negocio. Y una vez copiadas, la regla se pierde: no
queda registrado en ningún lado que ese cliente es un fijo.

**No materializar nada y resolver todo al vuelo desde las reglas.** Es lo más
limpio en el papel y se cae en la práctica: el turno del sábado que viene tiene
que poder editarse —cambió el horario esa semana, viene otro cliente, se cobró
distinto— y no se puede editar lo que no existe como fila. Además, sin turnos
materializados, la restricción de exclusión del
[ADR 0003](0003-espacios-compartidos.md) no tiene sobre qué actuar, y el
conflicto entre un fijo y una reserva suelta recién aparecería a la hora de
jugar.

**Materializar hasta el infinito.** No hay infinito con una serie sin fecha de
fin, que es el caso normal.

## Costo asumido

Hay dos fuentes que dicen cosas sobre el mismo sábado: la serie y el turno ya
materializado. Manda el turno materializado —si existe una fila, esa fila es la
verdad—, y esa regla de precedencia hay que sostenerla en cada consulta que
cruce las dos cosas. Es la parte del modelo con más riesgo de contradecirse.

Editar una serie con turnos ya generados obliga a decidir qué pasa con lo
existente: solo de acá en adelante, sin tocar lo pasado, y sin pisar turnos que
alguien haya editado a mano. Es una operación que hay que escribir con cuidado
y probar bien.

Aparece una tarea periódica de la que el sistema depende. Vale la aclaración de
arriba: si se cae, el club ve menos semanas en la grilla, pero no puede vender
encima de un fijo. El modo de falla es visible y no es una doble venta.
