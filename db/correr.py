"""Aplica archivos SQL contra la base de DATABASE_URL, en el orden dado.

    python db/correr.py db/migraciones/0001_esquema_inicial.sql db/semillas/0001_clubes_demo.sql

Migraciones y semillas corren cada una dentro de una transaccion: si algo
falla a mitad de camino no queda nada a medias. Los archivos de db/pruebas/
manejan su propia transaccion (terminan en rollback), asi que se mandan tal
cual. Los RAISE NOTICE de las pruebas se imprimen a medida que llegan.

Requiere: pip install "psycopg[binary]"  y un .env con DATABASE_URL.
"""

import os
import sys
from pathlib import Path

import psycopg

RAIZ = Path(__file__).resolve().parent.parent


def leer_env():
    env = RAIZ / ".env"
    if not env.exists():
        sys.exit("falta .env con DATABASE_URL (ver README de db/)")
    for linea in env.read_text(encoding="utf-8").splitlines():
        if linea.startswith("DATABASE_URL="):
            return linea.split("=", 1)[1].strip()
    sys.exit("el .env no tiene DATABASE_URL")


def correr(url, archivo):
    sql = archivo.read_text(encoding="utf-8")
    es_prueba = "pruebas" in archivo.parts
    print(f"\n== {archivo.relative_to(RAIZ)}")
    with psycopg.connect(url, autocommit=True) as conn:
        conn.add_notice_handler(lambda n: print("  ", n.message_primary))
        if es_prueba:
            conn.execute(sql)
        else:
            with conn.transaction():
                conn.execute(sql)
    print("   ok")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    url = os.environ.get("DATABASE_URL") or leer_env()
    for ruta in sys.argv[1:]:
        try:
            correr(url, Path(ruta).resolve())
        except psycopg.Error as e:
            print(f"   ERROR: {e}".rstrip())
            sys.exit(1)
