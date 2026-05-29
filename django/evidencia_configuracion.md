# Django — evidencia de configuración

> Placeholder (M0). Se completa en M3/M8 con la configuración real de
> `django-prometheus` y capturas de `/metrics`.

## Pendiente de documentar (M3)
- `requirements.txt` con `django-prometheus`.
- `INSTALLED_APPS` incluye `django_prometheus`.
- `MIDDLEWARE`: `PrometheusBeforeMiddleware` (primero) y `PrometheusAfterMiddleware` (último).
- `urls.py`: `path("", include("django_prometheus.urls"))`.
- Restricción de `/metrics` a la red interna (riesgo APP-3).
- Evidencia: `curl http://django-apache/metrics`.
