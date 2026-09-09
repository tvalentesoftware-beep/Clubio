# 0006 — El teléfono identifica al cliente, pero no es la clave primaria

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

El brief dice, textualmente, que el cliente se identifica con el teléfono y que
ese es el `pkey`. La primera mitad de la frase es correcta y describe cómo
funciona el negocio: el encargado no pide DNI ni email, pide un nombre y un
número, y ese número es lo que usa para reconocer al que llama.

La segunda mitad es una decisión técnica que conviene mirar antes de aceptarla,
porque una clave primaria es lo único de una tabla que después no se cambia sin
dolor.

## Decisión

El cliente tiene una clave primaria propia y opaca. El teléfono se guarda
normalizado en formato internacional y lleva un índice único **por club**: dos
clientes del mismo club no pueden compartir número, y el mismo número en dos
clubes son dos clientes distintos, cada uno con su historial, coherente con el
aislamiento del [ADR 0001](0001-multi-tenant-modelo-pool.md).

Dicho de otro modo: el teléfono es la clave del negocio y así se usa en la
pantalla —se busca por teléfono, se carga por teléfono—, pero las demás tablas
apuntan a la clave interna.

## Alternativas descartadas

**El teléfono como clave primaria real.** Se descarta por lo que pasa cuando
alguien cambia de número, que es común: con el teléfono como clave hay que
propagar el cambio a cada turno, cada serie y cada evento del historial, o
resignarse a que el cliente quede partido en dos personas. Con una clave
interna, cambiar de número es editar una columna.

Hay un segundo motivo, más silencioso: el teléfono se escribe distinto cada
vez, y una clave primaria que a veces es `3425123456` y a veces
`+54 342 512-3456` produce clientes duplicados que después hay que fusionar a
mano.

**Documento o email como identificador.** Ningún club los pide para alquilar
una cancha. Un identificador que el usuario no va a cargar es un campo vacío
con aire de rigor.

## Costo asumido

Normalizar teléfonos argentinos es un trabajo aburrido y lleno de casos: el 0
de larga distancia, el 15 del celular, el 9 después del código de país, los
números viejos de ocho dígitos. Hay que hacerlo en un solo lugar, en la
escritura, y probarlo con casos reales. Si se hace mal, el índice único no
alcanza y vuelven los duplicados por otra puerta.

Dos personas que comparten teléfono —una pareja, dos hermanos del mismo
equipo— son un solo cliente para el sistema. Es aceptable: el que reserva es
uno solo, y es el que responde si hay que llamar.

El mismo cliente en dos clubes no tiene identidad compartida. Es consecuencia
directa del modelo multi-club elegido y no se considera un problema: ningún
club quiere que otro vea el historial de su gente.

Queda pendiente, para cuando aparezca, una operación de fusionar dos clientes
cargados dos veces con números distintos. No entra ahora, pero el modelo la
permite justamente porque la clave es interna.
