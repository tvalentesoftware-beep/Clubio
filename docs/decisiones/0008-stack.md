# 0008 — Next.js con TypeScript sobre Supabase

- **Fecha:** 2026-09-08
- **Estado:** aceptada

## Contexto

Las decisiones anteriores le piden cosas concretas a la base de datos:
restricciones de exclusión sobre rangos de tiempo ([ADR 0003](0003-espacios-compartidos.md)),
seguridad a nivel de fila para el aislamiento entre clubes
([ADR 0001](0001-multi-tenant-modelo-pool.md)) y funciones que resuelvan la
disponibilidad del lado del servidor ([ADR 0002](0002-agenda-sin-grilla-pregenerada.md)).
Eso ya recorta el campo: hace falta PostgreSQL de verdad, no una capa de datos
que lo imite.

Del lado de la aplicación, el requisito dominante es que el panel se sienta
inmediato para alguien que está atendiendo el teléfono, y que un club nuevo se
dé de alta sin desplegar nada.

## Decisión

Next.js con App Router y TypeScript, desplegado en Vercel. Supabase como
PostgreSQL administrado, con su capa de autenticación y las políticas de RLS
escritas a mano.

La regla de reparto: las reglas del negocio viven en la base —restricciones,
funciones, triggers—, la aplicación orquesta y presenta. Las operaciones de
escritura pasan por el servidor de Next, no por el navegador, para que la
lógica no dependa de que el cliente la respete.

## Alternativas descartadas

**Vite con JavaScript sin tipos**, que es el stack del sistema anterior. Se
arranca más rápido porque ya se conoce, y se descarta por tres cosas: no hay
servidor donde poner nada, así que toda la lógica termina en el navegador con
la clave anónima; sin tipos, un modelo con catorce tablas y claves compuestas
se vuelve una sucesión de errores en tiempo de ejecución; y el repositorio, que
también es una pieza de portfolio, mostraría menos criterio del que hay.

**Un backend propio con Node y una base administrada.** Más control y ninguna
atadura a un proveedor, a cambio de escribir autenticación, gestión de sesión y
despliegue, que es exactamente el trabajo que no diferencia a este producto.

**Un framework de servidor tradicional**, tipo Django o Rails, con su panel de
administración casi gratis. La contra es que el panel administrativo genérico
no se parece a lo que este producto necesita —una grilla semanal que se opera
con el teléfono en la mano— y que sería el primer proyecto en ese stack, con el
costo de aprendizaje encima del costo de construir.

## Costo asumido

Hay dependencia de un proveedor para autenticación y para la API de datos.
Migrar la base es viable porque es PostgreSQL estándar; migrar la
autenticación es un trabajo real que habría que hacer entero.

RLS pasa a ser una barrera crítica y no una red de seguridad: cualquier
consulta que llegue desde el navegador solo está protegida por la política. Eso
obliga a probar el aislamiento entre clubes como una funcionalidad más, con
casos que intenten ver lo ajeno.

El plan gratuito de Supabase pausa los proyectos inactivos, lo cual es
irrelevante para un club en uso pero molesta durante el desarrollo. El espacio
no es preocupación: el sistema anterior, con dos años de operación real, usaba
catorce megabytes de los quinientos disponibles.

Next.js es más máquina de la que este panel necesita, y trae su propia
complejidad —qué corre en el servidor y qué en el cliente, cachés,
revalidación— que hay que entender para no pelearse con ella.
