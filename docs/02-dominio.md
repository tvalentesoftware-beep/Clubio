# El vocabulario del dominio

Buena parte de los problemas del sistema anterior se explican por dos palabras
que se usaban como si fueran una sola. Antes de modelar nada, entonces, hay que
fijar qué significa cada término en Clubio. Este es el vocabulario que usan el
esquema, el código y las pantallas: si en algún lado dice "cancha", quiere
decir exactamente lo que dice acá.

## Club

El cliente de Clubio. Es la unidad de aislamiento: todo dato pertenece a un
club y nadie ve datos de otro. Un club tiene su nombre, su logo, sus colores y
su zona horaria, y el panel se muestra con su marca, no con la de Clubio.

## Deporte

Fútbol 5, pádel, tenis. Define cuánto dura un turno por defecto —el fútbol se
juega por hora, el pádel por hora y media— y es la primera dimensión por la que
el club mira sus números.

## Espacio

**El metro cuadrado.** Un pedazo de piso que no puede estar ocupado por dos
cosas a la vez. El espacio no se reserva ni se muestra en pantalla: es la
unidad física contra la que se resuelven los conflictos.

## Cancha

**Lo que se vende.** "Fútbol 5 — Cancha 2", "Pádel 1". Es lo que el cliente
pide, lo que aparece en la grilla y lo que tiene precio.

Una cancha ocupa uno o más espacios, y acá está el punto entero: la cancha de
fútbol 8 ocupa los tres espacios que también ocupan, de a uno, las tres canchas
de fútbol 5. Son cuatro canchas sobre tres espacios. Vender la grande deja las
tres chicas sin lugar, y vender cualquiera de las chicas deja la grande sin
lugar, porque el pasto es el mismo. Separar "lo que se vende" de "lo que se
ocupa" es lo que permite que esa regla la sostenga la base de datos en vez de
la memoria del encargado.

Un club sin canchas combinables —lo más común— simplemente tiene un espacio por
cancha y nunca se entera de que la distinción existe.

## Franja de apertura

Los días y horas en que una cancha se puede reservar. Se declara por cancha y
por día de la semana, con vigencia: "pádel 1, los lunes, de 14:30 a 22:30,
desde el 1 de marzo". Reemplaza a la grilla pre-generada del sistema anterior.
Que el pádel abra distinto los lunes que los miércoles deja de ser una rareza
del generador y pasa a ser dos filas de configuración.

## Turno

Una reserva concreta: una cancha, un cliente, un desde y un hasta. Es de un
tipo —normal, fijo o clase—, tiene un estado y guarda el precio que se cobró.

## Serie

La regla de repetición de un fijo o una clase: "este cliente, esta cancha, los
sábados a las 20, desde marzo, sin fecha de fin". Los turnos concretos se
derivan de la serie y saben de qué serie vienen. Dar de baja un fijo es
terminar la serie, y faltar un sábado puntual es cancelar un turno sin tocar
la serie. Son dos operaciones distintas porque son dos cosas distintas.

## Cierre

El club decide que algo no se puede reservar: vacaciones, mantenimiento,
lluvia, un evento privado. Puede alcanzar a una cancha o al club entero,
durante un rato o durante dos semanas.

Un cierre **no** es un turno. En el sistema anterior ambos vivían en la misma
fila con el nombre `BLOQUEADO`, y eso hacía imposible distinguir una decisión
comercial de un efecto colateral. Acá el cierre es una decisión explícita del
club, y la indisponibilidad que produce una reserva de la cancha vecina se
llama de otra manera.

## Ocupación

El rastro que deja un turno sobre cada espacio que usa, durante el rango de
tiempo que dura. Es información derivada: nadie la carga, se calcula sola. Es
también donde la base impide, físicamente, que dos turnos pisen el mismo
espacio al mismo tiempo.

Cuando el panel muestra que la cancha de fútbol 8 no está disponible el sábado
a las 20, es porque hay una ocupación ahí, y el panel puede decir de dónde
viene: hay fútbol 5 vendido en la cancha 2. Eso es una explicación, no un turno
fantasma.

## Cliente

Quien reserva. Se lo identifica por su teléfono dentro del club, porque es el
único dato que el encargado siempre tiene y siempre pide. Acumula historial:
turnos jugados, cuánto dejó, cuántas veces canceló.

## Lista negra

Un cliente al que el club decide no tomarle más reservas, con el motivo
escrito. Es una marca sobre el cliente, no una baja: el historial se conserva.

## Tarifa

Cuánto sale un turno, con fecha de vigencia. Cuando el club aumenta, la tarifa
vieja no se edita: se cierra y se abre una nueva. El turno ya jugado guarda el
precio que se cobró y no vuelve a calcularse nunca.
