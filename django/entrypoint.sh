#!/bin/bash
# Entrypoint de la app Django + Apache.
# Espera a MariaDB, aplica migraciones, recolecta estáticos y arranca Apache.
set -e

DB_HOST="${DJANGO_DB_HOST:-mariadb}"
DB_PORT=3306

echo "[entrypoint] Esperando a ${DB_HOST}:${DB_PORT} ..."
for i in $(seq 1 30); do
    # /dev/tcp es una característica de bash: abre el socket sin netcat.
    if (echo > "/dev/tcp/${DB_HOST}/${DB_PORT}") >/dev/null 2>&1; then
        echo "[entrypoint] Base de datos accesible."
        break
    fi
    echo "[entrypoint] intento ${i}/30: BD no lista, reintentando en 2s..."
    sleep 2
    if [ "$i" -eq 30 ]; then
        echo "[entrypoint] ERROR: ${DB_HOST}:${DB_PORT} no respondió tras 30 intentos." >&2
        exit 1
    fi
done

cd /app

echo "[entrypoint] makemigrations notas..."
python manage.py makemigrations notas --noinput

echo "[entrypoint] migrate..."
python manage.py migrate --noinput

echo "[entrypoint] collectstatic..."
python manage.py collectstatic --noinput

echo "[entrypoint] Arrancando Apache en foreground..."
exec apache2ctl -D FOREGROUND
