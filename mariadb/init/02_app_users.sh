#!/bin/bash
# ==========================================================================
# 02_app_users.sh — provisioning de usuarios de MariaDB (M3)
#
# El entrypoint de la imagen oficial de MariaDB ejecuta todo lo que esté en
# /docker-entrypoint-initdb.d UNA SOLA VEZ, en el PRIMER arranque del volumen
# (cuando /var/lib/mysql está vacío), en orden lexicográfico. Por eso este
# script corre DESPUÉS de 01_databases.sql (las BDs ya existen) y se ejecuta
# con las variables de entorno del contenedor disponibles — el integrador las
# puebla desde .env en el servicio `mariadb` del docker-compose.yml.
#
# Crea, de forma idempotente, los usuarios de las apps (Django, WordPress) y
# el usuario de monitoreo del mysqld-exporter, tomando sus contraseñas REALES
# del entorno (nunca versionadas). Si alguna variable falta, se omite ESE
# usuario con un aviso, sin abortar el resto del init.
#
# Auth: nativa de MariaDB (IDENTIFIED BY). Host comodín '%' porque las apps se
# conectan desde OTROS contenedores de la red 'monitoring' (no localhost).
# ==========================================================================
set -e

# Cliente y credencial de root: ambos los provee el entrypoint de MariaDB.
# (MARIADB_ROOT_PASSWORD ya está seteada en este punto del init.)
mariadb_root() {
    mariadb -u root -p"$MARIADB_ROOT_PASSWORD" "$@"
}

# Crea un usuario de aplicación con TODOS los privilegios sobre SU base de datos.
# Args: <nombre_usuario> <password> <nombre_bd> <etiqueta>
create_app_user() {
    local user="$1" pass="$2" db="$3" label="$4"

    if [ -z "$user" ] || [ -z "$pass" ] || [ -z "$db" ]; then
        echo >&2 "[02_app_users] AVISO: variables incompletas para '${label}' (user='${user}', db='${db}'); se omite este usuario."
        return 0
    fi

    echo "[02_app_users] Creando usuario de ${label}: '${user}'@'%' con acceso a la BD '${db}'."
    mariadb_root <<-EOSQL
		CREATE USER IF NOT EXISTS '${user}'@'%' IDENTIFIED BY '${pass}';
		ALTER USER '${user}'@'%' IDENTIFIED BY '${pass}';
		GRANT ALL PRIVILEGES ON \`${db}\`.* TO '${user}'@'%';
	EOSQL
}

# ---- Usuario de Django ----
create_app_user "$DJANGO_DB_USER" "$DJANGO_DB_PASSWORD" "$DJANGO_DB_NAME" "Django"

# ---- Usuario de WordPress ----
create_app_user "$WORDPRESS_DB_USER" "$WORDPRESS_DB_PASSWORD" "$WORDPRESS_DB_NAME" "WordPress"

# ---- Usuario de monitoreo (mysqld-exporter v0.14, privilegio mínimo, riesgo DOK-3) ----
# Si EXPORTER_DB_USER no está definida, usa 'exporter' por defecto (coherente con .env.example).
EXPORTER_USER="${EXPORTER_DB_USER:-exporter}"
if [ -z "$EXPORTER_DB_PASSWORD" ]; then
    echo >&2 "[02_app_users] AVISO: EXPORTER_DB_PASSWORD vacía; se omite el usuario de monitoreo '${EXPORTER_USER}'."
else
    echo "[02_app_users] Creando usuario de monitoreo: '${EXPORTER_USER}'@'%' (PROCESS, REPLICATION CLIENT, SELECT)."
    mariadb_root <<-EOSQL
		CREATE USER IF NOT EXISTS '${EXPORTER_USER}'@'%' IDENTIFIED BY '${EXPORTER_DB_PASSWORD}';
		ALTER USER '${EXPORTER_USER}'@'%' IDENTIFIED BY '${EXPORTER_DB_PASSWORD}';
		GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${EXPORTER_USER}'@'%';
	EOSQL
fi

# Aplica todos los cambios de privilegios de una sola vez.
mariadb_root <<-EOSQL
	FLUSH PRIVILEGES;
EOSQL

echo "[02_app_users] Provisioning de usuarios completado."
