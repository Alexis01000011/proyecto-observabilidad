"""
Configuración de Django para la app de práctica de observabilidad.

App mínima pero real (CRUD de notas) instrumentada con django-prometheus.
Toda la configuración sensible se lee de variables de entorno (ver docker-compose.yml
y .env.example). No hay secretos en este archivo.
"""

import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Seguridad
# ---------------------------------------------------------------------------
# SECRET_KEY desde el entorno; el fallback solo evita un crash en builds locales
# sin .env (la imagen real siempre recibe DJANGO_SECRET_KEY).
SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "insecure-build-time-key-change-me")

DEBUG = False

# ALLOWED_HOSTS desde env (coma-separado) + los nombres internos necesarios para
# que el scrape de Prometheus (Host: django-apache) y los healthchecks (localhost,
# 127.0.0.1) pasen la validación de host de Django.
_env_hosts = os.environ.get("DJANGO_ALLOWED_HOSTS", "")
ALLOWED_HOSTS = [h.strip() for h in _env_hosts.split(",") if h.strip()]
for _internal in ("django-apache", "localhost", "127.0.0.1"):
    if _internal not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(_internal)

# ---------------------------------------------------------------------------
# Aplicaciones
# ---------------------------------------------------------------------------
INSTALLED_APPS = [
    # django_prometheus debe ir arriba para registrar sus señales/migraciones.
    "django_prometheus",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "notas",
]

# ---------------------------------------------------------------------------
# Middleware
# ---------------------------------------------------------------------------
# PrometheusBeforeMiddleware DEBE ser el PRIMERO y PrometheusAfterMiddleware el
# ÚLTIMO para medir correctamente latencia/contadores de todas las requests.
MIDDLEWARE = [
    "django_prometheus.middleware.PrometheusBeforeMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "django_prometheus.middleware.PrometheusAfterMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# ---------------------------------------------------------------------------
# Base de datos
# ---------------------------------------------------------------------------
# Backend de django_prometheus para MySQL/MariaDB: instrumenta las consultas y
# expone métricas django_db_* además de las de request.
DATABASES = {
    "default": {
        "ENGINE": "django_prometheus.db.backends.mysql",
        "NAME": os.environ.get("DJANGO_DB_NAME", "djangodb"),
        "USER": os.environ.get("DJANGO_DB_USER", "django"),
        "PASSWORD": os.environ.get("DJANGO_DB_PASSWORD", ""),
        "HOST": os.environ.get("DJANGO_DB_HOST", "mariadb"),
        "PORT": "3306",
        "OPTIONS": {
            "charset": "utf8mb4",
        },
    }
}

# ---------------------------------------------------------------------------
# Validación de contraseñas
# ---------------------------------------------------------------------------
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# ---------------------------------------------------------------------------
# Internacionalización
# ---------------------------------------------------------------------------
LANGUAGE_CODE = "es"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# ---------------------------------------------------------------------------
# Archivos estáticos
# ---------------------------------------------------------------------------
STATIC_URL = "/static/"
STATIC_ROOT = "/app/staticfiles"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
