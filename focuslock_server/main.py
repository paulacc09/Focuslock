"""
FocusLock — Punto de Entrada Unificado: Servidor API REST + WebSockets en Tiempo Real
Asignatura: Electrónica Digital III
Plataforma Destino: Raspberry Pi 4 / PC / Despliegue en la Nube (Docker/Render/K8s)

Modos de ejecución:
  1. Servidor API REST + WebSockets para App Móvil y Dashboard Web:
       python main.py
  2. Consola Interactiva en Terminal para sustentación/muestra en vivo:
       python main.py --cli
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import time
from typing import Any, Dict, List, Optional, Set

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

from hardware import HardwareController
from fsm import FocusLockFSM
from mqtt_client import FocusLockMQTTClient
from database import (
    init_postgres,
    init_redis,
    init_mongodb,
    is_mongodb_active,
    save_mongo_telemetry,
    save_mongo_session,
    get_mongo_recent_telemetry,
    save_session,
    update_session_status,
    log_focus_event,
    log_noise_audit,
    get_recent_sessions,
    set_live_telemetry,
    get_live_telemetry,
    push_noise_sample,
    get_recent_noise_samples,
    publish_telemetry_event,
    subscribe_telemetry_events,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("FocusLock.Server")

# Instancias unificadas de Hardware (HAL) y Máquina de Estados (FSM)
hw = HardwareController()
fsm = FocusLockFSM(hardware=hw)

def handle_mqtt_command(cmd: Dict[str, Any]) -> None:
    """Ejecuta comandos recibidos desde el broker Eclipse Mosquitto (tópico focuslock/commands)."""
    action = str(cmd.get("action", "")).lower().strip()
    if action == "start":
        fsm.start_session(
            focus_minutes=int(cmd.get("focus_minutes", 25)),
            break_minutes=int(cmd.get("break_minutes", 5)),
            focus_seconds=cmd.get("focus_seconds"),
            break_seconds=cmd.get("break_seconds"),
        )
    elif action == "cancel":
        fsm.cancel_session()
    elif action in ("emergency", "emergency_unlock", "unlock"):
        fsm.emergency_unlock()

mqtt_client = FocusLockMQTTClient(on_command=handle_mqtt_command)

# Conjunto de clientes WebSocket conectados para el Dashboard Web en vivo
active_web_clients: Set[Any] = set()

try:
    from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel, Field

    FASTAPI_AVAILABLE = True
except ImportError:
    FASTAPI_AVAILABLE = False
    FastAPI = None  # type: ignore

if FASTAPI_AVAILABLE:
    app = FastAPI(
        title="FocusLock Cloud & Edge API",
        description="Servidor de control y telemetría en tiempo real con WebSockets y soporte multi-base de datos",
        version="2.0.0",
    )

    # Permitir peticiones desde cualquier origen (App Flutter, Dashboard Web, Módulo Local)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    class StartSessionRequest(BaseModel):
        focus_minutes: Optional[int] = Field(default=25, ge=0, le=180, description="Minutos de enfoque bloqueado")
        break_minutes: Optional[int] = Field(default=5, ge=0, le=60, description="Minutos de descanso")
        focus_seconds: Optional[int] = Field(default=None, ge=5, le=10800, description="Segundos directos para muestra/demo")
        break_seconds: Optional[int] = Field(default=None, ge=1, le=3600, description="Segundos de descanso para muestra")
        session_id: Optional[str] = None
        session_name: Optional[str] = "Sesión de Enfoque FocusLock"

    class EmergencyUnlockRequest(BaseModel):
        auth_token: Optional[str] = None

    class MockPhoneRequest(BaseModel):
        detected: bool

    class LocalTelemetryPayload(BaseModel):
        attention_score: float = Field(default=1.0, ge=0.0, le=1.0)
        face_detected: bool = True
        distraction_detected: bool = False
        decibels: float = Field(default=45.0, ge=0.0, le=140.0)
        noise_violation: bool = False
        snapshot_base64: Optional[str] = None
        fps: Optional[float] = 0.0
        timestamp: Optional[str] = None

    @app.on_event("startup")
    async def startup_event() -> None:
        """Inicializa bases de datos (PostgreSQL, Redis & MongoDB), Mosquitto MQTT y el bus Pub/Sub."""
        logger.info("Iniciando servicios de base de datos y MQTT...")
        init_postgres()
        init_redis()
        init_mongodb()
        mqtt_client.start()

        # Tarea en segundo plano que publica estado FSM y telemetría hardware en Mosquitto cada 1s
        async def mqtt_telemetry_loop() -> None:
            last_state_val = None
            while True:
                try:
                    st = fsm.get_status()
                    tel = hw.get_hardware_telemetry()
                    if st.get("state") != last_state_val:
                        last_state_val = st.get("state")
                        mqtt_client.publish_fsm_state(st, event="STATE_CHANGE")
                    else:
                        mqtt_client.publish_fsm_state(st)
                    mqtt_client.publish_hardware_telemetry(tel)
                except Exception:
                    pass
                await asyncio.sleep(1.0)

        asyncio.create_task(mqtt_telemetry_loop())

        # Conectar suscriptor de Redis Pub/Sub para que mensajes de otras réplicas
        # se difundan a los WebSockets conectados a esta instancia
        def on_redis_message(data: Dict[str, Any]) -> None:
            asyncio.create_task(broadcast_to_web(data))

        subscribe_telemetry_events(on_redis_message)

    async def broadcast_to_web(payload: Dict[str, Any]) -> None:
        """Envía el payload a todos los navegadores web conectados."""
        disconnected = set()
        for client in active_web_clients:
            try:
                await client.send_json(payload)
            except Exception:
                disconnected.add(client)
        for client in disconnected:
            active_web_clients.discard(client)

    @app.get("/")
    def root() -> Dict[str, Any]:
        return {
            "service": "FocusLock Cloud & Edge Daemon",
            "version": "2.0.0",
            "status": "online",
            "fsm_state": fsm.state.value,
            "databases": {
                "postgres": "Active (Relational Storage)",
                "redis": "Active (Real-time NoSQL & Pub/Sub)",
                "mongodb": "Active (Document Store)" if is_mongodb_active() else "Standby (Awaiting MONGODB_URI)",
            },
            "websockets": {
                "local_module": "/ws/telemetry",
                "live_dashboard": "/ws/live",
            },
        }

    @app.get("/api/status")
    def get_status() -> Dict[str, Any]:
        """Devuelve el estado instantáneo de la FSM, temporizador, servos, LCD y periféricos."""
        st = fsm.get_status()
        live_tel = get_live_telemetry()
        st["local_module"] = live_tel
        return st

    @app.get("/api/telemetry")
    def get_telemetry() -> Dict[str, Any]:
        """Telemetría detallada de hardware a nivel de pines GPIO y voltajes lógicos."""
        data = hw.get_hardware_telemetry()
        data["fsm_state"] = fsm.state.value
        data["remaining_seconds"] = fsm.remaining_seconds
        data["total_seconds"] = fsm.total_seconds
        data["events"] = fsm.get_recent_events()
        data["local_telemetry"] = get_live_telemetry()
        return data

    @app.get("/api/mqtt/status")
    def get_mqtt_status() -> Dict[str, Any]:
        """Devuelve el estado de conexión con el broker Eclipse Mosquitto."""
        return {
            "broker": f"{mqtt_client.broker_host}:{mqtt_client.broker_port}",
            "connected": mqtt_client.connected,
            "topics": {
                "publish": [
                    mqtt_client.TOPIC_FSM_STATE,
                    mqtt_client.TOPIC_HARDWARE_TELEMETRY,
                ],
                "subscribe": [mqtt_client.TOPIC_COMMANDS],
            },
        }

    @app.get("/dashboard")
    def get_dashboard() -> Any:
        """Sirve el Panel Visual Gigante para PC en vivo."""
        from fastapi.responses import FileResponse
        dash_path = os.path.join(os.path.dirname(__file__), "dashboard.html")
        if os.path.exists(dash_path):
            return FileResponse(dash_path)
        return {"error": "dashboard.html not found"}

    @app.post("/api/session/start")
    def start_session(req: StartSessionRequest) -> Dict[str, Any]:
        """Inicia una sesión de estudio o demostración acelerada y la persiste en PostgreSQL."""
        s_id = req.session_id or f"sess_{int(time.time() * 1000)}"
        fsm.start_session(
            focus_minutes=req.focus_minutes or 25,
            break_minutes=req.break_minutes or 5,
            session_id=s_id,
            focus_seconds=req.focus_seconds,
            break_seconds=req.break_seconds,
        )
        mode = f"{req.focus_seconds}s (Demo)" if req.focus_seconds else f"{req.focus_minutes}m"

        # Persistir en Base de Datos 1 (PostgreSQL)
        total_sec = req.focus_seconds or ((req.focus_minutes or 25) * 60)
        session_dict = {
            "id": s_id,
            "session_name": req.session_name or f"Sesión {mode}",
            "mode": "demo" if req.focus_seconds else "standard",
            "target_minutes": req.focus_minutes or 25,
            "remaining_seconds": total_sec,
            "status": fsm.state.value,
        }
        save_session(session_dict)
        save_mongo_session(session_dict)
        log_focus_event(s_id, "SESSION_START", {"mode": mode, "seconds": total_sec})

        return {
            "ok": True,
            "session_id": s_id,
            "message": f"Sesión ({mode}) iniciada y guardada en PostgreSQL.",
            "data": fsm.get_status(),
        }

    @app.post("/api/session/cancel")
    def cancel_session() -> Dict[str, Any]:
        """Cancela la sesión si la caja aún no ha sido bloqueada o durante descanso."""
        success = fsm.cancel_session()
        if not success:
            raise HTTPException(
                status_code=400,
                detail="No se puede cancelar una sesión que ya se encuentra en Enfoque Bloqueado.",
            )
        if fsm.session_id:
            update_session_status(fsm.session_id, "CANCELLED", fsm.remaining_seconds)
            log_focus_event(fsm.session_id, "SESSION_CANCELLED", {"remaining": fsm.remaining_seconds})

        return {
            "ok": True,
            "message": "Sesión cancelada con éxito.",
            "data": fsm.get_status(),
        }

    @app.post("/api/hardware/unlock")
    def emergency_unlock(req: Optional[EmergencyUnlockRequest] = None) -> Dict[str, Any]:
        """Apertura manual o de emergencia: desbloquea el cerrojo y abre la tapa."""
        fsm.emergency_unlock()
        if fsm.session_id:
            update_session_status(fsm.session_id, "EMERGENCY_UNLOCKED", fsm.remaining_seconds)
            log_focus_event(fsm.session_id, "EMERGENCY_UNLOCK", {"action": "unlocked"})
        return {
            "ok": True,
            "message": "Caja desbloqueada y compuerta abierta por protocolo de emergencia.",
            "data": fsm.get_status(),
        }

    @app.post("/api/hardware/mock_phone")
    def mock_phone_detection(req: MockPhoneRequest) -> Dict[str, Any]:
        """Endpoint de simulación de presencia de celular."""
        hw.set_mock_phone_detected(req.detected, bypass_debounce=True)
        return {
            "ok": True,
            "message": f"Simulación de presencia fijada en: {req.detected}",
            "data": fsm.get_status(),
        }

    # =========================================================================
    # ENDPOINTS DE BASES DE DATOS (PostgreSQL & Redis)
    # =========================================================================
    @app.get("/api/db/sessions")
    def get_sessions_history(limit: int = 15) -> Dict[str, Any]:
        """Consulta histórica desde PostgreSQL (Base de Datos 1)."""
        sessions = get_recent_sessions(limit=limit)
        return {
            "database": "PostgreSQL (Relational)",
            "count": len(sessions),
            "sessions": sessions,
        }

    @app.get("/api/db/telemetry-live")
    def get_redis_live_telemetry() -> Dict[str, Any]:
        """Consulta de telemetría de alta frecuencia desde Redis (Base de Datos 2)."""
        live_data = get_live_telemetry()
        return {
            "database": "Redis (In-Memory Key-Value Cache)",
            "telemetry": live_data,
        }

    @app.get("/api/db/noise-history")
    def get_noise_history(limit: int = 30) -> Dict[str, Any]:
        """Consulta historial de niveles de ruido acústico en decibelios desde Redis."""
        samples = get_recent_noise_samples(limit=limit)
        return {
            "database": "Redis (Circular List Buffer)",
            "count": len(samples),
            "samples": samples,
        }

    @app.get("/api/db/mongodb")
    def get_mongodb_status() -> Dict[str, Any]:
        """Estado y últimos documentos almacenados en MongoDB."""
        active = is_mongodb_active()
        recent = get_mongo_recent_telemetry(limit=15) if active else []
        return {
            "database": "MongoDB (NoSQL Document Store)",
            "connected": active,
            "count": len(recent),
            "documents": recent,
        }

    @app.post("/api/telemetry/report")
    def post_telemetry_report(payload: LocalTelemetryPayload) -> Dict[str, Any]:
        """Endpoint REST alternativo para reporte de módulo local."""
        data = payload.dict()
        set_live_telemetry(data)
        save_mongo_telemetry(data)
        push_noise_sample({
            "decibels": data["decibels"],
            "violation": data["noise_violation"],
            "timestamp": data.get("timestamp"),
        })
        if data["noise_violation"]:
            log_noise_audit(fsm.session_id, data["decibels"], True, "VIOLATION")

        # Publicar en el bus para réplicas y dashboard
        publish_telemetry_event({"type": "local_telemetry", "data": data})
        return {"ok": True, "saved_to": ["redis", "postgres"]}

    # =========================================================================
    # WEBSOCKETS EN TIEMPO REAL (Requisito 3)
    # =========================================================================
    @app.websocket("/ws/telemetry")
    async def websocket_local_module(websocket: WebSocket) -> None:
        """
        Canal WebSocket para el Módulo Local (PC / Cámara / Micrófono).
        Recibe telemetría procesada y la retransmite al dashboard y bases de datos.
        """
        await websocket.accept()
        logger.info("Módulo local conectado a /ws/telemetry.")
        try:
            while True:
                raw_text = await websocket.receive_text()
                try:
                    payload = json.loads(raw_text)
                except json.JSONDecodeError:
                    continue

                # 1. Guardar en Base de Datos: Redis y MongoDB
                set_live_telemetry(payload)
                save_mongo_telemetry(payload)
                if "decibels" in payload:
                    push_noise_sample({
                        "decibels": payload.get("decibels", 0.0),
                        "violation": payload.get("noise_violation", False),
                        "timestamp": payload.get("timestamp"),
                    })

                # 2. Guardar en Base de Datos 1: PostgreSQL si hay distracción o infracción
                if payload.get("noise_violation"):
                    log_noise_audit(
                        fsm.session_id,
                        float(payload.get("decibels", 0.0)),
                        True,
                        "HIGH_NOISE_ALERT",
                    )
                if payload.get("distraction_detected"):
                    log_focus_event(
                        fsm.session_id,
                        "DISTRACTION_DETECTED",
                        {"attention_score": payload.get("attention_score", 0.0)},
                    )

                # 3. Publicar en Redis Pub/Sub (Balanceador Nginx con réplicas)
                event = {
                    "type": "telemetry_update",
                    "source": "local_module",
                    "fsm_state": fsm.state.value,
                    "remaining_seconds": fsm.remaining_seconds,
                    "telemetry": payload,
                }
                publish_telemetry_event(event)

                # 4. Enviar acuse de recibo con estado del hardware al módulo local
                ack = {
                    "ok": True,
                    "fsm_state": fsm.state.value,
                    "remaining_seconds": fsm.remaining_seconds,
                }
                await websocket.send_json(ack)
        except WebSocketDisconnect:
            logger.info("Módulo local desconectado de /ws/telemetry.")
        except Exception as exc:
            logger.warning("Error en conexión WebSocket del módulo local: %s", exc)

    @app.websocket("/ws/live")
    async def websocket_dashboard(websocket: WebSocket) -> None:
        """
        Canal WebSocket para el Dashboard Web.
        Envía telemetría en tiempo real a los navegadores web.
        """
        await websocket.accept()
        active_web_clients.add(websocket)
        logger.info("Nuevo cliente web suscrito a /ws/live. Total clientes: %d", len(active_web_clients))
        try:
            # Enviar estado inicial inmediato
            initial_state = {
                "type": "init",
                "fsm": fsm.get_status(),
                "telemetry": get_live_telemetry(),
                "recent_noise": get_recent_noise_samples(limit=10),
            }
            await websocket.send_json(initial_state)

            # Bucle de escucha y latido
            while True:
                msg = await websocket.receive_text()
                # Si el cliente solicita comando desde web:
                try:
                    cmd_data = json.loads(msg)
                    if cmd_data.get("action") == "ping":
                        await websocket.send_json({"type": "pong"})
                except Exception:
                    pass
        except WebSocketDisconnect:
            active_web_clients.discard(websocket)
            logger.info("Cliente web desconectado de /ws/live.")
        except Exception as exc:
            active_web_clients.discard(websocket)
            logger.debug("Error en WebSocket del dashboard web: %s", exc)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="FocusLock — Daemon Embebido y Cloud (API FastAPI / WebSockets / CLI)"
    )
    parser.add_argument(
        "--cli",
        action="store_true",
        help="Inicia la consola interactiva en terminal con telemetría en tiempo real.",
    )
    parser.add_argument(
        "--host",
        type=str,
        default=os.getenv("HOST", "0.0.0.0"),
        help="Host de escucha para el servidor FastAPI.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.getenv("PORT", "8000")),
        help="Puerto TCP para el servidor FastAPI.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    if args.cli:
        from cli import FocusLockInteractiveCLI

        cli_app = FocusLockInteractiveCLI(fsm=fsm, hardware=hw)
        cli_app.run()
    else:
        if not FASTAPI_AVAILABLE:
            raise RuntimeError(
                "FastAPI y Uvicorn no están instalados. "
                "Instálelos con 'pip install -r requirements.txt' o ejecute 'python main.py --cli'."
            )
        import uvicorn

        print("\n" + "=" * 70)
        print("  🚀 FOCUSLOCK SERVER INICIADO (Cloud & Edge Ready)")
        print(f"  • Escuchando en: http://{args.host}:{args.port}")
        print("  • WebSockets en: /ws/telemetry (Módulo Local) y /ws/live (Web)")
        print("  • MQTT Mosquitto: focuslock/fsm/state | focuslock/hardware/telemetry")
        print("  • Persistencia: PostgreSQL (Relacional) y Redis (NoSQL / PubSub)")
        print("  • Servos: Tapa en GPIO 13 (Pin 33) | Bloqueo en GPIO 18 (Pin 12)")
        print("=" * 70 + "\n")
        uvicorn.run(app, host=args.host, port=args.port, reload=False, workers=1)
