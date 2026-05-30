# Evidencia de validación — Scraping completo y verificación UP

> Demuestra la **Fase 3** (configuración de Prometheus) y la verificación de que **todos los
> targets están UP**, además de validar las **PromQL mínimas** del enunciado (Fases 4 y 5).
> Verificado en vivo sobre el EC2 el **2026-05-30** (instancia `i-07c87c0363b28acf1`, EIP
> `35.168.242.195`). Prometheus está atado a `127.0.0.1:9090` (no público); se consulta su API por
> túnel SSH.

## 1. Targets de scraping — todos UP

Consultado vía `GET /api/v1/targets`. Los 7 jobs activos en estado **`up`** con scrape fresco:

| Job | Estado | Último scrape (UTC) |
|-----|:--:|----|
| `prometheus` | UP | 2026-05-30T16:04:51 |
| `node_exporter` | UP | 2026-05-30T16:05:02 |
| `cadvisor` | UP | 2026-05-30T16:04:58 |
| `django` | UP | 2026-05-30T16:04:51 |
| `tomcat` | UP | 2026-05-30T16:05:01 |
| `mariadb` (mysqld-exporter) | UP | 2026-05-30T16:04:57 |
| `wordpress_http` (blackbox) | UP | 2026-05-30T16:05:00 |

Métricas de control: `up` = 1 para los 7 jobs · `mysql_up` = 1 · `probe_success{job="wordpress_http"}` = 1.

> Captura asociada: **`evidencias/01_targets_prometheus.png`** (página `/targets` de Prometheus, todos
> en verde). Para abrirla:
> ```bash
> ssh -i "deploy-keys.pem" -p 6655 -L 9090:127.0.0.1:9090 admin@35.168.242.195
> # luego en el navegador: http://localhost:9090/targets
> ```

## 2. PromQL del host (enunciado, Fase 4)

Las cuatro consultas mínimas devuelven datos reales del **host** (node_exporter con `pid: host` y
montajes `/proc`, `/sys`, `/`):

| Métrica | Consulta | Resultado de muestra |
|---------|----------|----------------------|
| Uso de CPU | `100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | **2.12 %** |
| Memoria usada | `100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))` | **20.87 %** |
| Disco usado | `100 * (1 - (node_filesystem_avail_bytes{fstype!~"tmpfs\|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs\|overlay"}))` | **34.37 %** (6 filesystems) |
| Carga promedio | `node_load1` | **0.1** |

La presencia de **6 filesystems** y un `node_load1` coherente con la CPU (~2 %) confirma que se miden
los recursos del **host**, no del contenedor (riesgo DOK-1 mitigado).

## 3. PromQL de contenedores (enunciado, Fase 5)

cAdvisor expone métricas **por contenedor** (etiqueta `name`), no solo el cgroup raíz:

| Métrica | Consulta | Series |
|---------|----------|:--:|
| CPU por contenedor | `rate(container_cpu_usage_seconds_total{name!=""}[5m])` | 12 |
| Memoria por contenedor | `container_memory_usage_bytes{name!=""}` | 12 |
| Red recibida | `rate(container_network_receive_bytes_total{name!=""}[5m])` | 17 |
| Red transmitida | `rate(container_network_transmit_bytes_total{name!=""}[5m])` | 17 |

Contenedores con métricas (12 nombres distintos): `alertmanager`, `blackbox_exporter`, `cadvisor`,
`django-apache`, `grafana`, `mariadb`, `mysqld-exporter`, `node_exporter`, `npm`, `prometheus`,
`tomcat`, `wordpress`. Esto confirma que el **storage driver overlay2** del host resuelve el riesgo
**DOK-4** (con el snapshotter containerd por defecto de Docker 29, cAdvisor v0.49 solo reportaría el
cgroup raíz `/`).

## 4. Reglas y Alertmanager

- `GET /api/v1/rules`: **9 reglas de tipo *alerting*** cargadas, todas con `health = ok` (sin errores).
- `GET /api/v1/alertmanagers`: **`alertmanager:9093` activo** (0 dropped). Prometheus enruta las
  alertas a Alertmanager correctamente.
