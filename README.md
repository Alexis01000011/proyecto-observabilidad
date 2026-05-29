# observabilidad-devops

Plataforma de observabilidad (**Prometheus + Grafana + Alertmanager + exporters**) sobre
**AWS EC2 con Docker**, que monitorea el host, los contenedores y 4 aplicaciones
(Django/Apache, Java/Tomcat, WordPress, MariaDB), con alertas por correo, dashboards en
Grafana y pruebas de fallo provocado.

> **Estado:** M0 (scaffolding). El cableado fino, las apps y los dashboards se completan en
> los milestones siguientes. Plan completo en `../PLAN.md`; práctica fuente en `../ENUNCIADO.md`.

## Arquitectura

```
Internet ─► Cloudflare (DNS + proxy) ─► EC2 (Debian, SSH:6655)
                                          ├── Nginx Proxy Manager (80/443)  ── reverse proxy + TLS
                                          │     ├─ grafana.notalexispage.online   → grafana:3000
                                          │     ├─ django.notalexispage.online    → django-apache:80
                                          │     ├─ tomcat.notalexispage.online    → tomcat:8080
                                          │     └─ wordpress.notalexispage.online → wordpress:80
                                          └── docker compose (red: monitoring)
                                               ├─ OBSERVABILIDAD: prometheus · grafana · alertmanager
                                               │                  node_exporter · cadvisor
                                               │                  mysqld-exporter · blackbox_exporter
                                               └─ APLICACIONES:   django-apache · tomcat(+jmx)
                                                                  wordpress · mariadb
```

## Servicios y exposición

| Servicio | Puerto interno | Exposición |
|----------|:--:|------------|
| Grafana | 3000 | Pública (NPM + Cloudflare) |
| Django / Apache | 80 | Pública (NPM); `/metrics` restringido |
| Tomcat | 8080 | Pública (NPM) |
| WordPress | 80 | Pública (NPM) |
| Prometheus | 9090 | Interno (túnel SSH) |
| Alertmanager | 9093 | Interno (túnel SSH) |
| node_exporter · cAdvisor · mysqld-exporter · JMX · blackbox | 9100 / 8080 / 9104 / 9404 / 9115 | Internos (red Docker) |
| MariaDB | 3306 | No público |

## Estructura del repo

```
observabilidad-devops/
├── docker-compose.yml         # todos los servicios
├── .env.example               # variables (copiar a .env, NO versionar)
├── prometheus/                # prometheus.yml + rules/alerts.yml
├── alertmanager/              # alertmanager.yml (SMTP por archivo, sin secreto)
├── blackbox/                  # blackbox.yml (sonda http_2xx)
├── grafana/                   # provisioning + dashboards
├── mariadb/                   # usuario_exporter.sql + init/
├── django/  tomcat/           # builds + evidencia_configuracion.md
└── evidencias/                # capturas 01..09
```

## Despliegue (resumen; se detalla en M8)

```bash
# 0) Red compartida con Nginx Proxy Manager (una sola vez en el host; idempotente)
docker network create proxy || true

# 1) Configurar secretos (NO se versionan)
cp .env.example .env            # y rellenar valores reales (mínimo: DOMAIN, GF_SECURITY_ADMIN_USER/PASSWORD)
mkdir -p secrets && printf '%s' '<APP_PASSWORD_GMAIL>' > secrets/smtp_password   # placeholder hasta M5
chmod 600 secrets/smtp_password

# 2) Validar y levantar
docker compose config           # valida sintaxis (los WARN de variables M3 sin set son esperados)
docker compose up -d            # levanta el stack completo
#   …o solo el núcleo de observabilidad:
# docker compose up -d prometheus grafana alertmanager node_exporter cadvisor blackbox_exporter

# 3) Verificar
#   - Prometheus targets UP (por túnel SSH a :9090)
#   - Grafana por https://grafana.notalexispage.online
```

> **Reverse proxy:** el servicio `npm` (en `/opt/npm` del servidor) debe unirse a la red externa
> `proxy` para resolver a `grafana` y a las apps por nombre de contenedor; sin esto los proxy
> hosts devuelven 502. Ver `npm/docker-compose.yml` (copia de referencia versionada). Solo los
> servicios con proxy host público se unen a `proxy`; el resto queda interno en `monitoring`.

## Notas de seguridad

- Secretos **siempre fuera del repo**: solo se versiona `.env.example`; `.env` y `secrets/`
  están en `.gitignore`.
- Prometheus / Alertmanager / exporters **no se publican**: se acceden por túnel SSH.
- Regla de oro: **primero al repo, luego deploy**; nunca editar dentro del contenedor.
