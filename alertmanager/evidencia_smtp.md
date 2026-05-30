# Evidencia de configuración SMTP y prueba de correo (Alertmanager)

> Demuestra los puntos del enunciado §8: **archivo `alertmanager.yml`**, **evidencia de
> configuración SMTP**, **prueba provocada manualmente** y **correo recibido**.
> Verificado en vivo el **2026-05-30** sobre el EC2 (`i-07c87c0363b28acf1`, EIP `35.168.242.195`).

## 1. Configuración SMTP (Gmail)

`alertmanager/alertmanager.yml`:

- `smtp_smarthost: smtp.gmail.com:587` · `smtp_require_tls: true` (STARTTLS).
- **Remitente:** `smtp_from` / `smtp_auth_username` = `alexiskyc@gmail.com`.
- **Contraseña:** `smtp_auth_password_file: /etc/alertmanager/smtp_password` — el **App Password de
  Gmail NUNCA se versiona**; se monta desde `./secrets/smtp_password` (en `.gitignore`).
- **Destinatario** (distinto del remitente): `cordovasalashectoralexis@gmail.com`, con `send_resolved: true`.
- **Ruta:** `route.receiver = correo-devops`, `group_wait 10s`, `group_interval 1m`, `repeat_interval 1h`.

Verificación de que el contenedor cargó la config real:

```
GET /api/v2/status → config contiene 'cordovasalashectoralexis' = True · 'alexiskyc@gmail.com' = True
```

## 2. Manejo del secreto (App Password)

- El archivo `secrets/smtp_password` se crea **en el servidor**, fuera del repositorio (16 bytes,
  sin salto de línea final — `printf %s`).
- **Permisos (least-privilege):** modo `600`, propietario **`65534:65534` (`nobody`)**, que es el
  usuario con el que corre el contenedor `prom/alertmanager`. Así **solo el contenedor (y root)**
  puede leerlo; **no es legible por el resto de usuarios del host** ni se versiona.

> ⚠️ **Hallazgo (riesgo ALR-4):** un secreto montado con dueño `admin` (uid 1000) y modo `600` da
> `permission denied` dentro del contenedor, porque Alertmanager corre como `nobody` (uid 65534). El
> envío SMTP fallaba con *"could not read /etc/alertmanager/smtp_password: permission denied"*.
> **Corrección:** `sudo chown 65534:65534 secrets/smtp_password` (manteniendo modo `600`), no
> `chmod 644` (eso lo dejaría legible por todo el host). Para rotar el App Password después, se
> reescribe con `sudo tee` y se reaplica el `chown`.

## 3. Prueba provocada manualmente

Se inyectó una **alerta sintética** directamente en Alertmanager (sin esperar a una falla real;
las fallas provocadas reales de servicios corresponden a las pruebas obligatorias §10):

```bash
curl -s -XPOST localhost:9093/api/v2/alerts -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"PruebaCorreoM5","severity":"critical","job":"manual-test"},
       "annotations":{"summary":"Prueba manual de correo","description":"Validación SMTP."}}]'
```

La alerta queda `active` y enrutada al receiver `correo-devops`.

## 4. Resultado

- **Antes** de cargar el App Password correcto, el log de Alertmanager mostraba el rechazo de Gmail:
  `*email.loginAuth auth: 535 5.7.8 Username and Password not accepted (BadCredentials)` — útil como
  evidencia del flujo SMTP llegando hasta la autenticación.
- **Tras** cargar el App Password correcto, el reintento de notificación **deja de registrar errores**
  (Alertmanager solo loguea fallos de notificación; el silencio tras el disparo = `Notify success`)
  y el **correo llega al destinatario**.

> Captura asociada: **`evidencias/08_correo_alerta.png`** (correo recibido en
> `cordovasalashectoralexis@gmail.com`).
