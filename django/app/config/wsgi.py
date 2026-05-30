"""
Configuración WSGI del proyecto.

Expone el callable WSGI a nivel de módulo como `application`.
Apache + mod_wsgi importa este módulo (WSGIScriptAlias / /app/config/wsgi.py).
"""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

application = get_wsgi_application()
