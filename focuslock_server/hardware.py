"""
FocusLock — Controlador de Hardware Embebido (Raspberry Pi 5 / 4 / Pi Zero W)
Asignatura: Electrónica Digital III

===============================================================================
FUNDAMENTACIÓN TÉCNICA Y CÁLCULOS DE TEMPORIZACIÓN (PWM, DUAL SERVO & DEBOUNCE)
===============================================================================
1. Control PWM de Servomotores SG90:
   - Frecuencia de portadora PWM: f_pwm = 50 Hz
   - Periodo de la señal: T = 1 / f_pwm = 1 / 50 Hz = 0.020 s = 20.0 ms
   - Relación de Ciclo de Trabajo (Duty Cycle): D(%) = (t_on / T) * 100
     * Posición 0°:
       t_on = 1.0 ms  =>  D = (1.0 ms / 20.0 ms) * 100 = 5.0%
     * Posición 90°:
       t_on = 2.0 ms  =>  D = (2.0 ms / 20.0 ms) * 100 = 10.0%

   - ASIGNACIÓN DE SERVOS (PINOUT RASPBERRY PI 5 / 4 / ZERO W):
     * SERVO 1 (Tapa / Compuerta):
       - Pin Físico 12 (GPIO 18 / BCM 18 — Canal PWM Hardware).
       - 0° = Tapa Abierta (1.0 ms / Duty 5%).
       - 90° = Tapa Cerrada (2.0 ms / Duty 10%).
     * SERVO 2 (Cerrojo / Bloqueo de Caja):
       - Pin Físico 33 (GPIO 13 / BCM 13 — Canal PWM Hardware).
       - 0° = Cerrojo Retraído / Desbloqueado (1.0 ms / Duty 5%).
       - 90° = Cerrojo Enclavado / Bloqueado (2.0 ms / Duty 10%).

   - SECUENCIA CRÍTICA DE CIERRE:
     1. El servo de la tapa (GPIO 18) se mueve a 90° para cerrar la compuerta.
     2. El servo de bloqueo (GPIO 13 / Pin 33) se enclava a 90° para bloquear físicamente la caja.
   - SECUENCIA CRÍTICA DE APERTURA:
     1. El servo de bloqueo (GPIO 13 / Pin 33) se retrae a 0° para desbloquear el pasador.
     2. El servo de la tapa (GPIO 18) se mueve a 0° para abrir la compuerta.

   - Mitigación de Jitter y Disipación Térmica:
     Tras aplicar el tren de pulsos durante t_settle = 400 ms (20 ciclos PWM completos),
     se fuerza D = 0.0% en ambos servos para cortar la corriente del puente H interno,
     eliminando el temblor mecánico (jitter) y el calentamiento en reposo.

2. Sensor Óptico Reflexivo Infrarrojo TCRT5000 / HW-201:
   - Conectado a Pin Físico 11 (GPIO 17 / BCM 17 — Entrada Digital).
   - Configuración: Pull-Up interno activado (R_pu ~ 50 kOhm a 3.3V).
   - Lógica activa en bajo (Active-Low):
     * Nivel ALTO (3.3V, GPIO.HIGH): Sin reflexión IR -> Compartimento VACÍO.
     * Nivel BAJO (0.0V, GPIO.LOW): Reflexión IR saturada -> Smartphone PRESENTE.
   - Filtro Antirrebote por Software (Debounce 200 ms con reloj monotónico).

3. Señalización Audiovisual:
   - LED Rojo (Pin Físico 15 / GPIO 22): Enfoque / Caja Bloqueada.
   - LED Verde (Pin Físico 16 / GPIO 23): Sistema Libre / Desbloqueado / Descanso.
   - Buzzer Activo (Pin Físico 13 / GPIO 27): Alertas acústicas y cuenta regresiva.
===============================================================================
"""

from __future__ import annotations

import logging
import threading
import time
from typing import Any, Dict, Optional

try:
    import RPi.GPIO as GPIO  # type: ignore
    IS_RPI: bool = True
except ImportError:
    IS_RPI = False

from display import DisplayController

logger = logging.getLogger("FocusLock.Hardware")


class HardwareController:
    """
    Capa de abstracción de hardware (HAL) para la estación física FocusLock.
    Compatible con Raspberry Pi 4 Model B y Pi Zero W (conector estándar de 40 pines)
    y con modo de emulación determinista para PC.
    """

    PWM_FREQUENCY_HZ: int = 50
    PWM_PERIOD_MS: float = 20.0
    DUTY_UNLOCKED_PERCENT: float = 5.0   # 1.0 ms (0°)
    DUTY_LOCKED_PERCENT: float = 10.0    # 2.0 ms (90°)
    SERVO_SETTLE_SEC: float = 0.400      # 400 ms antes de forzar duty = 0% (anti-jitter)
    DEBOUNCE_WINDOW_MS: float = 200.0    # 200 ms de estabilidad continua

    def __init__(
        self,
        lid_servo_pin: int = 18,   # Pin 12 (GPIO 18) — Mueve la Tapa
        lock_servo_pin: int = 13,  # Pin 33 (GPIO 13) — Bloquea la Caja
        sensor_pin: int = 17,      # Pin 11 (GPIO 17) — Sensor TCRT5000
        buzzer_pin: int = 27,      # Pin 13 (GPIO 27) — Buzzer activo
        led_red: int = 22,         # Pin 15 (GPIO 22) — LED Rojo
        led_green: int = 23,       # Pin 16 (GPIO 23) — LED Verde
    ) -> None:
        self.lid_servo_pin: int = lid_servo_pin
        self.lock_servo_pin: int = lock_servo_pin
        self.sensor_pin: int = sensor_pin
        self.buzzer_pin: int = buzzer_pin
        self.led_red: int = led_red
        self.led_green: int = led_green

        self._hw_lock = threading.RLock()

        # Controlador de Pantalla LCD / Display
        self.display = DisplayController()

        # Estados mecánicos de los actuadores
        self.is_lid_closed: bool = False
        self.is_box_locked: bool = False
        self.lid_angle_deg: int = 0
        self.lock_angle_deg: int = 0

        # Estados de indicadores
        self.led_red_state: bool = False
        self.led_green_state: bool = True
        self.buzzer_active: bool = False
        self._buzzer_off_timestamp: float = 0.0

        # Filtro antirrebote (200 ms con reloj monotónico)
        self._mock_phone_detected: bool = False
        self._debounce_ms: float = self.DEBOUNCE_WINDOW_MS
        self._last_raw_state: bool = False
        self._last_change_time: float = time.monotonic()
        self._stable_phone_detected: bool = False
        self._last_elapsed_debounce_ms: float = self.DEBOUNCE_WINDOW_MS

        self.pwm_lid: Optional[Any] = None
        self.pwm_lock: Optional[Any] = None

        if IS_RPI:
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)

            # 1. Servo Tapa (GPIO 18 / Pin 12)
            GPIO.setup(self.lid_servo_pin, GPIO.OUT)
            self.pwm_lid = GPIO.PWM(self.lid_servo_pin, self.PWM_FREQUENCY_HZ)
            self.pwm_lid.start(0)

            # 2. Servo Bloqueo (GPIO 13 / Pin 33)
            GPIO.setup(self.lock_servo_pin, GPIO.OUT)
            self.pwm_lock = GPIO.PWM(self.lock_servo_pin, self.PWM_FREQUENCY_HZ)
            self.pwm_lock.start(0)

            # 3. Sensor TCRT5000 (GPIO 17 / Pin 11) con pull-up interno
            GPIO.setup(self.sensor_pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

            # 4. Buzzer (GPIO 27) y LEDs (GPIO 22 Rojo, GPIO 23 Verde)
            GPIO.setup(self.buzzer_pin, GPIO.OUT, initial=GPIO.LOW)
            GPIO.setup(self.led_red, GPIO.OUT, initial=GPIO.LOW)
            GPIO.setup(self.led_green, GPIO.OUT, initial=GPIO.HIGH)
            logger.info(
                "GPIO inicializado en Raspberry Pi (Dual Servo: Tapa=GPIO %d [Pin 12], Bloqueo=GPIO %d [Pin 33]).",
                self.lid_servo_pin,
                self.lock_servo_pin,
            )
        else:
            logger.info("Ejecutando en Modo Simulación HAL (PC / Sin RPi.GPIO).")

        # Asegurar posición inicial segura: Tapa Abierta y Caja Desbloqueada
        self.unlock_and_open()

    # =========================================================================
    # CONTROL DE SERVOMOTORES (SECUENCIA TAPA + CERROJO)
    # =========================================================================

    def _drive_servo(self, pwm_inst: Optional[Any], angle_deg: int, duty_percent: float) -> None:
        """Aplica pulso PWM al servomotor y corta la señal a los 400 ms para eliminar jitter."""
        if IS_RPI and pwm_inst is not None:
            pwm_inst.ChangeDutyCycle(duty_percent)
            time.sleep(self.SERVO_SETTLE_SEC)
            pwm_inst.ChangeDutyCycle(0.0)

    def close_lid(self) -> None:
        """Cierra la compuerta / tapa de la caja (Servo GPIO 18 a 90°)."""
        with self._hw_lock:
            self.is_lid_closed = True
            self.lid_angle_deg = 90
        self._drive_servo(self.pwm_lid, 90, self.DUTY_LOCKED_PERCENT)
        logger.info("Tapa (GPIO %d / Pin 12): 90° CERRADA", self.lid_servo_pin)

    def open_lid(self) -> None:
        """Abre la compuerta / tapa de la caja (Servo GPIO 18 a 0°)."""
        with self._hw_lock:
            self.is_lid_closed = False
            self.lid_angle_deg = 0
        self._drive_servo(self.pwm_lid, 0, self.DUTY_UNLOCKED_PERCENT)
        logger.info("Tapa (GPIO %d / Pin 12): 0° ABIERTA", self.lid_servo_pin)

    def lock_box(self) -> None:
        """Enclava el cerrojo de bloqueo de la caja (Servo GPIO 13 / Pin 33 a 90°)."""
        with self._hw_lock:
            self.is_box_locked = True
            self.lock_angle_deg = 90
            self.set_leds(locked=True)
        self._drive_servo(self.pwm_lock, 90, self.DUTY_LOCKED_PERCENT)
        logger.info("Cerrojo (GPIO %d / Pin 33): 90° BLOQUEADO", self.lock_servo_pin)

    def unlock_box(self) -> None:
        """Retrae el cerrojo de bloqueo de la caja (Servo GPIO 13 / Pin 33 a 0°)."""
        with self._hw_lock:
            self.is_box_locked = False
            self.lock_angle_deg = 0
            self.set_leds(locked=False)
        self._drive_servo(self.pwm_lock, 0, self.DUTY_UNLOCKED_PERCENT)
        logger.info("Cerrojo (GPIO %d / Pin 33): 0° DESBLOQUEADO", self.lock_servo_pin)

    def close_and_lock(self) -> None:
        """
        Secuencia completa de cierre seguro requerida:
        1. Cierra la compuerta/tapa (Servo GPIO 18).
        2. Enclava el cerrojo de la caja (Servo GPIO 13 / Pin 33).
        """
        logger.info("Iniciando secuencia: Cerrar Tapa -> Bloquear Caja...")
        self.close_lid()
        time.sleep(0.15)
        self.lock_box()

    def unlock_and_open(self) -> None:
        """
        Secuencia completa de apertura segura:
        1. Retrae el cerrojo de la caja (Servo GPIO 13 / Pin 33).
        2. Abre la compuerta/tapa (Servo GPIO 18).
        """
        logger.info("Iniciando secuencia: Desbloquear Caja -> Abrir Tapa...")
        self.unlock_box()
        time.sleep(0.15)
        self.open_lid()

    # Métodos compatibles con código existente
    def lock_door(self) -> None:
        self.close_and_lock()

    def unlock_door(self) -> None:
        self.unlock_and_open()

    @property
    def is_locked(self) -> bool:
        return self.is_box_locked

    # =========================================================================
    # SENSOR ÓPTICO TCRT5000 Y FILTRO ANTIRREBOTE
    # =========================================================================

    def _read_raw_sensor(self) -> bool:
        """Lectura instantánea del pin GPIO 17 (lógica activa en bajo: 0V = celular presente)."""
        if IS_RPI:
            return bool(GPIO.input(self.sensor_pin) == GPIO.LOW)
        return self._mock_phone_detected

    def is_phone_detected(self) -> bool:
        """
        Evalúa el sensor óptico con filtro antirrebote por software de 200 ms
        utilizando reloj monotónico libre de deriva.
        """
        with self._hw_lock:
            raw_state = self._read_raw_sensor()
            now = time.monotonic()

            if raw_state != self._last_raw_state:
                self._last_raw_state = raw_state
                self._last_change_time = now

            elapsed_ms = (now - self._last_change_time) * 1000.0
            self._last_elapsed_debounce_ms = min(elapsed_ms, self._debounce_ms)

            if elapsed_ms >= self._debounce_ms:
                if self._stable_phone_detected != raw_state:
                    logger.info(
                        "Sensor TCRT5000 (GPIO %d) estabilizado tras %.0f ms -> %s",
                        self.sensor_pin,
                        elapsed_ms,
                        "CELULAR PRESENTE" if raw_state else "COMPARTIMENTO VACÍO",
                    )
                self._stable_phone_detected = raw_state

            return self._stable_phone_detected

    def set_mock_phone_detected(self, detected: bool, bypass_debounce: bool = False) -> None:
        """Inyecta estado en el sensor simulado (PC o API de pruebas)."""
        with self._hw_lock:
            self._mock_phone_detected = detected
            if bypass_debounce:
                self._last_raw_state = detected
                self._stable_phone_detected = detected
                self._last_change_time = time.monotonic() - (self._debounce_ms / 1000.0)
                self._last_elapsed_debounce_ms = self._debounce_ms
            logger.info("Estímulo Sensor TCRT5000 (GPIO %d): raw=%s", self.sensor_pin, detected)

    def toggle_mock_phone_detected(self) -> bool:
        with self._hw_lock:
            new_state = not self._mock_phone_detected
        self.set_mock_phone_detected(new_state, bypass_debounce=False)
        return new_state

    # =========================================================================
    # INDICADORES LUMINOSOS Y ACÚSTICOS
    # =========================================================================

    def set_leds(self, locked: bool) -> None:
        """LED Rojo (GPIO 22) ON cuando está bloqueado; LED Verde (GPIO 23) ON cuando está libre."""
        with self._hw_lock:
            self.led_red_state = locked
            self.led_green_state = not locked
            if IS_RPI:
                GPIO.output(self.led_red, GPIO.HIGH if locked else GPIO.LOW)
                GPIO.output(self.led_green, GPIO.LOW if locked else GPIO.HIGH)

    def beep(self, duration_sec: float = 0.15) -> None:
        """Activa el buzzer activo (GPIO 27 / Pin 13) durante duration_sec."""
        now = time.monotonic()
        with self._hw_lock:
            self.buzzer_active = True
            self._buzzer_off_timestamp = max(self._buzzer_off_timestamp, now + duration_sec)

        if IS_RPI:
            GPIO.output(self.buzzer_pin, GPIO.HIGH)
            time.sleep(duration_sec)
            GPIO.output(self.buzzer_pin, GPIO.LOW)
            with self._hw_lock:
                if time.monotonic() >= self._buzzer_off_timestamp:
                    self.buzzer_active = False
        else:
            logger.debug("Buzzer (GPIO %d): BEEP %.2fs", self.buzzer_pin, duration_sec)

    # =========================================================================
    # TELEMETRÍA Y LIMPIEZA
    # =========================================================================

    def get_hardware_telemetry(self) -> Dict[str, Any]:
        with self._hw_lock:
            stable = self.is_phone_detected()
            now = time.monotonic()
            if self.buzzer_active and now >= self._buzzer_off_timestamp:
                self.buzzer_active = False

            elapsed_ms = min((now - self._last_change_time) * 1000.0, self._debounce_ms)
            is_debouncing = self._last_raw_state != self._stable_phone_detected
            line1, line2 = self.display.get_display_text()

            return {
                "is_rpi": IS_RPI,
                "is_locked": self.is_box_locked,
                "is_lid_closed": self.is_lid_closed,
                "lid_servo_pin": self.lid_servo_pin,
                "lid_angle_deg": self.lid_angle_deg,
                "lock_servo_pin": self.lock_servo_pin,
                "lock_angle_deg": self.lock_angle_deg,
                "servo_freq_hz": self.PWM_FREQUENCY_HZ,
                "sensor_pin": self.sensor_pin,
                "raw_sensor": self._last_raw_state,
                "stable_sensor": stable,
                "is_debouncing": is_debouncing,
                "debounce_elapsed_ms": elapsed_ms,
                "debounce_window_ms": self._debounce_ms,
                "led_red_pin": self.led_red,
                "led_red_on": self.led_red_state,
                "led_green_pin": self.led_green,
                "led_green_on": self.led_green_state,
                "buzzer_pin": self.buzzer_pin,
                "buzzer_on": self.buzzer_active,
                "lcd_line1": line1,
                "lcd_line2": line2,
                "lcd_hardware": self.display.is_hardware_connected,
            }

    def cleanup(self) -> None:
        """Detiene PWM y libera pines GPIO."""
        if IS_RPI:
            if self.pwm_lid is not None:
                self.pwm_lid.stop()
            if self.pwm_lock is not None:
                self.pwm_lock.stop()
            GPIO.cleanup()
        self.display.clear()
        logger.info("Recursos de hardware liberados limpiamente.")
