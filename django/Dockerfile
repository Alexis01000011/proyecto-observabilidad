# Django + Apache (mod_wsgi) — ESQUELETO (M0).
# La app real y el cableado de django-prometheus se construyen en M3.
FROM python:3.12-slim

# TODO (M3): apache2 + libapache2-mod-wsgi-py3, copiar el proyecto Django,
# instalar requirements, configurar el vhost y exponer /metrics restringido.

WORKDIR /app
COPY requirements.txt .
# RUN pip install --no-cache-dir -r requirements.txt   # se activa en M3

# Placeholder para que la imagen tenga un CMD válido hasta M3.
CMD ["python", "-c", "print('django-apache: esqueleto M0; app real en M3'); import time; time.sleep(86400)"]
