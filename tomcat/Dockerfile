# Tomcat + JMX Exporter (javaagent) — M3.
# Tomcat oficial sirviendo la sample app, instrumentado con jmx_prometheus_javaagent
# (modo HTTP server: =9404:) → métricas de JVM/Catalina en http://tomcat:9404/metrics.
FROM tomcat:10.1-jdk17-temurin

# --- Sample app ---------------------------------------------------------------
# La imagen oficial deja webapps/ VACÍO (responde 404 en /) y envía los webapps
# de ejemplo en webapps.dist/. Restaurarlos despliega ROOT, examples y docs, de
# modo que Tomcat sirve una app real en / y /examples (tráfico que monitorear).
RUN cp -a /usr/local/tomcat/webapps.dist/. /usr/local/tomcat/webapps/

# --- JMX Prometheus javaagent -------------------------------------------------
# Versión CLAVADA a 0.20.0: usa el formato de config CLÁSICO compatible con
# jmx/config.yml (lowercaseOutputName / rules: [{pattern: ".*"}]). La línea 1.x
# cambia a un formato incompatible — NO auto-bumpear ni usar "latest".
# ADD descarga la URL de Maven Central en build (la base temurin trae ca-certificates).
ADD https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.20.0/jmx_prometheus_javaagent-0.20.0.jar /opt/jmx/jmx_javaagent.jar
COPY jmx/config.yml /opt/jmx/config.yml

# La forma "=9404:" levanta el PROPIO servidor HTTP del agente en 0.0.0.0:9404
# → accesible como tomcat:9404 en la red 'monitoring'. catalina.sh run respeta CATALINA_OPTS.
ENV CATALINA_OPTS="-javaagent:/opt/jmx/jmx_javaagent.jar=9404:/opt/jmx/config.yml"

# 8080 = app (vía NPM); 9404 = métricas JMX (solo interno para Prometheus).
EXPOSE 8080 9404

# Sin override del CMD: la imagen base ya corre `catalina.sh run`.
