# Django — evidencia de configuración (M3)

App de práctica **real** (CRUD de notas) servida por **Apache + mod_wsgi**,
instrumentada con **django-prometheus** y con `/metrics` **restringido a la red
interna de monitoreo**.

## Estructura

```
django/
├── Dockerfile              # python:3.12-slim + apache2 + mod_wsgi (pip) + mysqlclient
├── apache-site.conf        # VirtualHost :80, WSGIDaemonProcess, /metrics restringido
├── entrypoint.sh           # espera BD → makemigrations → migrate → collectstatic → apache2ctl
├── requirements.txt        # Django<5.1, django-prometheus, mysqlclient, mod_wsgi
└── app/
    ├── manage.py
    ├── config/             # settings.py, urls.py, wsgi.py, __init__.py
    └── notas/              # models, views, urls, apps, migrations/, templates/notas/
```

## settings.py (puntos clave)

- **`SECRET_KEY`** desde `DJANGO_SECRET_KEY` (env). **`DEBUG = False`**.
- **`ALLOWED_HOSTS`**: se parsea `DJANGO_ALLOWED_HOSTS` (coma-separado) y se añaden
  siempre `django-apache`, `localhost` y `127.0.0.1`, de modo que el scrape interno
  de Prometheus (`Host: django-apache`) y el healthcheck (`localhost`) pasen la
  validación de host de Django.
- **`INSTALLED_APPS`** (orden relevante):
  ```python
  INSTALLED_APPS = [
      "django_prometheus",        # arriba
      "django.contrib.admin",
      "django.contrib.auth",
      "django.contrib.contenttypes",
      "django.contrib.sessions",
      "django.contrib.messages",
      "django.contrib.staticfiles",
      "notas",
  ]
  ```
- **`MIDDLEWARE`**: `PrometheusBeforeMiddleware` **primero**, los middlewares estándar
  de Django en medio, `PrometheusAfterMiddleware` **último**:
  ```python
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
  ```
- **`DATABASES`**: backend **`django_prometheus.db.backends.mysql`** (expone métricas
  `django_db_*` de consultas), `NAME/USER/PASSWORD/HOST` desde env, `PORT=3306`,
  `OPTIONS={"charset": "utf8mb4"}`.
- **`STATIC_URL = "/static/"`**, **`STATIC_ROOT = "/app/staticfiles"`**.
- **`ROOT_URLCONF = "config.urls"`**, **`WSGI_APPLICATION = "config.wsgi.application"`**.

## urls.py

```python
urlpatterns = [
    path("", include("django_prometheus.urls")),  # /metrics
    path("", include("notas.urls")),               # lista en /, creación en /crear/
    path("admin/", admin.site.urls),               # opcional
]
```

## Modelo CRUD (`notas/models.py`)

```python
class Nota(models.Model):
    titulo = models.CharField("Título", max_length=200)
    contenido = models.TextField("Contenido")
    creado = models.DateTimeField("Creado", auto_now_add=True)
```

Vistas: `lista_notas` (GET `/`) lista las notas; `crear_nota` (GET/POST `/crear/`)
muestra el formulario y persiste la nota. Plantillas en `notas/templates/notas/`.

## Restricción de `/metrics` (apache-site.conf)

El control de acceso lo hace **Apache**, no Django:

```apache
<Location /metrics>
    Require ip 172.28.0.0/16
</Location>
```

- La red `monitoring` (la fija el integrador con subnet **172.28.0.0/16**) es desde
  donde **Prometheus** scrapea → **PERMITIDO**.
- El tráfico público entra por **NPM** en la red `proxy` (otra subred) → **DENEGADO**.
- Riesgos cubiertos: **APP-1 / APP-3** (no exponer métricas a internet) y **APP-2**
  (un solo proceso WSGI → contadores consistentes).

## mod_wsgi (consistencia de versión de Python)

`Dockerfile` instala `mod_wsgi` vía **pip** (no apt) sobre `python:3.12-slim` y registra
el módulo con:

```dockerfile
RUN mod_wsgi-express module-config > /etc/apache2/mods-available/wsgi.load && a2enmod wsgi
```

así el módulo se enlaza contra **el mismo Python 3.12** que ejecuta Django. El
`WSGIDaemonProcess` usa `processes=1 threads=2` (riesgo APP-2).

## Comandos de evidencia

Desde un contenedor en la red `monitoring` (p.ej. el propio `prometheus`), el scrape
debe responder `200` y mostrar series `django_*`:

```bash
# Desde dentro de la red monitoring (permitido por subnet 172.28.0.0/16):
docker exec prometheus wget -qO- http://django-apache/metrics | head
# o, dentro del propio contenedor django-apache:
docker exec django-apache curl -s http://localhost/metrics | head

# Métricas esperadas (django-prometheus):
#   django_http_requests_total_by_method_total
#   django_http_responses_total_by_status_total
#   django_db_execute_total{...}
#   django_http_requests_latency_seconds_by_view_method_bucket
```

Acceso DENEGADO esperado desde fuera de la subred de monitoreo (NPM/público):
`/metrics` devuelve **403 Forbidden**.

Targets de Prometheus: job `django` → `django-apache:80`, `metrics_path: /metrics`
debe figurar **UP** en `http://localhost:9090/targets` (verificación en M4).
