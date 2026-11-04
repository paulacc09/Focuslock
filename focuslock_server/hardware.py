"""
FocusLock — Controlador de Hardware Embebido (Raspberry Pi Zero W / BCM2835)
Asignatura: Electrónica Digital III (Entrega 30%)

===============================================================================
FUNDAMENTACIÓN TÉCNICA Y CÁLCULOS DE TEMPORIZACIÓN (PWM & DEBOUNCE)
===============================================================================
1. Control PWM del Servomotor SG90 (GPIO 18 — Canal PWM0 Hardware):
   - Frecuencia de portadora PWM: f_pwm = 50 Hz
   - Periodo de la señal: T = 1 / f_pwm = 1 / 50 Hz = 0.020 s = 20.0 ms
   - Relación de Ciclo de Trabajo (Duty Cycle): D(%) = (t_on / T) * 100
     * Posición 0° (Cerrojo Desbloqueado / Abierto):
       t_on = 1.0 ms  =>  D = (1.0 ms / 20.0 ms) * 100 = 5.0%
     * Posición 90° (Cerrojo Bloqueado / Enclavado):
       t_on = 2.0 ms  =>  D = (2.0 ms / 20.0 ms) * 100 = 10.0%
   - Mitigación de Jitter y Disipación Térmica:
     Tras aplicar el tren de pulsos durante t_settle = 400 ms (20 ciclos PWM
     completos, suficientes para alcanzar la posición angular nominal a
     velocidad de 0.12 s / 60°), se fuerza D = 0.0% para cortar la corriente
     de mantenimiento del puente H interno del SG90, eliminando el temblor
     mecánico (jitter por cuantización de reloj) y el calentamiento en reposo.

2. Sensor Óptico Reflexivo Infrarrojo TCRT5000 (GPIO 17 — Entrada Digital):
   - Configuración eléctrica: Pull-Up interno activado (R_pu ~ 50 kOhm a 3.3V).
   - Lógica activa en bajo (Active-Low):
     * Nivel ALTO (3.3V, GPIO.HIGH): Sin reflexión IR -> Compartimento VACÍO.
     * Nivel BAJO (0.0V, GPIO.LOW): Reflexión IR saturada -> Smartphone PRESENTE.
   - Filtro Antirrebote por Software (Software Debounce):
     * Ventana de estabilidad continua: t_debounce = 200 ms.
     * Reloj monotónico: time.monotonic() (inmune a ajustes NTP del sistema).
     * Condición de transición válida:
       |t_actual - t_ultimo_cambio_crudo| * 1000 >= 200.0 ms
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

logger = logging.getLogger("FocusLock.Hardware")


class HardwareController:
    """
    Capa de abstracción de hardware (HAL) para la estación física FocusLock.
    Opera de forma transparente sobre el SoC BCM2835 (Raspberry Pi Zero W)
    o en modo de simulación determinista para validación en PC.
    """

    PWM_FREQUENCY_HZ: int = 50
    PWM_PERIOD_MS: float = 20.0
    DUTY_UNLOCKED_PERCENT: float = 5.0   # 1.0 ms / 20.0 ms = 5.0% (0°)
    DUTY_LOCKED_PERCENT: float = 10.0    # 2.0 ms / 20.0 ms = 10.0% (90°)
    SERVO_SETTLE_SEC: float = 0.400      # 400 ms antes de cortar pulso (duty = 0%)
    DEBOUNCE_WINDOW_MS: float = 200.0    # 200 ms de estabilidad continua

    def __init__(
        self,
        servo_pin: int = 18,
        sensor_pin: int = 17,
        buzzer_pin: int = 27,
        led_red: int = 22,
        led_green: int = 23,
    ) -> None:
        self.servo_pin: int = servo_pin
        self.sensor_pin: int = sensor_pin
        self.buzzer_pin: int = buzzer_pin
        self.led_red: int = led_red
        self.led_green: int = led_green

        self._hw_lock = threading.RLock()

        # Estado del actuador y telemetría de pines
        self.is_locked: bool = False
        self.servo_angle_deg: int = 0
        self.servo_pulse_ms: float = 1.0
        self.servo_duty_cycle: float = 0.0
        self.led_red_state: bool = False
        self.led_green_state: bool = True
        self.buzzer_active: bool = False
        self._buzzer_off_timestamp: float = 0.0

        # Estado del filtro antirrebote (200 ms con time.monotonic())
        self._mock_phone_detected: bool = False
        self._debounce_ms: float = self.DEBOUNCE_WINDOW_MS
        self._last_raw_state: bool = False
        self._last_change_time: float = time.monotonic()
        self._stable_phone_detected: bool = False
        self._last_elapsed_debounce_ms: float = self.DEBOUNCE_WINDOW_MS

        self.pwm: Optional[Any] = None

        if IS_RPI:
            GPIO.setmode(GPIO.BCM)
            GPIO.setwarnings(False)

            # Actuador Servo PWM (GPIO 18 — 50 Hz, T = 20 ms)
            GPIO.setup(self.servo_pin, GPIO.OUT)
            self.pwm = GPIO.PWM(self.servo_pin, self.PWM_FREQUENCY_HZ)
            self.pwm.start(0)

            # Sensor TCRT5000 (GPIO 17) con pull-up interno
            GPIO.setup(self.sensor_pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

            # Buzzer (GPIO 27) y LEDs de estado (GPIO 22 Rojo, GPIO 23 Verde)
            GPIO.setup(self.buzzer_pin, GPIO.OUT, initial=GPIO.LOW)
            GPIO.setup(self.led_red, GPIO.OUT, initial=GPIO.LOW)
            GPIO.setup(self.led_green, GPIO.OUT, initial=GPIO.HIGH)
            logger.info("GPIO inicializado en Raspberry Pi Zero W (BCM2835).")
        else:
            logger.info("Ejecutando en Modo Simulación HAL (PC / Sin RPi.GPIO).")

        # Garantizar estado inicial seguro (0° Desbloqueado)
        self.unlock_door()

    def lock_door(self) -> None:
        """
        Enclava el cerrojo mecánicamente en posición 90°.
        Cálculo PWM:
          - Frecuencia f = 50 Hz (Periodo T = 20 ms)
          - Ancho de pulso t_on = 2.0 ms -> Duty Cycle = (2.0 / 20.0) * 100 = 10.0%
          - Tras 400 ms de posicionamiento, fuerza Duty Cycle = 0.0% para
            eliminar jitter mecánico y disipación térmica en el servomotor SG90.
        """
        with self._hw_lock:
            self.is_locked = True
            self.servo_angle_deg = 90
            self.servo_pulse_ms = 2.0
            self.servo_duty_cycle = self.DUTY_LOCKED_PERCENT
            self.set_leds(locked=True)

        if IS_RPI and self.pwm is not None:
            self.pwm.ChangeDutyCycle(self.DUTY_LOCKED_PERCENT)
            time.sleep(self.SERVO_SETTLE_SEC)
            self.pwm.ChangeDutyCycle(0.0)

        with self._hw_lock:
            self.servo_duty_cycle = 0.0  # Pulso detenido tras 400 ms (anti-jitter)

        logger.info("Cerrojo PWM (GPIO %d): 90° BLOQUEADO (2.0ms @ 50Hz -> Duty 10.0%% -> 0%%)", self.servo_pin)

    def unlock_door(self) -> None:
        """
        Retrae el cerrojo mecánicamente a la posición 0° (Abierto).
        Cálculo PWM:
          - Frecuencia f = 50 Hz (Periodo T = 20 ms)
          - Ancho de pulso t_on = 1.0 ms -> Duty Cycle = (1.0 / 20.0) * 100 = 5.0%
          - Tras 400 ms de posicionamiento, fuerza Duty Cycle = 0.0% para
            eliminar jitter mecánico y sobrecalentamiento del SG90.
        """
        with self._hw_lock:
            self.is_locked = False
            self.servo_angle_deg = 0
            self.servo_pulse_ms = 1.0
            self.servo_duty_cycle = self.DUTY_UNLOCKED_PERCENT
            self.set_leds(locked=False)

        if IS_RPI and self.pwm is not None:
            self.pwm.ChangeDutyCycle(self.DUTY_UNLOCKED_PERCENT)
            time.sleep(self.SERVO_SETTLE_SEC)
            self.pwm.ChangeDutyCycle(0.0)

        with self._hw_lock:
            self.servo_duty_cycle = 0.0  # Pulso detenido tras 400 ms (anti-jitter)

        logger.info("Cerrojo PWM (GPIO %d): 0° DESBLOQUEADO (1.0ms @ 50Hz -> Duty 5.0%% -> 0%%)", self.servo_pin)

    def _read_raw_sensor(self) -> bool:
        """Lectura instantánea sin filtrar del pin GPIO 17 (lógica activa en bajo)."""
        if IS_RPI:
            return bool(GPIO.input(self.sensor_pin) == GPIO.LOW)
        return self._mock_phone_detected

    def is_phone_detected(self) -> bool:
        """
        Evalúa el sensor óptico TCRT5000 (GPIO 17) aplicando el algoritmo de
        debounce por software de 200 ms mediante reloj monotónico `time.monotonic()`.

        Exige 200 ms de estabilidad continua en la señal de entrada antes de
        conmutar el estado lógico validado (`_stable_phone_detected`), filtrando
        rebotes mecánicos o reflexiones espurias durante la inserción del celular.
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
                        "PRESENTE / OBSTÁCULO" if raw_state else "VACÍO",
                    )
                self._stable_phone_detected = raw_state

            return self._stable_phone_detected

    def set_mock_phone_detected(self, detected: bool, bypass_debounce: bool = False) -> None:
        """
        Inyecta un cambio de nivel en el sensor óptico simulado (PC o endpoint de test).
        Por defecto pasa por el filtro antirrebote real de 200 ms con `time.monotonic()`
        para que en la consola interactiva se observe la progresión del debounce.
        """
        with self._hw_lock:
            self._mock_phone_detected = detected
            if bypass_debounce:
                self._last_raw_state = detected
                self._stable_phone_detected = detected
                self._last_change_time = time.monotonic() - (self._debounce_ms / 1000.0)
                self._last_elapsed_debounce_ms = self._debounce_ms
            logger.info("Estímulo Sensor TCRT5000 (GPIO %d): señal cruda = %s", self.sensor_pin, detected)

    def toggle_mock_phone_detected(self) -> bool:
        """Conmuta la presencia simulada del smartphone en el sensor TCRT5000."""
        with self._hw_lock:
            new_state = not self._mock_phone_detected
        self.set_mock_phone_detected(new_state, bypass_debounce=False)
        return new_state

    def set_leds(self, locked: bool) -> None:
        """Actualiza los indicadores luminosos: LED Rojo (Pin 22) y LED Verde (Pin 23)."""
        with self._hw_lock:
            self.led_red_state = locked
            self.led_green_state = not locked
            if IS_RPI:
                GPIO.output(self.led_red, GPIO.HIGH if locked else GPIO.LOW)
                GPIO.output(self.led_green, GPIO.LOW if locked else GPIO.HIGH)

    def beep(self, duration_sec: float = 0.15) -> None:
        """
        Activa el Buzzer piezoeléctrico activo (GPIO 27) durante `duration_sec`.
        Registra la ventana temporal para reflejar el estado en la telemetría CLI.
        """
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

    def get_hardware_telemetry(self) -> Dict[str, Any]:
        """
        Devuelve una instantánea completa y thread-safe del estado físico de los pines
        GPIO, parámetros PWM y temporización del filtro de debounce para la consola CLI.
        """
        with self._hw_lock:
            stable = self.is_phone_detected()
            now = time.monotonic()
            if self.buzzer_active and now >= self._buzzer_off_timestamp:
                self.buzzer_active = False

            elapsed_ms = min((now - self._last_change_time) * 1000.0, self._debounce_ms)
            is_debouncing = self._last_raw_state != self._stable_phone_detected

            return {
                "is_rpi": IS_RPI,
                "is_locked": self.is_locked,
                "servo_pin": self.servo_pin,
                "servo_angle_deg": self.servo_angle_deg,
                "servo_pulse_ms": self.servo_pulse_ms,
                "servo_freq_hz": self.PWM_FREQUENCY_HZ,
                "servo_duty_expected": (
                    self.DUTY_LOCKED_PERCENT if self.is_locked else self.DUTY_UNLOCKED_PERCENT
                ),
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
            }

    def cleanup(self) -> None:
        """Libera los canales PWM y restablece los registros GPIO del SoC."""
        if IS_RPI:
            if self.pwm is not None:
                self.pwm.stop()
            GPIO.cleanup()
        logger.info("Recursos de hardware liberados limpiamente.")
