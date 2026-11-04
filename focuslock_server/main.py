"""
FocusLock — Punto de Entrada Unificado: Servidor API REST + Consola Interactiva CLI
Asignatura: Electrónica Digital III (Entrega 30%)
Plataforma Destino: Raspberry Pi Zero W (BCM2835 ARMv6 @ 1 GHz, 512 MB RAM) y PC

Modos de ejecución (sin código descartable; ambos usan la misma FSM y HAL):
  1. Servidor API REST para App Móvil Flutter:
       python main.py
  2. Consola Interactiva en Terminal para demostración en vivo (Digital III):
       python main.py --cli
"""

from __future__ import annotations

import argparse
import logging
from typing import Any, Dict, Optional

from hardware import HardwareController
from fsm import FocusLockFSM

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)

# Instancias compartidas de Hardware (HAL) y Máquina de Estados (FSM)
hw = HardwareController()
fsm = FocusLockFSM(hardware=hw)

# Inicialización perezosa / condicional de FastAPI para permitir que `--cli`
# funcione incluso en entornos donde aún no se haya instalado FastAPI/Uvicorn.
try:
    from fastapi import FastAPI, HTTPException
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel, Field

    FASTAPI_AVAILABLE = True
except ImportError:
    FASTAPI_AVAILABLE = False
    FastAPI = None  # type: ignore

if FASTAPI_AVAILABLE:
    app = FastAPI(
        title="FocusLock Embebido API",
        description="Servidor de control local en Raspberry Pi Zero W para la estación física FocusLock",
        version="1.0.0",
    )

    # Permitir peticiones desde cualquier origen en la LAN local (Flutter app)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    class StartSessionRequest(BaseModel):
        focus_minutes: int = Field(default=25, ge=1, le=180, description="Minutos de enfoque bloqueado")
        break_minutes: int = Field(default=5, ge=1, le=60, description="Minutos de descanso")
        session_id: Optional[str] = None

    class EmergencyUnlockRequest(BaseModel):
        auth_token: Optional[str] = None

    class MockPhoneRequest(BaseModel):
        detected: bool

    @app.get("/")
    def root() -> Dict[str, str]:
        return {
            "service": "FocusLock Embedded Daemon",
            "platform": "Raspberry Pi Zero W",
            "status": "online",
        }

    @app.get("/api/status")
    def get_status() -> Dict[str, Any]:
        """
        Devuelve el estado instantáneo de la FSM, temporizador y periféricos:
        { "state": "IDLE", "phone_detected": false, "remaining_seconds": 0, "session_id": null, ... }
        """
        return fsm.get_status()

    @app.post("/api/session/start")
    def start_session(req: StartSessionRequest) -> Dict[str, Any]:
        """Inicia una sesión Pomodoro y pone el sistema a la espera del smartphone."""
        fsm.start_session(
            focus_minutes=req.focus_minutes,
            break_minutes=req.break_minutes,
            session_id=req.session_id,
        )
        return {
            "ok": True,
            "message": "Sesión iniciada. Esperando detección del celular en la base.",
            "data": fsm.get_status(),
        }

    @app.post("/api/session/cancel")
    def cancel_session() -> Dict[str, Any]:
        """Cancela la sesión si el cerrojo aún no ha sido enclavado o durante descanso."""
        success = fsm.cancel_session()
        if not success:
            raise HTTPException(
                status_code=400,
                detail="No se puede cancelar una sesión que ya se encuentra en Enfoque Bloqueado.",
            )
        return {
            "ok": True,
            "message": "Sesión cancelada con éxito.",
            "data": fsm.get_status(),
        }

    @app.post("/api/hardware/unlock")
    def emergency_unlock(req: Optional[EmergencyUnlockRequest] = None) -> Dict[str, Any]:
        """Apertura manual o de emergencia del cerrojo mecánico."""
        fsm.emergency_unlock()
        return {
            "ok": True,
            "message": "Cerrojo liberado por protocolo de emergencia.",
            "data": fsm.get_status(),
        }

    @app.post("/api/hardware/mock_phone")
    def mock_phone_detection(req: MockPhoneRequest) -> Dict[str, Any]:
        """Endpoint de simulación para pruebas en PC cuando no hay GPIO físico."""
        hw.set_mock_phone_detected(req.detected, bypass_debounce=True)
        return {
            "ok": True,
            "message": f"Simulación de presencia fijada en: {req.detected}",
            "data": fsm.get_status(),
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="FocusLock — Daemon Embebido (API FastAPI / Consola Interactiva CLI)"
    )
    parser.add_argument(
        "--cli",
        action="store_true",
        help="Inicia la consola interactiva en terminal con telemetría en tiempo real (Digital III).",
    )
    parser.add_argument(
        "--host",
        type=str,
        default="0.0.0.0",
        help="Host de escucha para el servidor FastAPI (por defecto: 0.0.0.0).",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8000,
        help="Puerto TCP para el servidor FastAPI (por defecto: 8000).",
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

        # En la Raspberry Pi Zero W (512 MB RAM, monocore), 1 worker es lo óptimo
        uvicorn.run("main:app", host=args.host, port=args.port, reload=False, workers=1)
