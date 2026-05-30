"""
URLs raíz del proyecto.

- "" → app `notas` (CRUD de la práctica).
- "" → `django_prometheus.urls` expone /metrics (restringido por Apache a la red
  interna; ver apache-site.conf).
- "admin/" → admin de Django (opcional, útil para demostrar tráfico/consultas).
"""

from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    # /metrics (django-prometheus). El control de acceso lo hace Apache (<Location /metrics>).
    path("", include("django_prometheus.urls")),
    # App de práctica: lista en / y creación en /crear/.
    path("", include("notas.urls")),
    # Admin opcional.
    path("admin/", admin.site.urls),
]
