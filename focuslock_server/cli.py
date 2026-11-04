"""
FocusLock — Consola Interactiva de Telemetría y Control en Tiempo Real (CLI)
Asignatura: Electrónica Digital III (Entrega 30%)

Permite demostrar en vivo (en PC o en la Raspberry Pi Zero W vía SSH) el
comportamiento exacto de la Máquina de Estados Finita (FSM), la modulación PWM
del servomotor SG90 (GPIO 18), el filtro antirrebote por software de 200 ms del
sensor óptico TCRT5000 (GPIO 17) y los periféricos de señalización (LEDs y Buzzer).
"""

from __future__ import annotations

import os
import sys
import threading
import time
from typing import Optional

from fsm import FSMState, FocusLockFSM
from hardware import HardwareController


class FocusLockInteractiveCLI:
    """
    Panel de instrumentación en terminal con refresco dinámico ANSI y captura
    de teclado asíncrona no bloqueante en hilo background.
    """

    # Secuencias ANSI (soportadas en Windows 10/11 PowerShell/WT y Linux/RPi)
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    MAGENTA = "\033[95m"
    CYAN = "\033[96m"
    WHITE = "\033[97m"
    CLEAR_SCREEN = "\033[2J\033[H"
    CURSOR_HOME = "\033[H"
    HIDE_CURSOR = "\033[?25l"
    SHOW_CURSOR = "\033[?25h"

    def __init__(self, fsm: FocusLockFSM, hardware: HardwareController) -> None:
        self.fsm: FocusLockFSM = fsm
        self.hw: HardwareController = hardware
        self._running: bool = False
        self._last_key_feedback: str = (
            "Listo. Presione una tecla de comando ('1', 'd', 'p', 'c', 'e', 'q')."
        )
        self._input_thread: Optional[threading.Thread] = None

    @staticmethod
    def _enable_windows_ansi() -> None:
        """Activa el procesamiento de secuencias virtuales ANSI VT100 en consolas Windows."""
        if os.name == "nt":
            try:
                import ctypes
                kernel32 = ctypes.windll.kernel32
                handle = kernel32.GetStdHandle(-11)  # STD_OUTPUT_HANDLE
                mode = ctypes.c_ulong()
                if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                    kernel32.SetConsoleMode(handle, mode.value | 0x0004)
            except Exception:
                pass

    def _read_single_key(self) -> str:
        """
        Lee una pulsación de tecla sin requerir Enter en terminales interactivas
        (Windows msvcrt o POSIX termios/tty), con fallback limpio a sys.stdin.readline().
        """
        if os.name == "nt":
            try:
                import msvcrt
                while self._running:
                    if msvcrt.kbhit():
                        ch = msvcrt.getwch()
                        return ch.lower()
                    time.sleep(0.04)
                return ""
            except Exception:
                pass
        else:
            try:
                import select
                import termios
                import tty

                fd = sys.stdin.fileno()
                old_settings = termios.tcgetattr(fd)
                try:
                    tty.setcbreak(fd)
                    while self._running:
                        rlist, _, _ = select.select([sys.stdin], [], [], 0.05)
                        if rlist:
                            ch = sys.stdin.read(1)
                            return ch.lower()
                finally:
                    termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
                return ""
            except Exception:
                pass

        # Fallback estándar si stdin no es un TTY interactivo
        line = sys.stdin.readline()
        if not line:
            time.sleep(0.1)
            return ""
        return line.strip().lower()[:1]

    def _keyboard_listener_loop(self) -> None:
        """Hilo listener en background para procesar comandos de teclado sin bloquear la FSM."""
        while self._running:
            key = self._read_single_key()
            if not key:
                continue

            if key == "1":
                self.fsm.start_session(focus_minutes=25, break_minutes=5)
                self._last_key_feedback = (
                    "Comando [1]: Sesión Pomodoro iniciada (25 min Focus / 5 min Break)."
                )
            elif key == "d":
                self.fsm.start_session(focus_seconds=15, break_seconds=5)
                self._last_key_feedback = (
                    "Comando [d]: ¡MODO DEMO ACELERADO! (15s Focus / 5s Break) -> [WAITING_PHONE]."
                )
            elif key == "p":
                new_raw = self.hw.toggle_mock_phone_detected()
                estado_txt = "COLOCADO (evaluando debounce 200ms...)" if new_raw else "RETIRADO (evaluando debounce 200ms...)"
                self._last_key_feedback = f"Comando [p]: Celular {estado_txt} en GPIO 17."
            elif key == "c":
                ok = self.fsm.cancel_session()
                if ok:
                    self._last_key_feedback = "Comando [c]: Sesión cancelada correctamente -> [IDLE]."
                else:
                    self._last_key_feedback = (
                        "Comando [c]: ¡Bloqueo activo! No se permite cancelar en [LOCKED_FOCUS]. Use [e] Emergencia."
                    )
            elif key == "e":
                self.fsm.emergency_unlock()
                self._last_key_feedback = (
                    "Comando [e]: ¡Apertura de Emergencia ejecutada! Cerrojo en 0°."
                )
            elif key == "q":
                self._last_key_feedback = "Comando [q]: Cerrando consola y liberando hardware..."
                self._running = False
                break

    def _format_state_color(self, state: FSMState, banner: str) -> str:
        color_map = {
            FSMState.IDLE: self.CYAN,
            FSMState.WAITING_PHONE: self.BLUE,
            FSMState.GRACE_PERIOD: self.YELLOW,
            FSMState.LOCKED_FOCUS: self.RED,
            FSMState.BREAK_OPEN: self.GREEN,
            FSMState.EMERGENCY_UNLOCKED: self.MAGENTA,
        }
        c = color_map.get(state, self.WHITE)
        return f"{self.BOLD}{c}{banner}{self.RESET}"

    def _build_dashboard_frame(self) -> str:
        tel = self.hw.get_hardware_telemetry()
        state = self.fsm.state
        state_banner = self._format_state_color(state, self.fsm.get_formatted_state_banner())

        # 1. Formateo de Cerrojo PWM (GPIO 18)
        if tel["is_locked"]:
            servo_str = (
                f"{self.BOLD}{self.RED}[90° BLOQUEADO (2.0ms @ 50Hz | Duty=10.0% -> 0% anti-jitter)]{self.RESET}"
            )
        else:
            servo_str = (
                f"{self.BOLD}{self.GREEN}[0° DESBLOQUEADO (1.0ms @ 50Hz | Duty=5.0% -> 0% anti-jitter)]{self.RESET}"
            )

        # 2. Formateo de Sensor TCRT5000 (GPIO 17) + Debounce 200 ms
        elapsed_ms = tel["debounce_elapsed_ms"]
        window_ms = tel["debounce_window_ms"]
        bar_slots = 10
        filled = int(round((elapsed_ms / window_ms) * bar_slots))
        bar = "█" * filled + "░" * (bar_slots - filled)

        if tel["stable_sensor"]:
            sensor_badge = f"{self.BOLD}{self.GREEN}[PRESENTE / OBSTÁCULO (LOW 0.0V)]{self.RESET}"
        else:
            sensor_badge = f"{self.BOLD}{self.YELLOW}[VACÍO (HIGH 3.3V Pull-Up)]{self.RESET}"

        debounce_status = (
            f"{self.YELLOW}FILTRANDO REBOTE...{self.RESET}"
            if tel["is_debouncing"]
            else f"{self.GREEN}ESTABLE{self.RESET}"
        )

        # 3. Formateo de Indicadores (LED Verde Pin 23, LED Rojo Pin 22, Buzzer Pin 27)
        led_green_str = (
            f"{self.BOLD}{self.GREEN}● ON (HIGH){self.RESET}"
            if tel["led_green_on"]
            else f"{self.DIM}○ OFF (LOW){self.RESET}"
        )
        led_red_str = (
            f"{self.BOLD}{self.RED}● ON (HIGH){self.RESET}"
            if tel["led_red_on"]
            else f"{self.DIM}○ OFF (LOW){self.RESET}"
        )
        buzzer_str = (
            f"{self.BOLD}{self.YELLOW}🔊 ACTIVO (BEEP){self.RESET}"
            if tel["buzzer_on"]
            else f"{self.DIM}🔇 SILENCIO (LOW){self.RESET}"
        )

        platform_mode = (
            "Raspberry Pi Zero W (BCM2835 GPIO Real)"
            if tel["is_rpi"]
            else "Simulación HAL Determinista en PC (Mismo código de producción)"
        )

        events = self.fsm.get_recent_events()
        event_lines = "\n".join(f"  {self.DIM}•{self.RESET} {ev}" for ev in events[-5:])
        if not event_lines:
            event_lines = "  • Sin eventos registrados."

        lines = [
            f"{self.BOLD}{self.CYAN}==============================================================================={self.RESET}",
            f"{self.BOLD}  FOCUSLOCK — ESTACIÓN EMBEBIDA POMODORO | ELECTRÓNICA DIGITAL III (30%){self.RESET}",
            f"  Modo de Ejecución: {self.CYAN}{platform_mode}{self.RESET}",
            f"{self.BOLD}{self.CYAN}==============================================================================={self.RESET}",
            "",
            f"  {self.BOLD}ESTADO FSM         :{self.RESET} {state_banner}",
            f"  {self.BOLD}CERROJO PWM (GPIO {tel['servo_pin']}):{self.RESET} {servo_str}",
            f"  {self.BOLD}SENSOR TCRT5000 (GPIO {tel['sensor_pin']}):{self.RESET} {sensor_badge}",
            f"  {self.BOLD}DEBOUNCE SW (200ms):{self.RESET} [{bar}] {elapsed_ms:5.0f}/{window_ms:.0f} ms ({debounce_status}) [time.monotonic()]",
            "",
            f"  {self.BOLD}INDICADORES FÍSICOS GPIO:{self.RESET}",
            f"    ├─ LED Verde (GPIO {tel['led_green_pin']}) : {led_green_str:<28} (Descanso / Libre)",
            f"    ├─ LED Rojo  (GPIO {tel['led_red_pin']}) : {led_red_str:<28} (Enfoque Bloqueado)",
            f"    └─ Buzzer 5V (GPIO {tel['buzzer_pin']}) : {buzzer_str:<28} (Alertas Acústicas)",
            "",
            f"{self.CYAN}-------------------------------------------------------------------------------{self.RESET}",
            f"  {self.BOLD}PARÁMETROS TÉCNICOS DE DISEÑO (DIGITAL III):{self.RESET}",
            "    • PWM SG90 (GPIO 18) : f = 50 Hz (T = 20.0 ms) | 0° = 1.0 ms (Duty 5.0%) | 90° = 2.0 ms (Duty 10.0%)",
            "    • Corte Anti-Jitter  : Duty = 0.0% tras t_settle = 400 ms (evita vibración y consumo térmico)",
            "    • Muestreo & Debounce: f_s = 20 Hz (T_s = 50 ms) | Ventana antirrebote = 200 ms continuos",
            f"{self.CYAN}-------------------------------------------------------------------------------{self.RESET}",
            f"  {self.BOLD}CONTROLES INTERACTIVOS (Tiempo Real — Sin bloqueo de hilo):{self.RESET}",
            f"    {self.BOLD}[1]{self.RESET} Iniciar Pomodoro Estándar (25m Focus / 5m Break)",
            f"    {self.BOLD}[d]{self.RESET} Modo Demo Acelerado Sustentación (15s Focus / 5s Break)",
            f"    {self.BOLD}[p]{self.RESET} Simular Colocar/Retirar Celular (TCRT5000 con 200ms Debounce)",
            f"    {self.BOLD}[c]{self.RESET} Cancelar Sesión (permitido solo antes del bloqueo)",
            f"    {self.BOLD}[e]{self.RESET} Apertura de Emergencia (Override Manual a 0°)",
            f"    {self.BOLD}[q]{self.RESET} Salir limpiamente y liberar GPIO",
            f"{self.CYAN}-------------------------------------------------------------------------------{self.RESET}",
            f"  {self.BOLD}ÚLTIMA ACCIÓN:{self.RESET} {self.YELLOW}{self._last_key_feedback}{self.RESET}",
            "",
            f"  {self.BOLD}BITÁCORA DE TRANSICIONES FSM:{self.RESET}",
            event_lines,
            f"{self.BOLD}{self.CYAN}==============================================================================={self.RESET}",
        ]
        # Rellenar cada línea con espacios al final para limpiar restos de renders previos
        padded_lines = [f"{line}\033[K" for line in lines]
        return "\n".join(padded_lines) + "\033[J"

    def run(self) -> None:
        """Inicia el bucle de renderizado a 10 Hz y el hilo de captura de teclado."""
        self._enable_windows_ansi()
        self._running = True

        # Silenciar logs por consola estándar durante el modo dashboard interactivo
        logging.getLogger().setLevel(logging.CRITICAL)

        self._input_thread = threading.Thread(
            target=self._keyboard_listener_loop,
            name="FocusLock-CLI-Input",
            daemon=True,
        )
        self._input_thread.start()

        sys.stdout.write(self.CLEAR_SCREEN + self.HIDE_CURSOR)
        sys.stdout.flush()

        try:
            while self._running:
                frame = self._build_dashboard_frame()
                sys.stdout.write(self.CURSOR_HOME + frame + "\n")
                sys.stdout.flush()
                time.sleep(0.10)  # Refresco visual de 10 FPS (100 ms)
        except KeyboardInterrupt:
            self._running = False
        finally:
            sys.stdout.write(self.SHOW_CURSOR + "\n")
            sys.stdout.flush()
            self.fsm.stop()
            self.hw.cleanup()
            print("[FocusLock CLI] Sesión finalizada limpiamente.")

