"""
FocusLock — Máquina de Estados Finita (FSM) y Lógica de Negocio Embebida
Asignatura: Electrónica Digital III

===============================================================================
ARQUITECTURA DE LA MÁQUINA DE ESTADOS FINITA (MODELO MOORE / MEALY HÍBRIDO)
===============================================================================
Estados definidos (FSMState):
  1. IDLE               -> Tapa abierta (0°), cerrojo abierto (0°), LED Verde ON.
  2. WAITING_PHONE      -> Espera detección óptica en TCRT5000 (GPIO 17) con debounce 200ms.
  3. GRACE_PERIOD       -> Ventana de seguridad obligatoria de 5 segundos con beeps
                           y advertencia en LCD ("Bloqueo en: 5s, 4s...").
  4. LOCKED_FOCUS       -> Tapa cerrada (GPIO 18 a 90°) y cerrojo enclavado (GPIO 13/Pin 33 a 90°),
                           corte anti-jitter a los 400ms, LED Rojo ON, cuenta regresiva.
  5. BREAK_OPEN         -> Cerrojo liberado (0°) y tapa abierta (0°), LED Verde ON.
  6. EMERGENCY_UNLOCKED -> Apertura de emergencia forzada inmediata (ambos servos a 0°).
===============================================================================
"""

from __future__ import annotations

import logging
import threading
import time
from collections import deque
from enum import Enum
from typing import Any, Callable, Deque, Dict, List, Optional

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
    Ejecuta un hilo daemon de evaluación a 20 Hz (T_s = 50 ms) para garantizar
    resolución sub-200 ms en el filtro antirrebote del sensor y temporización precisa.
    """

    def __init__(
        self,
        hardware: HardwareController,
        on_focus_completed: Optional[Callable[[Optional[str], Optional[str], int], None]] = None,
    ) -> None:
        self.hw: HardwareController = hardware
        self.state: FSMState = FSMState.IDLE
        self.remaining_seconds: int = 0
        self.total_seconds: int = 0
        self.session_id: Optional[str] = None
        self.user_id: Optional[str] = None
        self._on_focus_completed = on_focus_completed

        self._focus_duration: int = 25 * 60
        self._break_duration: int = 5 * 60
        self._grace_seconds: int = 5
        self._insertion_timeout: int = 30
        self._insertion_timer: int = 30

        self._event_log: Deque[str] = deque(maxlen=8)
        self._running: bool = True
        self._lock = threading.RLock()

        self._record_event("Sistema inicializado en [IDLE]. Tapa y cerrojo abiertos.")
        self.hw.display.show_idle()

        self._worker_thread = threading.Thread(
            target=self._loop,
            name="FocusLock-FSM-Worker",
            daemon=True,
        )
        self._worker_thread.start()

    def _record_event(self, message: str) -> None:
        """Almacena eventos con estampa de tiempo para la consola y telemetría."""
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
        focus_seconds: Optional[int] = None,
        break_seconds: Optional[int] = None,
        user_id: Optional[str] = None,
    ) -> None:
        """
        Inicia una sesión de estudio o demostración y pasa a WAITING_PHONE.
        Si se especifica `focus_seconds` (ej. 30 segundos para muestra), se usa directamente.
        """
        with self._lock:
            if focus_seconds is not None:
                self._focus_duration = max(5, focus_seconds)
                self._break_duration = max(1, break_seconds or 10)
                dur_desc = f"{self._focus_duration}s Demo Focus / {self._break_duration}s Break"
            else:
                self._focus_duration = max(1, focus_minutes) * 60
                self._break_duration = max(1, break_minutes) * 60
                dur_desc = f"{focus_minutes}m Focus / {break_minutes}m Break"

            self.total_seconds = self._focus_duration
            self.remaining_seconds = self._focus_duration
            self.session_id = session_id or f"sess_{int(time.time())}"
            self.user_id = user_id
            self.state = FSMState.WAITING_PHONE
            self._insertion_timer = self._insertion_timeout

            self.hw.unlock_and_open()
            self.hw.beep(0.10)
            self.hw.display.show_waiting_phone(self._insertion_timer)
            self._record_event(f"Sesión iniciada ({dur_desc}) -> [WAITING_PHONE]")

    def cancel_session(self) -> bool:
        """Cancela la sesión únicamente si aún no se ha enclavado el cerrojo."""
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
                self.hw.unlock_and_open()
                self.hw.beep(0.20)
                self.hw.display.show_idle()
                self._record_event(f"Sesión cancelada desde [{prev_state}] -> [IDLE].")
                return True

            self._record_event(
                f"Cancelación denegada en [{self.state.value}] (Use emergencia 'e')."
            )
            return False

    def emergency_unlock(self) -> None:
        """Protocolo de apertura de emergencia: libera cerrojo y abre tapa inmediatamente."""
        with self._lock:
            self.state = FSMState.EMERGENCY_UNLOCKED
            self.remaining_seconds = 0
            self.total_seconds = 0
            self.hw.unlock_and_open()
            self.hw.beep(0.50)
            self.hw.display.show_emergency()
            self._record_event("¡APERTURA DE EMERGENCIA! Caja liberada -> [EMERGENCY_UNLOCKED].")

    def reset_to_idle(self) -> None:
        """Restablece la máquina de estados a IDLE."""
        with self._lock:
            self.state = FSMState.IDLE
            self.remaining_seconds = 0
            self.total_seconds = 0
            self.hw.unlock_and_open()
            self.hw.display.show_idle()
            self._record_event("Sistema restablecido manualmente a [IDLE].")

    @staticmethod
    def format_mm_ss(seconds: int) -> str:
        mins = max(0, seconds) // 60
        secs = max(0, seconds) % 60
        return f"{mins:02d}:{secs:02d}"

    def get_formatted_state_banner(self) -> str:
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
        with self._lock:
            line1, line2 = self.hw.display.get_display_text()
            return {
                "state": self.state.value,
                "phone_detected": self.hw.is_phone_detected(),
                "remaining_seconds": self.remaining_seconds,
                "total_seconds": self.total_seconds,
                "session_id": self.session_id,
                "user_id": self.user_id,
                "is_locked": self.hw.is_locked,
                "is_lid_closed": self.hw.is_lid_closed,
                "lcd_line1": line1,
                "lcd_line2": line2,
            }

    def stop(self) -> None:
        self._running = False
        if self._worker_thread.is_alive():
            self._worker_thread.join(timeout=1.0)

    def _loop(self) -> None:
        """
        Bucle concurrente principal @ 20 Hz (T_s = 50 ms):
        - Filtro antirrebote continuo del sensor TCRT5000.
        - Base de tiempo de 1.0 segundo con reloj monotónico libre de deriva.
        - Transición automática: Detección -> Ventana de gracia 5s -> Cierre tapa -> Bloqueo caja.
        """
        last_tick = time.monotonic()

        while self._running:
            time.sleep(0.05)  # Muestreo a 20 Hz
            now = time.monotonic()
            tick_second = (now - last_tick) >= 1.0
            if tick_second:
                last_tick += 1.0
                if (now - last_tick) >= 1.0:
                    last_tick = now

            with self._lock:
                phone_detected = self.hw.is_phone_detected()

                # 1. WAITING_PHONE: Espera detección en el sensor
                if self.state == FSMState.WAITING_PHONE:
                    if phone_detected:
                        self.state = FSMState.GRACE_PERIOD
                        self.remaining_seconds = self._grace_seconds
                        self.total_seconds = self._grace_seconds
                        last_tick = now
                        self.hw.beep(0.20)
                        self.hw.display.show_grace_period(self.remaining_seconds)
                        self._record_event(
                            "Celular detectado (Debounce 200ms OK) -> [GRACE_PERIOD: 5s]"
                        )
                        continue

                    if tick_second:
                        self._insertion_timer -= 1
                        self.hw.display.show_waiting_phone(self._insertion_timer)
                        if self._insertion_timer <= 0:
                            self.state = FSMState.IDLE
                            self.remaining_seconds = 0
                            self.total_seconds = 0
                            self.hw.display.show_idle()
                            self._record_event(
                                "Timeout esperando celular (30s) -> Retorno a [IDLE]."
                            )

                # 2. GRACE_PERIOD: 5 segundos de advertencia antes del cierre y bloqueo
                elif self.state == FSMState.GRACE_PERIOD:
                    if not phone_detected:
                        # Si el usuario retira el teléfono durante los 5s, vuelve a espera
                        self.state = FSMState.WAITING_PHONE
                        self._insertion_timer = self._insertion_timeout
                        self.remaining_seconds = self._focus_duration
                        self.total_seconds = self._focus_duration
                        self.hw.beep(0.15)
                        self.hw.display.show_waiting_phone(self._insertion_timer)
                        self._record_event(
                            "Celular retirado durante ventana de gracia -> [WAITING_PHONE]"
                        )
                        continue

                    if tick_second:
                        self.remaining_seconds -= 1
                        if self.remaining_seconds > 0:
                            self.hw.beep(0.08)  # Beep corto preventivo por cada segundo
                            self.hw.display.show_grace_period(self.remaining_seconds)
                        else:
                            # Fin de los 5 segundos: CIERRA TAPA Y LUEGO BLOQUEA CAJA
                            self.state = FSMState.LOCKED_FOCUS
                            self.remaining_seconds = self._focus_duration
                            self.total_seconds = self._focus_duration
                            self.hw.close_and_lock()
                            self.hw.beep(0.35)
                            time_str = self.format_mm_ss(self.remaining_seconds)
                            self.hw.display.show_locked_focus(time_str)
                            self._record_event(
                                f"¡Caja cerrada y cerrojo enclavado en Pin 33! -> [LOCKED_FOCUS: {time_str}]"
                            )

                # 3. LOCKED_FOCUS: Sesión de enfoque bloqueada
                elif self.state == FSMState.LOCKED_FOCUS and tick_second:
                    if self.remaining_seconds > 0:
                        self.remaining_seconds -= 1
                    time_str = self.format_mm_ss(self.remaining_seconds)
                    self.hw.display.show_locked_focus(time_str)

                    if self.remaining_seconds <= 0:
                        # Sesión completada: DESBLOQUEA CAJA Y ABRE TAPA
                        self.state = FSMState.BREAK_OPEN
                        self.remaining_seconds = self._break_duration
                        self.total_seconds = self._break_duration
                        self.hw.unlock_and_open()
                        self.hw.beep(0.40)
                        break_time_str = self.format_mm_ss(self.remaining_seconds)
                        self.hw.display.show_break(break_time_str)
                        self._record_event(
                            f"Enfoque finalizado con éxito. Cerrojo y tapa abiertos -> [BREAK_OPEN: {break_time_str}]"
                        )
                        if self._on_focus_completed is not None:
                            cb = self._on_focus_completed
                            s_id = self.session_id
                            u_id = self.user_id
                            f_dur = self._focus_duration
                            threading.Thread(
                                target=cb,
                                args=(s_id, u_id, f_dur),
                                daemon=True,
                            ).start()

                # 4. BREAK_OPEN: Descanso con caja abierta
                elif self.state == FSMState.BREAK_OPEN and tick_second:
                    if self.remaining_seconds > 0:
                        self.remaining_seconds -= 1
                    break_time_str = self.format_mm_ss(self.remaining_seconds)
                    self.hw.display.show_break(break_time_str)

                    if self.remaining_seconds <= 0:
                        self.state = FSMState.IDLE
                        self.remaining_seconds = 0
                        self.total_seconds = 0
                        self.hw.beep(0.25)
                        self.hw.display.show_idle()
                        self._record_event("Descanso concluido -> Sistema listo en [IDLE].")
