#!/usr/bin/env bash
# Runbook de pruebas de fallo provocado: provoca eventos controlados para evidenciar que
# las alertas disparan y llega el correo. Se ejecuta EN EL SERVIDOR (dentro de ~/observabilidad-devops).
#
# Por qué los valores difieren del ejemplo del enunciado (--cpu 2 --timeout 300s / --vm-bytes 512M):
#   - Las alertas de CPU y RAM son `for: 5m`. La de CPU usa rate(node_cpu_seconds_total[5m]),
#     un promedio móvil de 5 min: CPU>80% no es "verdad" hasta ~4 min de stress, así que la
#     alerta dispara a ~9 min (no a los 5). Hay que sostener el stress más tiempo.
#   - 512 MB es ~6% de los 8 GB de esta instancia: nunca alcanza el umbral del 85%. Se
#     dimensiona el stress al host (~5.4 GB) para rozar ~87% y cruzar el umbral.
#
# Imagen: progrium/stress (del enunciado) usa el manifiesto Docker v1 (2014) que Docker 29
# ya no soporta ("unsupported manifest media type"). Se usa polinux/stress, un reemplazo con
# el MISMO binario `stress` y los mismos flags; su entrypoint no es `stress`, por eso se antepone.
#
# Uso:
#   bash scripts/failure_tests.sh cpu        # satura CPU 2 vCPU   (parar: docker stop stress-cpu)
#   bash scripts/failure_tests.sh mem        # satura RAM ~5.4 GB  (parar: docker stop stress-mem)
#   bash scripts/failure_tests.sh stop-apps  # detiene mariadb/django-apache/tomcat/wordpress
#   bash scripts/failure_tests.sh restore    # reinicia todo en orden (BD sana primero) y avisa
#   bash scripts/failure_tests.sh status     # estado de alertas activas + salud de targets
set -euo pipefail

PROM="http://127.0.0.1:9090"
APPS="mariadb django-apache tomcat wordpress"

case "${1:-}" in
  cpu)
    # 2 workers en 2 vCPU -> ~100%. timeout 1200s es solo un backstop: lo normal es pararlo
    # a mano (docker stop stress-cpu) en cuanto se confirma que llegó el correo.
    docker run -d --rm --name stress-cpu progrium/stress --cpu 2 --timeout 1200s
    echo "stress-cpu lanzado. HighCPUUsage dispara a ~9 min. Parar: docker stop stress-cpu"
    ;;
  mem)
    # ~5.4 GB (2 x 2700M) sobre ~1.7 GB de base ≈ ~87% de 8 GB. --vm-keep mantiene la RAM
    # ocupada; sin él, el ciclo malloc/free haría dipear el % y reiniciaría el for:5m.
    docker run -d --rm --name stress-mem progrium/stress --vm 2 --vm-bytes 2700M --vm-keep --timeout 900s
    echo "stress-mem lanzado. HighMemoryUsage dispara a ~5 min. Vigilar OOM (free -m). Parar: docker stop stress-mem"
    ;;
  stop-apps)
    docker stop $APPS
    echo "Detenidos: $APPS. A5/A6/A7/A8 disparan a ~1.5 min."
    ;;
  restore)
    docker start mariadb
    printf 'Esperando MariaDB healthy'
    for _ in $(seq 1 30); do
      st="$(docker inspect -f '{{.State.Health.Status}}' mariadb 2>/dev/null || echo none)"
      [ "$st" = "healthy" ] && { echo " OK"; break; }
      printf '.'; sleep 5
    done
    docker start django-apache tomcat wordpress
    echo "Servicios reiniciados. Verificar: bash scripts/failure_tests.sh status"
    ;;
  status)
    if command -v jq >/dev/null 2>&1; then
      echo "== Alertas (alertname: state) =="
      curl -s "$PROM/api/v1/alerts" | jq -r '.data.alerts[] | "\(.labels.alertname): \(.state)"' | sort -u
      echo "== Targets (job: health) =="
      curl -s "$PROM/api/v1/targets" | jq -r '.data.activeTargets[] | "\(.labels.job): \(.health)"' | sort -u
    else
      echo "(jq no instalado; volcado crudo de /api/v1/alerts y /api/v1/targets)"
      curl -s "$PROM/api/v1/alerts"; echo
      curl -s "$PROM/api/v1/targets"
    fi
    ;;
  *)
    echo "Uso: $0 {cpu|mem|stop-apps|restore|status}" >&2
    exit 1
    ;;
esac
