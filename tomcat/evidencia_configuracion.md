# Tomcat / JMX — evidencia de configuración

Componente: **Tomcat oficial + JMX Prometheus javaagent** (modo HTTP server del agente).
Construido en el EC2 (`docker compose build tomcat`). Prometheus scrapea `tomcat:9404`.

## Imagen base y app de ejemplo
- Base: `tomcat:10.1-jdk17-temurin` (`CATALINA_HOME=/usr/local/tomcat`).
- La imagen oficial deja `webapps/` **vacío** (404 en `/`) y envía los webapps de ejemplo
  en `webapps.dist/`. El Dockerfile los restaura:
  ```dockerfile
  RUN cp -a /usr/local/tomcat/webapps.dist/. /usr/local/tomcat/webapps/
  ```
  Esto despliega **ROOT** (home de Tomcat en `/`), **examples** (servlets/JSP en `/examples`,
  útiles para generar tráfico) y **docs** → hay una app real que monitorear.

## Agente JMX
- Artefacto: `jmx_prometheus_javaagent` **0.20.0** (Maven Central).
  - URL: `https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar`
  - Descargado en build con `ADD ... /opt/jmx/jmx_javaagent.jar`.
- Versión **clavada** a 0.20.0 a propósito: usa el **formato de config clásico**
  (`lowercaseOutputName` / `rules: [{pattern: ".*"}]`). La línea 1.x usa un formato
  **incompatible** → no usar `latest` ni 1.x.
- Config: `jmx/config.yml` (copiado a `/opt/jmx/config.yml`), catch-all con
  `lowercaseOutputName: true`, `lowercaseOutputLabelNames: true`, `startDelaySeconds: 0`.

## Arranque (CATALINA_OPTS)
```dockerfile
ENV CATALINA_OPTS="-javaagent:/opt/jmx/jmx_javaagent.jar=9404:/opt/jmx/config.yml"
```
- Se usa **CATALINA_OPTS** (lo respeta `catalina.sh run`, el CMD de la imagen base; no se hace override del CMD).
- La forma `=9404:` levanta el **servidor HTTP propio del agente** en `0.0.0.0:9404`
  → accesible como `tomcat:9404` dentro de la red `monitoring` (sin proceso exporter aparte ni RMI/JMX remoto).
- `EXPOSE 8080 9404` (8080 = app vía NPM; 9404 = métricas, solo interno para Prometheus).

## Evidencia (ejecutar en el EC2, dentro de la red `monitoring`)
```bash
# Build + arranque
docker compose build tomcat
docker compose up -d tomcat

# La app responde (home de Tomcat / sample app)
curl -I http://tomcat:8080/

# Métricas JMX expuestas por el agente (debe mostrar jvm_*, java_lang_*, etc.)
curl -s http://tomcat:9404/metrics | grep -E '^jvm_' | head

# Verificar el target UP en Prometheus (job 'tomcat' → tomcat:9404)
# http://localhost:9090/targets  (vía túnel SSH)
```
Salida esperada de `/metrics`: series `jvm_memory_bytes_used`, `jvm_threads_current`,
`jvm_gc_collection_seconds_*`, `java_lang_*`, además de `jmx_scrape_duration_seconds`.
