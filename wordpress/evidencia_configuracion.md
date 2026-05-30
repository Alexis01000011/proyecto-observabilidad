# WordPress — evidencia de configuración (M3)

Componente: **WordPress (imagen oficial)** monitoreado por **disponibilidad HTTP** vía
**Blackbox Exporter** contra el origin interno. Documenta el cableado de base de datos, el
arranque/instalación y el método de monitoreo. No incluye secretos (solo referencias a `.env`).

## 1. Imagen

- **Imagen:** `wordpress:6-php8.2-apache` (oficial, sin build propio).
  - Trae PHP 8.2 + Apache + WordPress 6.x y el entrypoint oficial que genera `wp-config.php`
    automáticamente a partir de las variables `WORDPRESS_DB_*`.
- **Servicio:** `wordpress` (ver `docker-compose.yml`). El puerto 80 **no se publica** al host;
  el acceso externo lo da Nginx Proxy Manager (NPM) resolviendo el contenedor por nombre en la red `proxy`.
- **Volumen:** `wordpress_data:/var/www/html` persiste el código de WordPress y los uploads entre recreaciones.

## 2. Cableado de base de datos

WordPress se conecta a la instancia compartida de **MariaDB** (servicio `mariadb`, imagen `mariadb:11.4`).
El usuario y la base de datos los **provisiona el script de inicialización de MariaDB** (otro componente,
montado en `/docker-entrypoint-initdb.d`). WordPress **no** crea la BD ni el usuario; solo se autentica.

| Variable de entorno (compose)        | Valor / origen                  | Notas |
|--------------------------------------|---------------------------------|-------|
| `WORDPRESS_DB_HOST`                  | `mariadb:3306`                  | DNS interno de la red `monitoring`; host:puerto explícito |
| `WORDPRESS_DB_NAME`                  | `${WORDPRESS_DB_NAME}` → `wordpress` | BD creada por el init de MariaDB |
| `WORDPRESS_DB_USER`                  | `${WORDPRESS_DB_USER}` → `wordpress` | usuario creado por el init de MariaDB |
| `WORDPRESS_DB_PASSWORD`              | `${WORDPRESS_DB_PASSWORD}`      | **placeholder en `.env`** (`cambia_esto_wp`); valor real solo en deploy, fuera del repo |

- Las variables se interpolan desde `.env` (gitignored); ver `.env.example` para nombres y placeholders.
- La contraseña real **nunca** se versiona: vive únicamente en el `.env` del servidor.
- `depends_on: mariadb` con `condition: service_healthy` (ver composePatch) garantiza que WordPress
  no arranque su instalación antes de que MariaDB acepte conexiones, evitando el error
  "Error establishing a database connection" en el primer arranque.

## 3. Arranque e instalación

- En el **primer arranque**, el entrypoint oficial de la imagen:
  1. Espera/usa `WORDPRESS_DB_HOST` y genera `wp-config.php` con las credenciales de las variables.
  2. Copia el código de WordPress al volumen `wordpress_data` si está vacío.
- La **instalación final** (título del sitio, usuario admin) se completa **en runtime vía navegador**
  en la pantalla `wp-admin/install.php` (modelo de la imagen oficial: no hay instalación desatendida en M3).
- **Criterio M3 = "WordPress instala":** con la BD/usuario provisionados por MariaDB y las variables
  correctas, al abrir el sitio se llega a la pantalla de instalación (o al sitio ya instalado) **sin**
  error de conexión a base de datos. Eso valida el cableado completo WordPress ↔ MariaDB.

## 4. Monitoreo (Blackbox probe contra origin interno)

WordPress no expone métricas Prometheus nativas; se monitorea por **disponibilidad HTTP** con
**Blackbox Exporter**, no con un exporter embebido.

- **Job:** `wordpress_http` en `prometheus/prometheus.yml` (lo gestiona el integrador; no se toca aquí).
- **Target (origin interno):** `http://wordpress:80` — se sondea el **contenedor directamente** por su
  nombre DNS en la red `monitoring`, no la URL pública vía NPM. Así la disponibilidad mide la app real,
  independiente del proxy/Cloudflare.
- **Mecanismo:** Prometheus llama a `blackbox_exporter:9115/probe?module=http_2xx&target=http://wordpress:80`
  (relabeling estándar). La señal de UP es la métrica **`probe_success`** (1 = arriba, 0 = abajo).

### Manejo de APP-6 (la pantalla de instalación responde 302)

WordPress recién levantado redirige (`302`) de `/` hacia `wp-admin/install.php`. Para que ese estado
**cuente como UP**, el módulo `http_2xx` de `blackbox/blackbox.yml` está configurado con:

```yaml
http_2xx:
  prober: http
  http:
    method: GET
    valid_status_codes: [200, 302]   # 200 = sitio/instalación servidos; 302 = redirect del setup
    follow_redirects: true           # sigue el redirect del setup/login
    preferred_ip_protocol: ip4
```

- `follow_redirects: true` → el probe sigue el `302` hasta la pantalla de instalación (que devuelve `200`).
- `valid_status_codes: [200, 302]` → tanto un `200` final como un `302` intermedio/visible se consideran
  éxito, de modo que `probe_success=1` durante **todas** las fases (instalación pendiente y sitio ya configurado).

## 5. Resumen de verificación esperada

- `docker compose up -d` levanta `mariadb` (healthy) y luego `wordpress`.
- Abrir el sitio (vía NPM) muestra la pantalla de instalación o el sitio, **sin** error de BD.
- En Prometheus, `probe_success{job="wordpress_http", instance="http://wordpress:80"}` = `1`.
- (Captura de evidencia a adjuntar en deploy: pantalla de instalación de WP + target `wordpress_http` UP.)
