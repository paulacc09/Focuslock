"""
FocusLock — Máquina de Estados Finita (FSM) y Lógica de Negocio Embebida
Asignatura: Electrónica Digital III (Entrega 30%)

===============================================================================
ARQUITECTURA DE LA MÁQUINA DE ESTADOS FINITA (MODELO DE MOORE / MEALY HÍBRIDO)
===============================================================================
Estados definidos (FSMState):
  1. IDLE               -> Cerrojo 0° (1.0 ms), LED Verde ON, esperando inicio.
  2. WAITING_PHONE      -> Cerrojo 0° (1.0 ms), muestreo óptico a 20 Hz (T_s = 50 ms)
                           con filtro de debounce de 200 ms en GPIO 17.
  3. GRACE_PERIOD       -> Ventana de seguridad obligatoria de 5 segundos tras
                           confirmar presencia del smartphone; emite pulsos acústicos
                           preventivos en el Buzzer (GPIO 27) antes de enclavar.
  4. LOCKED_FOCUS       -> Cerrojo enclavado a 90° (2.0 ms @ 50 Hz -> D = 10.0%,
                           seguido de corte D = 0% tras 400 ms), LED Rojo ON,
                           temporizador regresivo MM:SS activo.
  5. BREAK_OPEN         -> Cerrojo liberado a 0° (1.0 ms @ 50 Hz -> D = 5.0%),
                           LED Verde ON, temporizador de descanso MM:SS activo.
  6. EMERGENCY_UNLOCKED -> Apertura forzada inmediata por protocolo de seguridad.
===============================================================================
"""

from __future__ import annotations

import logging
import threading
import time
from collections import deque
from enum import Enum
from typing import Any, Deque, Dict, List, Optional

from hardware import HardwareController

logger = logging.getLogger("FocusLock.FSM")


class FSMState(str, Enum):
    IDLE = "IDLE"
    WAITING_PHONE = "WAITING_PHONE"
    GRACE_PERIOD = "GRACE_PERIOD"
    LOCKED_FOCUS = "LOCKED_FOCUS"
    BREAK_OPEN = "BREAK_OPEN"
    EMERGENCY_UNLOCKED = "EMERGENCY_UNLOCKED"


class FocusLockFSM:
    """
    Controlador concurrente de la Máquina de Estados Finita (FSM) de FocusLock.
    Ejecuta un hilo daemon de evaluación a 20 Hz (periodo de muestreo de 50 ms)
    para garantizar resolución sub-200 ms en el filtro antirrebote del sensor
    TCRT5000 y exactitud de reloj monotónico en la cuenta regresiva Pomodoro.
    """

    def __init__(self, hardware: HardwareController) -> None:
        self.hw: HardwareController = hardware
        self.state: FSMState = FSMState.IDLE
        self.remaining_seconds: int = 0
        self.total_seconds: int = 0
        self.session_id: Optional[str] = None

        self._focus_duration: int = 25 * 60
        self._break_duration: int = 5 * 60
        self._grace_seconds: int = 5
        self._insertion_timeout: int = 30
        self._insertion_timer: int = 30

        self._event_log: Deque[str] = deque(maxlen=8)
        self._running: bool = True
        self._lock = threading.RLock()

        self._record_event("Sistema inicializado en estado [IDLE]. Cerrojo a 0°.")
        self._worker_thread = threading.Thread(
            target=self._loop,
            name="FocusLock-FSM-Worker",
            daemon=True,
        )
        self._worker_thread.start()

    def _record_event(self, message: str) -> None:
        """Almacena eventos con estampa de tiempo para el panel CLI y el logger."""
        timestamp = time.strftime("%H:%M:%S")
        entry = f"[{timestamp}] {message}"
        self._event_log.append(entry)
        logger.info(message)

    def get_recent_events(self) -> List[str]:
        with self._lock:
            return list(self._event_log)

    def start_session(
        self,
        focus_minutes: int = 25,
        break_minutes: int = 5,
        session_id: Optional[str] = None,
    ) -> None:
        """Inicia una sesión Pomodoro y transiciona a WAITING_PHONE."""
        with self._lock:
            self._focus_duration = max(1, focus_minutes) * 60
            self._break_duration = max(1, break_minutes) * 60
            self.total_seconds = self._focus_duration
            self.remaining_seconds = self._focus_duration
            self.session_id = session_id or f"sess_{int(time.time())}"
            self.state = FSMState.WAITING_PHONE
            self._insertion_timer = self._insertion_timeout
            self.hw.unlock_door()
            self.hw.beep(0.10)
            self._record_event(
                f"Sesión iniciada ({focus_minutes}m Focus / {break_minutes}m Break) -> [WAITING_PHONE]"
            )

    def cancel_session(self) -> bool:
        """
        Cancela la sesión activa únicamente si el cerrojo aún no está enclavado
        en LOCKED_FOCUS (o si el sistema está en descanso / emergencia).
        """
        with self._lock:
            if self.state in (
                FSMState.WAITING_PHONE,
                FSMState.GRACE_PERIOD,
                FSMState.BREAK_OPEN,
                FSMState.EMERGENCY_UNLOCKED,
            ):
                prev_state = self.state.value
                self.state = FSMState.IDLE
                self.remaining_seconds = 0
                self.total_seconds = 0
                self.hw.unlock_door()
                self.hw.beep(0.20)
                self._record_event(f"Sesión cancelada desde [{prev_state}] -> [IDLE].")
                return True

            self._record_event(
                f"Cancelación denegada en estado [{self.state.value}] (Use 'e' para emergencia)."
            )
            return False

    def emergency_unlock(self) -> None:
        """Protocolo de apertura de emergencia: libera el servomotor inmediatamente."""
        with self._lock:
            self.state = FSMState.EMERGENCY_UNLOCKED
            self.remaining_seconds = 0
            self.total_seconds = 0
            self.hw.unlock_door()
            self.hw.beep(0.50)
            self._record_event("¡APERTURA DE EMERGENCIA! Cerrojo liberado -> [EMERGENCY_UNLOCKED].")

    def reset_to_idle(self) -> None:
        """Restablece la máquina de estados a IDLE."""
        with self._lock:
            self.state = FSMState.IDLE
            self.remaining_seconds = 0
            self.total_seconds = 0
            self.hw.unlock_door()
            self._record_event("Sistema restablecido manualmente a [IDLE].")

    @staticmethod
    def format_mm_ss(seconds: int) -> str:
        mins = max(0, seconds) // 60
        secs = max(0, seconds) % 60
        return f"{mins:02d}:{secs:02d}"

    def get_formatted_state_banner(self) -> str:
        """
        Devuelve la representación textual exacta requerida para la consola:
        [IDLE] / [WAITING_PHONE] / [GRACE_PERIOD: 5s] / [LOCKED_FOCUS: MM:SS] / [BREAK_OPEN: MM:SS]
        """
        with self._lock:
            if self.state == FSMState.IDLE:
                return "[IDLE]"
            if self.state == FSMState.WAITING_PHONE:
                return f"[WAITING_PHONE] (Timeout inserción: {self._insertion_timer}s)"
            if self.state == FSMState.GRACE_PERIOD:
                return f"[GRACE_PERIOD: {self.remaining_seconds}s]"
            if self.state == FSMState.LOCKED_FOCUS:
                return f"[LOCKED_FOCUS: {self.format_mm_ss(self.remaining_seconds)}]"
            if self.state == FSMState.BREAK_OPEN:
                return f"[BREAK_OPEN: {self.format_mm_ss(self.remaining_seconds)}]"
            if self.state == FSMState.EMERGENCY_UNLOCKED:
                return "[EMERGENCY_UNLOCKED]"
            return f"[{self.state.value}]"

    def get_status(self) -> Dict[str, Any]:
        """Devuelve el diccionario de estado serializable para la API FastAPI y el CLI."""
        with self._lock:
            return {
                "state": self.state.value,
                "phone_detected": self.hw.is_phone_detected(),
                "remaining_seconds": self.remaining_seconds,
                "total_seconds": self.total_seconds,
                "session_id": self.session_id,
                "is_locked": self.hw.is_locked,
            }

    def stop(self) -> None:
        """Detiene el hilo de evaluación de la FSM de forma limpia."""
        self._running = False
        if self._worker_thread.is_alive():
            self._worker_thread.join(timeout=1.0)

    def _loop(self) -> None:
        """
        Hilo maestro de evaluación concurrente:
          - Frecuencia de muestreo de entrada digital: f_s = 20 Hz (T_s = 50 ms)
            para resolver con precisión el filtro de debounce de 200 ms (4 muestras).
          - Base de tiempo de segundos mediante acumulador monotónico exacto (1.0 s)
            libre de deriva acumulativa.
        """
        last_tick = time.monotonic()

        while self._running:
            time.sleep(0.05)  # Muestreo a 20 Hz (cada 50 ms)
            now = time.monotonic()
            tick_second = (now - last_tick) >= 1.0
            if tick_second:
                last_tick += 1.0
                # Si hubo una pausa larga del SO, resincronizar para evitar ráfagas
                if (now - last_tick) >= 1.0:
                    last_tick = now

            with self._lock:
                phone_detected = self.hw.is_phone_detected()

                # 1. Estado: Esperando colocación del teléfono en el sensor TCRT5000
                if self.state == FSMState.WAITING_PHONE:
                    if phone_detected:
                        self.state = FSMState.GRACE_PERIOD
                        self.remaining_seconds = self._grace_seconds
                        self.total_seconds = self._grace_seconds
                        last_tick = now
                        self.hw.beep(0.20)
                        self._record_event(
                            "Celular detectado (Debounce 200ms OK) -> [GRACE_PERIOD: 5s]"
                        )
                        continue

                    if tick_second:
                        self._insertion_timer -= 1
                        if self._insertion_timer <= 0:
                            self.state = FSMState.IDLE
                            self.remaining_seconds = 0
                            self.total_seconds = 0
                            self._record_event(
                                "Timeout esperando smartphone (30s) -> Retornando a [IDLE]."
                            )

                # 2. Estado: Ventana de Gracia (5 segundos antes de enclavar)
                elif self.state == FSMState.GRACE_PERIOD:
                    if not phone_detected:
                        # Si el usuario retira el teléfono durante la ventana de gracia, regresa a espera
                        self.state = FSMState.WAITING_PHONE
                        self._insertion_timer = self._insertion_timeout
                        self.remaining_seconds = self._focus_duration
                        self.total_seconds = self._focus_duration
                        self.hw.beep(0.15)
                        self._record_event(
                            "Celular retirado durante ventana de gracia -> [WAITING_PHONE]"
                        )
                        continue

                    if tick_second:
                        self.remaining_seconds -= 1
                        if self.remaining_seconds > 0:
                            self.hw.beep(0.08)
                        else:
                            self.state = FSMState.LOCKED_FOCUS
                            self.remaining_seconds = self._focus_duration
                            self.total_seconds = self._focus_duration
                            self.hw.lock_door()
                            self.hw.beep(0.30)
                            self._record_event(
                                "¡Cerrojo enclavado a 90°! -> "
                                f"[LOCKED_FOCUS: {self.format_mm_ss(self.remaining_seconds)}]"
                            )

                # 3. Estado: Enfoque Bloqueado (Pomodoro en curso)
                elif self.state == FSMState.LOCKED_FOCUS and tick_second:
                    if self.remaining_seconds > 0:
                        self.remaining_seconds -= 1
                    if self.remaining_seconds <= 0:
                        self.state = FSMState.BREAK_OPEN
                        self.remaining_seconds = self._break_duration
                        self.total_seconds = self._break_duration
                        self.hw.unlock_door()
                        self.hw.beep(0.40)
                        self._record_event(
                            "Bloque Focus completado. Cerrojo a 0° -> "
                            f"[BREAK_OPEN: {self.format_mm_ss(self.remaining_seconds)}]"
                        )

                # 4. Estado: Descanso con cerrojo abierto
                elif self.state == FSMState.BREAK_OPEN and tick_second:
                    if self.remaining_seconds > 0:
                        self.remaining_seconds -= 1
                    if self.remaining_seconds <= 0:
                        self.state = FSMState.IDLE
                        self.remaining_seconds = 0
                        self.total_seconds = 0
                        self.hw.beep(0.25)
                        self._record_event("Descanso finalizado -> Sistema listo en [IDLE].")
