# Clubio

Panel administrativo para clubes deportivos. Un club entra, configura sus
deportes, canchas y horarios, y desde ahí gestiona turnos, clientes e ingresos.

Estado: **modelo de datos en funcionamiento, sin aplicación todavía**. El
esquema corre en PostgreSQL con dos clubes de demostración y 29 pruebas que
verifican lo que el modelo promete. Lo que hay antes de eso es el
razonamiento, y esa es la parte del trabajo que este repositorio quiere dejar
por escrito.

## Por qué este repo tiene tanta documentación

Clubio no nace de una idea abstracta. Nace de haber operado durante meses un
sistema de reservas real, en un club real, y de haber visto de cerca dónde
duele: dobles ventas que evita una persona acordándose de una regla, turnos
fijos que se cortan sin que nadie se entere, ingresos históricos que cambian
cuando se actualiza una lista de precios.

Ese sistema anterior está documentado en
[docs/05-caso-punto-country.md](docs/05-caso-punto-country.md). Cada decisión
de arquitectura de Clubio se toma contra ese material: se sabe qué falló y por
qué. Las decisiones viven en [docs/decisiones/](docs/decisiones/), una por
archivo, cada una con lo que se descartó y con el costo que se asume al
elegir. El historial de commits está pensado para leerse: cuenta el orden real
en que se pensaron las cosas.

## Cómo leer esto

| Documento | Qué contesta |
|---|---|
| [01-problema.md](docs/01-problema.md) | Qué problema resuelve Clubio y para quién |
| [02-dominio.md](docs/02-dominio.md) | El vocabulario del negocio: qué es una cancha, un espacio, una serie |
| [03-modelo-de-datos.md](docs/03-modelo-de-datos.md) | Las tablas, y por qué cada una existe |
| [04-descubrimiento-club.md](docs/04-descubrimiento-club.md) | Lo que hay que preguntarle a un club antes de darlo de alta |
| [05-caso-punto-country.md](docs/05-caso-punto-country.md) | El sistema anterior: qué aprendimos de operarlo |
| [decisiones/](docs/decisiones/) | Los ADR: una decisión por archivo |
| [db/migraciones/](db/migraciones/) | El esquema, como SQL ejecutable |
| [db/semillas/](db/semillas/) | Dos clubes de demostración para levantar el sistema con datos |
| [db/pruebas/](db/pruebas/) | Las promesas del modelo, comprobadas contra la base |

## Stack

Next.js (App Router) + TypeScript en el frontend, Supabase (PostgreSQL) como
base de datos y autenticación, Vercel para el deploy. El razonamiento está en
[ADR 0008](docs/decisiones/0008-stack.md).

## Alcance de esta etapa

Adentro: turnos, clientes, estadísticas de ingresos y de uso, configuración
del club, marca del club en el panel.

Afuera por ahora: cobros y caja, torneos, bot de WhatsApp, app para el
socio. El bot existe como producto aparte; Clubio no lo asume en el diseño,
aunque tampoco le cierra la puerta (ver [ADR 0002](docs/decisiones/0002-agenda-sin-grilla-pregenerada.md)).
