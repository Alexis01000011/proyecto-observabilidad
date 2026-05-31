#!/usr/bin/env bash
# Genera tráfico hacia Django y Tomcat para poblar los paneles de requests/latencia/errores
# de sus dashboards de Grafana (sin tráfico salen vacíos). Resuelve los servicios por nombre
# desde la red de monitoreo, sin pasar por Nginx Proxy Manager.
# Uso:  bash scripts/seed_traffic.sh [iteraciones]    (default 300; ~0.2 s por vuelta)
set -euo pipefail
N="${1:-300}"
docker run --rm -e N="$N" --network observabilidad-devops_monitoring curlimages/curl sh -c '
  for i in $(seq 1 "$N"); do
    curl -s -o /dev/null http://django-apache/                 # lista de notas (GET -> SELECT en BD)
    curl -s -o /dev/null http://django-apache/crear/           # formulario (200)
    curl -s -o /dev/null "http://django-apache/no-existe-$i"   # 404 (puebla errores 4xx)
    curl -s -o /dev/null http://tomcat:8080/                   # ROOT (200)
    curl -s -o /dev/null http://tomcat:8080/examples/          # examples (200)
    curl -s -o /dev/null "http://tomcat:8080/no-existe-$i"     # 404 (errores)
    sleep 0.2
  done'
