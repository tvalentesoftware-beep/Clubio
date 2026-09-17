# Clubio — panel web

Next.js 16 (App Router) + TypeScript + Tailwind, sobre Supabase. Las reglas
del negocio no viven acá: viven en [../db](../db). La app lee `fn_disponibilidad`
y pinta; escribe a través de Server Actions, nunca desde el navegador.

## Correr en local

```bash
cp .env.example .env.local   # y completar las dos claves publicas de Supabase
npm install
npm run dev
```

Entra con el usuario creado en Supabase Auth y vinculado por
`db/semillas/0002_usuarios_club.sql`.

## Dónde está cada cosa

| Ruta | Qué es |
|---|---|
| `src/proxy.ts` | Refresca la sesión y manda a `/login` si no hay usuario |
| `src/lib/supabase/` | Clientes de Supabase para servidor y para el proxy |
| `src/lib/club.ts` | El club del usuario logueado |
| `src/lib/semana.ts` | Fechas y horas en la zona horaria del club |
| `src/app/(panel)/` | Todo lo que se ve con la marca del club |
| `src/componentes/grilla-semana.tsx` | La grilla: pinta lo que la base dijo, sin reglas propias |
| `src/componentes/panel-slot.tsx` | El panel lateral de un slot: agendar, editar, cancelar, bloquear |
| `src/app/(panel)/turnos/acciones.ts` | Las escrituras sobre turnos, como Server Actions |
| `src/app/(panel)/clientes/` | Tabla, detalle, lista negra y rankings; leen `vw_clientes_*` |
| `src/app/(panel)/turnos/estadisticas/` | Ingresos del mes, históricos, por deporte y tipo; leen `fn_ingresos*` |
| `src/lib/telefono.ts` | La unica puerta por la que entra un telefono |
