# FocusLock — Estación Inteligente de Enfoque (Cloud & Edge)

FocusLock es una solución integral para el bloqueo de distracciones y gestión de sesiones Pomodoro de alto rendimiento. Combina una estación física de bloqueo con servomotores y sensores (Raspberry Pi 4 / emulador PC), un módulo local de visión por computadora y análisis acústico en PC, un servidor backend escalable en la nube con WebSockets y soporte multi-base de datos, y un panel de control web accesible en tiempo real.

---

## 🏗️ Arquitectura del Sistema

```mermaid
flowchart TD
    subgraph LocalPC["💻 Entorno Local (Mi PC)"]
        Cam["📷 Cámara Física / Web<br/>(Detección de Rostro y Atención)"]
        Mic["🎤 Micrófono<br/>(Monitoreo Acústico RMS en dB)"]
        LocalMod["⚙️ Módulo Local (Python)<br/>/local-module/main.py"]
        LocalDB[("💾 SQLite Local Buffer<br/>(Tolerancia a caídas offline)")]
        Cam --> LocalMod
        Mic --> LocalMod
        LocalMod <--> LocalDB
    end

    subgraph CloudInfra["☁️ Infraestructura Cloud & Balanceo"]
        LB["⚖️ Load Balancer (Nginx)<br/>(Sticky Sessions con ip_hash & WebSocket Upgrade)"]
        subgraph Replicas["Réplicas de Servidor FastAPI"]
            App1["🚀 FocusLock Server 1<br/>(:8000)"]
            App2["🚀 FocusLock Server 2<br/>(:8000)"]
        end
        subgraph Databases["Persistencia Dual"]
            Postgres[("🐘 Base de Datos 1: PostgreSQL<br/>(Sesiones Pomodoro, Histórico, Auditoría)")]
            Redis[("⚡ Base de Datos 2: Redis<br/>(Telemetría Viva, Buffer dB, Pub/Sub Réplicas)")]
        end
    end

    subgraph Clients["🌐 Clientes Finales"]
        WebDash["🖥️ Dashboard Web en Vivo<br/>https://digiproy.qd.je"]
        AppFlutter["📱 App Móvil Flutter"]
    end

    LocalMod -- "WebSocket /ws/telemetry<br/>(Reconexión Exponencial)" --> LB
    LB --> App1
    LB --> App2

    App1 <--> Postgres
    App2 <--> Postgres
    App1 <--> Redis
    App2 <--> Redis
    App1 <-. "Pub/Sub Sync" .-> Redis <-. "Pub/Sub Sync" .-> App2

    App1 -- "WebSocket /ws/live" --> WebDash
    App2 -- "WebSocket /ws/live" --> WebDash
    WebDash -. "REST API" .-> LB
    AppFlutter -. "REST / Sockets" .-> LB
```

---

## 🌟 Cumplimiento de Requisitos

1. **Despliegue en la nube:** Desplegable en Render, Railway, Fly.io o VPS con `Dockerfile` optimizado, orquestación `docker-compose.yml`, configuración `render.yaml` y variables en `.env.example`.
2. **Módulo local (`/local-module`):** Servicio autónomo en PC que captura cámara y micrófono, procesa métricas de atención y ruido, tolera caídas de la nube con SQLite local y se ejecuta con un solo comando.
3. **Funcionalidad con sockets:** Canales WebSocket `/ws/telemetry` (módulo local) y `/ws/live` (dashboard web) para streaming bidireccional en tiempo real.
4. **Cámara y micrófono:** Captura visual con OpenCV (presencia y atención) y acústica con decibelios RMS, con fallback interactivo en el navegador mediante `getUserMedia` y HTTPS.
5. **Mínimo 2 bases de datos:**
   - **PostgreSQL:** Base relacional para sesiones, métricas consolidadas e infracciones de ruido.
   - **Redis:** Base NoSQL/Caché para telemetría viva de alta frecuencia y bus Pub/Sub entre réplicas.
6. **Balanceador de cargas:** Nginx configurado con `ip_hash` (sticky sessions) para WebSockets y 2 réplicas del servidor sincronizadas mediante Redis adapter.
7. **Hosting + dominio:** Conexión configurada para el dominio `https://digiproy.qd.je` con gestión de registros DNS externos y certificados SSL/TLS automáticos.
8. **100% en GitHub:** Todo el código, `.gitignore` limpio, workflows de CI/CD en `.github/workflows/deploy.yml` y documentación completa.

---

## 💻 Módulo Local (`/local-module`)

El módulo local corre en la computadora personal y cumple una función esencial en FocusLock: supervisar que el usuario mantenga su concentración y que el entorno de estudio permanezca en silencio durante la sesión bloqueada.

### Requisitos Previos
- Python 3.9 o superior.
- Cámara web y micrófono (físicos o emulados por el sistema operativo).

### Instalación
```bash
# 1. Instalar dependencias del módulo local
pip install -r local-module/requirements.txt
```

### Ejecución (Un solo comando)
Desde la raíz del proyecto:
```bash
python run_local.py
```
O directamente desde su carpeta:
```bash
cd local-module
python main.py
```

### Verificación de Funcionamiento
Al iniciar, la consola mostrará:
```text
13:25:00 [INFO] [LOCAL-MODULE] =================================================================
13:25:00 [INFO] [LOCAL-MODULE]   🎯 FOCUSLOCK — MÓDULO LOCAL INICIADO
13:25:00 [INFO] [LOCAL-MODULE]   • Servidor Cloud API : https://digiproy.qd.je
13:25:00 [INFO] [LOCAL-MODULE]   • Conexión WebSocket : wss://digiproy.qd.je/ws/telemetry
13:25:00 [INFO] [LOCAL-MODULE]   • Límite Ruido (dB)  : 65.0 dB
13:25:00 [INFO] [LOCAL-MODULE]   • Base de Datos Local: local_telemetry.db
13:25:00 [INFO] [LOCAL-MODULE] =================================================================
13:25:01 [INFO] [LOCAL-MODULE] ✅ Conexión establecida con la nube. Transmitiendo telemetría en vivo.
13:25:02 [INFO] [LOCAL-MODULE] FSM:[LOCKED_FOCUS] 1485s | Atención: 92% | Ruido: 43.5 dB
```

### Tolerancia a Fallos y Modo Offline
Si la nube se desconecta o cae temporalmente:
1. El módulo entra en modo offline y guarda cada muestra en la base de datos local SQLite (`local_telemetry.db`).
2. Aplica reintentos continuos con retroceso exponencial (backoff).
3. Al restablecer la conexión, sincroniza en bloque los registros offline pendientes hacia la nube.

---

## 🗄️ Bases de Datos y Migraciones

### 1. PostgreSQL (Relacional)
Gestiona la persistencia a largo plazo:
- **`focus_sessions`**: Registro de sesiones Pomodoro (ID, modo demo/estándar, duración, estado, faltas de concentración, alertas de ruido).
- **`focus_events`**: Bitácora de transiciones de hardware y FSM.
- **`noise_audit_logs`**: Auditoría de eventos donde el ruido superó el umbral configurado.

*Migraciones y Seeds:* Al arrancar el servidor FastAPI, la función `init_postgres()` ejecuta las sentencias DDL automáticamente y siembra datos iniciales con `seed_postgres()`.

### 2. Redis (NoSQL / Memoria / Caché)
Gestiona el estado en tiempo real:
- **`focuslock:live_telemetry`**: Último estado instantáneo de la cámara y atención con TTL.
- **`focuslock:noise:history`**: Lista circular con las últimas lecturas de decibelios.
- **`focuslock:events`**: Canal Pub/Sub para que múltiples réplicas detrás del balanceador Nginx compartan eventos de WebSockets en tiempo real.

---

## ⚖️ Balanceador de Carga con Docker Compose

Para levantar toda la infraestructura localmente (Balanceador Nginx + 2 Réplicas de FastAPI + PostgreSQL + Redis):

```bash
docker compose up -d --build
```

### Servicios Levantados
| Contenedor | Imagen | Puerto Expuesto | Función |
| :--- | :--- | :--- | :--- |
| `focuslock_lb` | `nginx:alpine` | `80:80`, `8080:80` | Balanceador Nginx con sticky sessions e ip_hash |
| `focuslock_app_1` | `focuslock:latest` | Interno `8000` | Réplica 1 del Servidor FastAPI |
| `focuslock_app_2` | `focuslock:latest` | Interno `8000` | Réplica 2 del Servidor FastAPI |
| `focuslock_postgres` | `postgres:16-alpine`| `5432:5432` | Base de datos relacional PostgreSQL |
| `focuslock_redis` | `redis:7-alpine` | `6379:6379` | Base de datos en memoria Redis |

Para detener los servicios:
```bash
docker compose down
```

---

## ☁️ Despliegue en la Nube & Dominio `https://digiproy.qd.je`

### Despliegue en Render Cloud
1. El proyecto incluye `render.yaml` (Render Blueprint) y `Dockerfile`.
2. Al conectar el repositorio `https://github.com/paulacc09/Focuslock` a Render, se aprovisiona automáticamente el servicio web Docker y la base de datos PostgreSQL.
3. Se añade el dominio personalizado `digiproy.qd.je` en la sección **Custom Domains** de Render.

### Configuración DNS Requerida (Paso Manual)
Dado que los nameservers del dominio padre (`qd.je`) son externos:
- `ns1.digitalplat.org`
- `ns2.digitalplat.org`
- `ns3.digitalplat.org`
- `ns4.digitalplat.org`

Debe ingresar al panel de administración de DNS donde se gestionan los registros de `digitalplat.org` y añadir el siguiente registro:

| Tipo | Nombre / Host | Valor / Destino | TTL |
| :--- | :--- | :--- | :--- |
| **CNAME** | `digiproy` | El host asignado por Render (ej. `focuslock-server.onrender.com`) | 300 (Automático) |

*Nota:* Si el proveedor cloud asigna una IP fija en su lugar, se utiliza un registro de tipo **A** con valor hacia dicha dirección IP. Una vez agregado, Render emitirá el certificado SSL/TLS de Let's Encrypt automáticamente para habilitar HTTPS.

---

## ⚙️ Variables de Entorno (`.env`)

Copiar el archivo de plantilla:
```bash
cp .env.example .env
```

| Variable | Descripción | Valor por Defecto |
| :--- | :--- | :--- |
| `ENVIRONMENT` | Entorno de ejecución (`development`, `production`) | `development` |
| `PORT` | Puerto de escucha del backend | `8000` |
| `DATABASE_URL` | Cadena de conexión a PostgreSQL | `postgresql://focuslock_user:focuslock_pass@localhost:5432/focuslock_db` |
| `REDIS_URL` | Cadena de conexión a Redis | `redis://localhost:6379/0` |
| `CLOUD_API_URL` | URL de la nube para el módulo local | `https://digiproy.qd.je` |
| `CLOUD_WS_URL` | URL de WebSocket para el módulo local | `wss://digiproy.qd.je/ws/telemetry` |
| `NOISE_DECIBEL_LIMIT` | Límite acústico en decibelios antes de alerta | `65.0` |
| `TELEMETRY_INTERVAL_SECONDS` | Frecuencia de envío de telemetría | `1.0` |

---

## 🚀 Pipeline de Integración y Despliegue Continuo (CI/CD)

El archivo `.github/workflows/deploy.yml` ejecuta automáticamente ante cada push a la rama `main`:
1. **Validación de Código:** Compilación y análisis de sintaxis de todo el código Python del servidor, bases de datos y módulo local.
2. **Pruebas de Base de Datos:** Verificación de migraciones y consultas relacionales en memoria/SQLite.
3. **Construcción de Contenedor:** Prueba de build de la imagen Docker para asegurar consistencia de despliegue.
4. **Trigger de Despliegue:** Disparo automático de despliegue en la nube mediante webhook seguro de Render (`RENDER_DEPLOY_HOOK_URL`).
