# El caso que da origen a Clubio

Antes de Clubio hubo un sistema administrativo hecho a medida para un club de
fútbol y pádel: tres canchas de fútbol 5, una de fútbol 8, tres de pádel, un
encargado, un panel web y —más tarde— un bot de WhatsApp que tomaba reservas
solo. Estuvo y sigue estando en producción. Funciona.

Este documento no es una lista de errores ajenos. Es el registro de lo que
aprendí operándolo, porque cada decisión de Clubio se toma contra esta
experiencia y no contra un manual. Los datos concretos que aparecen acá están
anonimizados: no hay nombres de clientes del club ni identificadores de
infraestructura.

## Cómo estaba construido

La tabla de reservas no se llenaba al reservar. Era una **grilla
pre-generada**: existía de antemano una fila por cada combinación posible de
fecha, hora, deporte y cancha, y reservar significaba hacer un `UPDATE` sobre
esa fila. Liberar un turno era poner el nombre y el teléfono en `null`. El
molde eran 47 filas por día, y se extendió una vez hasta cubrir un año
completo: diecisiete mil filas insertadas de una sentada.

La idea tiene una virtud que no hay que subestimar: la pantalla del encargado
es literalmente la tabla. Se lee como un Excel porque **es** un Excel. Para un
club chico y un desarrollo rápido, eso resolvió el problema real.

## Los cinco lugares donde se rompió

**Una cancha era tres canchas.** La cancha de fútbol 8 es físicamente el mismo
pasto que las tres de fútbol 5. No son recursos distintos. Reservar la grande
tiene que dejar las tres chicas fuera de circulación, y reservar una sola
chica tiene que dejar la grande fuera. En la base eso se resolvió con una
segunda fila marcada como `BLOQUEADO`, escrita por un trigger. Pero ni la
pantalla ni el bot conocían la regla: la consulta de disponibilidad filtraba
por el deporte pedido y podía ofrecer fútbol 8 con las tres de fútbol 5 ya
vendidas. Que no se haya vendido nunca dos veces el mismo pasto —lo verifiqué
sobre toda la tabla: 175 franjas bloqueadas de un lado y 28 del otro, cero
excepciones— no es mérito del sistema. Es mérito de la persona que opera el
panel y se acuerda.

**Los turnos fijos no existían como concepto.** El cliente que juega todos los
sábados a las 20 no estaba modelado como "juega todos los sábados". Un trigger
copiaba su nombre hacia adelante en el momento en que alguien tildaba la
casilla "fijo", hasta donde llegara la grilla en ese momento. Consecuencias:
un cliente marcado antes de extender la grilla quedó con cinco apariciones y
otro marcado después quedó con cincuenta y cinco, sin que nadie hiciera nada
distinto. Y la mayoría de los fijos del club ni siquiera estaban tildados: los
cargaba el encargado a mano, semana por semana, porque el trigger empujaba al
marcar y no había forma de mirar la base y saber quiénes eran los fijos.

**`BLOQUEADO` significaba dos cosas.** A veces era el club cerrando la cancha
—vacaciones, mantenimiento, lluvia— y a veces era la contracara automática de
una reserva del otro deporte. Mismo valor en la misma columna para una
decisión comercial y para un efecto derivado. Cualquier estadística que contara
turnos u ocupación tenía que empezar por adivinar cuál de las dos era.

**El precio vivía en el código.** El ingreso de un turno se calculaba
multiplicando por la tarifa vigente hoy. Cuando el club aumentó, el ingreso
histórico de marzo cambió solo. Un reporte que cambia hacia atrás no es un
reporte.

**Nada era multi-club.** El deporte, las canchas, los horarios y los precios
estaban horneados en la estructura: la variación de pádel por día de la semana
—tres patrones distintos de horarios según fuera lunes, miércoles o el resto—
estaba escrita en el generador de la grilla. Vender el mismo sistema a un
segundo club significaba duplicar el proyecto entero y editarlo.

## Qué se lleva Clubio de acá

Que la pantalla parezca un Excel es un requisito del producto y se respeta.
Que la base **sea** un Excel es lo que hay que dejar atrás: las reglas del
negocio tienen que estar en el modelo y no en la memoria del encargado, la
disponibilidad tiene que salir de un solo lugar, y un dato de dos años atrás
tiene que seguir diciendo lo mismo dentro de dos años más.
