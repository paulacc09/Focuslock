"""
FocusLock — Consola Interactiva de Telemetría y Control en Tiempo Real (CLI)
Asignatura: Electrónica Digital III

Permite demostrar en vivo (en PC o en Raspberry Pi 4 vía SSH / terminal) el
comportamiento exacto de la FSM, la modulación PWM de los dos servomotores
(Tapa en Pin 12 / GPIO 18 y Bloqueo en Pin 33 / GPIO 13), el sensor óptico
con debounce de 200 ms, los indicadores LED/Buzzer y la pantalla LCD.
"""

from __future__ import annotations

import logging
import os
import sys
import threading
import time
from typing import Optional

from fsm import FSMState, FocusLockFSM
from hardware import HardwareController


class FocusLockInteractiveCLI:
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
            "Listo. Presione una tecla ('1', 'd' [Demo 30s], 'p', 'c', 'e', 'q')."
        )
        self._input_thread: Optional[threading.Thread] = None

    @staticmethod
    def _enable_windows_ansi() -> None:
        if os.name == "nt":
            try:
                import ctypes
                kernel32 = ctypes.windll.kernel32
                handle = kernel32.GetStdHandle(-11)
                mode = ctypes.c_ulong()
                if kernel32.GetConsoleMode(handle, ctypes.byref(mode)):
                    kernel32.SetConsoleMode(handle, mode.value | 0x0004)
            except Exception:
                pass

    def _read_single_key(self) -> str:
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

        line = sys.stdin.readline()
        if not line:
            time.sleep(0.1)
            return ""
        return line.strip().lower()[:1]

    def _keyboard_listener_loop(self) -> None:
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
                self.fsm.start_session(focus_seconds=30, break_seconds=10)
                self._last_key_feedback = (
                    "Comando [d]: ¡MODO DEMO MUESTRA! (30s Focus / 10s Break) -> Esperando celular."
                )
            elif key == "p":
                new_raw = self.hw.toggle_mock_phone_detected()
                estado_txt = "COLOCADO (evaluando 200ms debounce...)" if new_raw else "RETIRADO"
                self._last_key_feedback = f"Comando [p]: Sensor TCRT5000 -> {estado_txt}"
            elif key == "c":
                ok = self.fsm.cancel_session()
                if ok:
                    self._last_key_feedback = "Comando [c]: Sesión cancelada -> [IDLE]."
                else:
                    self._last_key_feedback = (
                        "Comando [c]: Denegado. Caja bloqueada. Use [e] para Emergencia."
                    )
            elif key == "e":
                self.fsm.emergency_unlock()
                self._last_key_feedback = (
                    "Comando [e]: ¡Apertura de Emergencia! Cerrojo y tapa abiertos."
                )
            elif key == "q":
                self._last_key_feedback = "Comando [q]: Saliendo..."
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

        # 1. Servo Tapa (GPIO 18 / Pin 12)
        if tel["is_lid_closed"]:
            lid_str = f"{self.BOLD}{self.RED}[90° CERRADA]{self.RESET}"
        else:
            lid_str = f"{self.BOLD}{self.GREEN}[0° ABIERTA]{self.RESET}"

        # 2. Servo Cerrojo (GPIO 13 / Pin 33)
        if tel["is_locked"]:
            lock_str = f"{self.BOLD}{self.RED}[90° BLOQUEADO (Enclavado)]{self.RESET}"
        else:
            lock_str = f"{self.BOLD}{self.GREEN}[0° DESBLOQUEADO (Retraído)]{self.RESET}"

        # 3. Sensor TCRT5000 + Debounce
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
            f"{self.YELLOW}FILTRANDO...{self.RESET}"
            if tel["is_debouncing"]
            else f"{self.GREEN}ESTABLE{self.RESET}"
        )

        # 4. Indicadores LEDs y Buzzer
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
            else f"{self.DIM}🔇 SILENCIO{self.RESET}"
        )

        # 5. Virtual LCD Box
        lcd_l1 = tel["lcd_line1"].ljust(16)
        lcd_l2 = tel["lcd_line2"].ljust(16)
        hw_tag = "(I2C Real)" if tel["lcd_hardware"] else "(Virtual Simulado)"

        platform_mode = (
            "Raspberry Pi 4 / GPIO BCM Real"
            if tel["is_rpi"]
            else "Simulación HAL en PC (Desarrollo)"
        )

        events = self.fsm.get_recent_events()
        event_lines = "\n".join(f"  {self.DIM}•{self.RESET} {ev}" for ev in events[-5:])
        if not event_lines:
            event_lines = "  • Sin eventos registrados."

        lines = [
            f"{self.BOLD}{self.CYAN}==============================================================================={self.RESET}",
            f"{self.BOLD}  FOCUSLOCK — ESTACIÓN EMBEBIDA DE ENFOQUE | ELECTRÓNICA DIGITAL III{self.RESET}",
            f"  Plataforma: {self.CYAN}{platform_mode}{self.RESET}",
            f"{self.BOLD}{self.CYAN}==============================================================================={self.RESET}",
            "",
            f"  {self.BOLD}ESTADO FSM               :{self.RESET} {state_banner}",
            f"  {self.BOLD}SERVO TAPA (Pin 12 / G18):{self.RESET} {lid_str}",
            f"  {self.BOLD}SERVO BLOQUEO (Pin 33/G13):{self.RESET} {lock_str}",
            f"  {self.BOLD}SENSOR TCRT5000 (Pin 11) :{self.RESET} {sensor_badge}",
            f"  {self.BOLD}DEBOUNCE 200ms           :{self.RESET} [{bar}] {elapsed_ms:5.0f}/{window_ms:.0f} ms ({debounce_status})",
            "",
            f"  {self.BOLD}PANTALLA LCD 16x2 {hw_tag}:{self.RESET}",
            f"    ┌──────────────────┐",
            f"    │ {self.BOLD}{self.YELLOW}{lcd_l1}{self.RESET} │  (Línea 1)",
            f"    │ {self.BOLD}{self.WHITE}{lcd_l2}{self.RESET} │  (Línea 2)",
            f"    └──────────────────┘",
            "",
            f"  {self.BOLD}INDICADORES FÍSICOS GPIO:{self.RESET}",
            f"    ├─ LED Verde (Pin 16 / GPIO 23) : {led_green_str:<26} (Libre / Descanso)",
            f"    ├─ LED Rojo  (Pin 15 / GPIO 22) : {led_red_str:<26} (Caja Bloqueada)",
            f"    └─ Buzzer 5V (Pin 13 / GPIO 27) : {buzzer_str:<26} (Alertas acústicas)",
            "",
            f"{self.CYAN}-------------------------------------------------------------------------------{self.RESET}",
            f"  {self.BOLD}CONTROLES DE DEMOSTRACIÓN (Digital III):{self.RESET}",
            f"    {self.BOLD}[1]{self.RESET} Iniciar Pomodoro Estándar (25m Focus / 5m Break)",
            f"    {self.BOLD}[d]{self.RESET} Iniciar Modo Muestra Rápida ({self.BOLD}{self.YELLOW}30s Focus{self.RESET} / 10s Break)",
            f"    {self.BOLD}[p]{self.RESET} Simular Colocar / Retirar Celular (TCRT5000)",
            f"    {self.BOLD}[c]{self.RESET} Cancelar Sesión (solo permitido antes del bloqueo)",
            f"    {self.BOLD}[e]{self.RESET} Apertura de Emergencia (Desbloquea cerrojo y abre tapa)",
            f"    {self.BOLD}[q]{self.RESET} Salir limpiamente y liberar GPIO",
            f"{self.CYAN}-------------------------------------------------------------------------------{self.RESET}",
            f"  {self.BOLD}ÚLTIMA ACCIÓN:{self.RESET} {self.YELLOW}{self._last_key_feedback}{self.RESET}",
            "",
            f"  {self.BOLD}BITÁCORA DE TRANSICIONES FSM:{self.RESET}",
            event_lines,
            f"{self.BOLD}{self.CYAN}==============================================================================={self.RESET}",
        ]
        padded_lines = [f"{line}\033[K" for line in lines]
        return "\n".join(padded_lines) + "\033[J"

    def run(self) -> None:
        self._enable_windows_ansi()
        self._running = True

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
                time.sleep(0.10)
        except KeyboardInterrupt:
            self._running = False
        finally:
            sys.stdout.write(self.SHOW_CURSOR + "\n")
            sys.stdout.flush()
            self.fsm.stop()
            self.hw.cleanup()
            print("[FocusLock CLI] Sesión finalizada limpiamente.")
