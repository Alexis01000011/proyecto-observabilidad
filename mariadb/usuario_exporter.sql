-- ==========================================================================
-- usuario_exporter.sql — Entregable del ENUNCIADO (Fase 9)
--
-- DOCUMENTA el usuario de monitoreo que consume el mysqld-exporter (v0.14),
-- con sus GRANT EXACTOS y de PRIVILEGIO MÍNIMO. Es el documento entregable:
-- NO se ejecuta en el arranque. La creación EFECTIVA (idempotente, con la
-- contraseña real tomada del entorno) la realiza el script de init:
--   mariadb/init/02_app_users.sh
--
-- ⚠️ La contraseña real NO se versiona. Aquí va un PLACEHOLDER. En el deploy,
-- la contraseña verdadera vive en `.env` (gitignored) como EXPORTER_DB_PASSWORD
-- y el integrador la inyecta como variable de entorno del contenedor MariaDB,
-- desde donde 02_app_users.sh la lee al provisionar el usuario.
--
-- Host '%' (comodín): el exporter corre en OTRO contenedor de la red Docker
-- 'monitoring' y se conecta vía TCP (mariadb:3306), no por localhost.
-- ==========================================================================

-- Crea el usuario de monitoreo (auth nativa de MariaDB). En 02_app_users.sh se
-- usa CREATE USER IF NOT EXISTS para que el primer arranque sea idempotente.
CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY '<EXPORTER_DB_PASSWORD>';  -- placeholder; pass real desde .env

-- Privilegio MÍNIMO requerido por mysqld-exporter v0.14 (riesgo DOK-3).
-- No se otorga ningún privilegio de escritura ni acceso a datos de aplicación:
--   * PROCESS            -> leer SHOW PROCESSLIST / estado de hilos (collector de procesos).
--   * REPLICATION CLIENT -> leer SHOW SLAVE STATUS / SHOW MASTER STATUS (posición de binlog).
--   * SELECT ON *.*      -> leer information_schema / performance_schema y contadores de estado.
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';

-- Aplica los privilegios de inmediato.
FLUSH PRIVILEGES;
