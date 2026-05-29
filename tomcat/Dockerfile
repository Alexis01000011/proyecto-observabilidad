# Tomcat + JMX Exporter (javaagent) — ESQUELETO (M0).
# En M3: descargar jmx_prometheus_javaagent, añadir la app de ejemplo y arrancar
# Tomcat con -javaagent exponiendo métricas en :9404.
FROM tomcat:10.1-jdk17-temurin

# TODO (M3):
#   - COPY jmx_prometheus_javaagent-<ver>.jar y jmx/config.yml a /opt/jmx/
#   - ENV CATALINA_OPTS="-javaagent:/opt/jmx/jmx_javaagent.jar=9404:/opt/jmx/config.yml"
#   - desplegar la sample app en webapps/
#   - EXPOSE 8080 9404

# En M0 arranca Tomcat tal cual (sin JMX todavía); la imagen base ya trae su CMD.
EXPOSE 8080
