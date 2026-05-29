-- Inicialización de MariaDB (se ejecuta SOLO en el primer arranque del volumen).
-- M0: crea las dos bases de datos. Los usuarios de app y el usuario 'exporter'
-- (con sus contraseñas reales desde .env) se provisionan en M3.

CREATE DATABASE IF NOT EXISTS djangodb  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
