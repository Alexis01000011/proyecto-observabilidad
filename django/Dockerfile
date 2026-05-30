# Django + Apache (mod_wsgi) — app real de práctica (M3).
#
# Se usa python:3.12-slim para que mod_wsgi se COMPILE vía pip contra la MISMA
# versión de Python que ejecuta la app. Así se evita el mismatch del paquete
# libapache2-mod-wsgi-py3 de apt (que se enlaza contra otra versión de Python).
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DJANGO_SETTINGS_MODULE=config.settings

# Dependencias de sistema:
#  - apache2 / apache2-dev: servidor web + headers para compilar mod_wsgi (pip).
#  - default-libmysqlclient-dev / build-essential / pkg-config: para compilar mysqlclient.
#  - curl: healthcheck y evidencia (curl http://localhost/metrics).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apache2 \
        apache2-dev \
        default-libmysqlclient-dev \
        build-essential \
        pkg-config \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instala dependencias de Python (incluye mod_wsgi compilado para python3.12).
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Registra el módulo mod_wsgi recién compilado en Apache.
# `mod_wsgi-express module-config` imprime el LoadModule + WSGIPythonHome correctos
# apuntando al Python de la imagen (/usr/local).
RUN mod_wsgi-express module-config > /etc/apache2/mods-available/wsgi.load \
    && a2enmod wsgi

# Código de la app.
COPY app /app

# VirtualHost de la app (puerto 80) con /metrics restringido a la red interna.
COPY apache-site.conf /etc/apache2/sites-available/000-django.conf
RUN a2dissite 000-default \
    && a2ensite 000-django

# Entrypoint: espera la BD, migra, collectstatic y arranca Apache en foreground.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]
