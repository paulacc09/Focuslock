"""
FocusLock — Punto de Entrada Unificado: Servidor API REST + Consola Interactiva CLI
Asignatura: Electrónica Digital III
Plataforma Destino: Raspberry Pi 4 Model B (o Pi Zero W) y PC (Simulación)

Modos de ejecución:
  1. Servidor API REST para App Móvil Flutter:
       python main.py
  2. Consola Interactiva en Terminal para sustentación/muestra en vivo:
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

# Instancias unificadas de Hardware (HAL) y Máquina de Estados (FSM)
hw = HardwareController()
fsm = FocusLockFSM(hardware=hw)

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
        description="Servidor de control local en Raspberry Pi 4 para la estación física FocusLock",
        version="1.2.0",
    )

    # Permitir peticiones desde cualquier IP en la LAN / Wi-Fi local (App Flutter)
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

    class EmergencyUnlockRequest(BaseModel):
        auth_token: Optional[str] = None

    class MockPhoneRequest(BaseModel):
        detected: bool

    @app.get("/")
    def root() -> Dict[str, str]:
        return {
            "service": "FocusLock Embedded Daemon",
            "platform": "Raspberry Pi 4 Model B (40-Pin Header)",
            "status": "online",
            "servos": "Dual Servo (Tapa: Pin 12/GPIO 18, Bloqueo: Pin 33/GPIO 13)",
        }

    @app.get("/api/status")
    def get_status() -> Dict[str, Any]:
        """Devuelve el estado instantáneo de la FSM, temporizador, servos, LCD y periféricos."""
        return fsm.get_status()

    @app.get("/api/telemetry")
    def get_telemetry() -> Dict[str, Any]:
        """Telemetría detallada de hardware a nivel de pines GPIO y voltajes lógicos."""
        data = hw.get_hardware_telemetry()
        data["fsm_state"] = fsm.state.value
        data["remaining_seconds"] = fsm.remaining_seconds
        data["total_seconds"] = fsm.total_seconds
        data["events"] = fsm.get_recent_events()
        return data

    @app.get("/dashboard")
    def get_dashboard() -> Any:
        """Sirve el Panel Visual Gigante para PC en vivo."""
        import os
        from fastapi.responses import FileResponse
        dash_path = os.path.join(os.path.dirname(__file__), "dashboard.html")
        if os.path.exists(dash_path):
            return FileResponse(dash_path)
        return {"error": "dashboard.html not found"}

    @app.post("/api/session/start")
    def start_session(req: StartSessionRequest) -> Dict[str, Any]:
        """Inicia una sesión de estudio o demostración acelerada."""
        fsm.start_session(
            focus_minutes=req.focus_minutes or 25,
            break_minutes=req.break_minutes or 5,
            session_id=req.session_id,
            focus_seconds=req.focus_seconds,
            break_seconds=req.break_seconds,
        )
        mode = f"{req.focus_seconds}s (Demo)" if req.focus_seconds else f"{req.focus_minutes}m"
        return {
            "ok": True,
            "message": f"Sesión ({mode}) iniciada. Esperando detección del celular.",
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
        return {
            "ok": True,
            "message": "Sesión cancelada con éxito.",
            "data": fsm.get_status(),
        }

    @app.post("/api/hardware/unlock")
    def emergency_unlock(req: Optional[EmergencyUnlockRequest] = None) -> Dict[str, Any]:
        """Apertura manual o de emergencia: desbloquea el cerrojo y abre la tapa."""
        fsm.emergency_unlock()
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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="FocusLock — Daemon Embebido (API FastAPI / Consola Interactiva CLI)"
    )
    parser.add_argument(
        "--cli",
        action="store_true",
        help="Inicia la consola interactiva en terminal con telemetría en tiempo real.",
    )
    parser.add_argument(
        "--host",
        type=str,
        default="0.0.0.0",
        help="Host de escucha para el servidor FastAPI (por defecto: 0.0.0.0 para acceso LAN).",
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

        print("\n" + "=" * 70)
        print("  🚀 FOCUSLOCK DAEMON INICIADO (Raspberry Pi 4 / PC)")
        print(f"  • Escuchando en: http://{args.host}:{args.port}")
        print("  • Servos: Tapa en Pin 12 (GPIO 18) | Bloqueo en Pin 33 (GPIO 13)")
        print("  • Sensor: Pin 11 (GPIO 17) | Buzzer: Pin 13 (GPIO 27)")
        print("  • LEDs: Rojo Pin 15 (GPIO 22) | Verde Pin 16 (GPIO 23)")
        print("  • Pantalla: TFT 2.8\" SPI (ILI9341)")
        print("=" * 70 + "\n")
        uvicorn.run(app, host=args.host, port=args.port, reload=False, workers=1)
