-- Usuario de monitoreo para mysqld-exporter (permisos mínimos).
-- Entregable del ENUNCIADO (Fase 9). Documenta los GRANTs necesarios.
--
-- La contraseña real NO se versiona: aquí va un placeholder. En M3 la creación
-- efectiva se hace en el init de MariaDB sustituyendo EXPORTER_DB_PASSWORD desde .env.

CREATE USER IF NOT EXISTS 'exporter'@'%' IDENTIFIED BY '<EXPORTER_DB_PASSWORD>';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'%';
FLUSH PRIVILEGES;
