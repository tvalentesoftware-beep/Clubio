# Base de datos

Todo lo que corre en PostgreSQL vive acá, como SQL plano y en orden.

| Carpeta | Qué hay | Cuándo se corre |
|---|---|---|
| `migraciones/` | El esquema y las funciones, numerados | Una vez por base, en orden |
| `semillas/` | Dos clubes ficticios (ADR 0009) | En bases de desarrollo, después de las migraciones |
| `pruebas/` | Las promesas del modelo, comprobadas | Cada vez que se toca algo; terminan en `rollback` |

## Cómo correrlo

Hace falta un `.env` en la raíz del repo con la conexión a Postgres. En
Supabase es la del *Session pooler* (la directa es IPv6 y desde muchas redes
no sale):

```
DATABASE_URL=postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
```

Y luego, en orden:

```bash
pip install "psycopg[binary]"
python db/correr.py db/migraciones/0001_esquema_inicial.sql db/migraciones/0002_disponibilidad.sql db/migraciones/0003_materializar_serie.sql
python db/correr.py db/semillas/0001_clubes_demo.sql
python db/correr.py db/pruebas/0001_reglas_del_modelo.sql db/pruebas/0002_disponibilidad.sql db/pruebas/0003_materializar_serie.sql
```

Si el esquema está bien, la salida de las pruebas es una lista de `OK`. Si
algo se rompió, corta con un `FALLO` que dice cuál.

Estado al 2026-09-15: las tres migraciones y la semilla entran limpias en
Supabase (PostgreSQL 17) y las 29 pruebas pasan.
