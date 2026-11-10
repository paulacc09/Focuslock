"""
FocusLock — Controlador de Pantalla TFT 2.8" SPI (ILI9341 240x320 Portrait)
Asignatura: Electrónica Digital III

Pines oficiales (Esquemático FocusLock):
- VCC         -> Pin 1 RPi (3.3V)
- GND         -> Pin 6 RPi (GND)
- CS          -> Pin 24 RPi (GPIO 8 / CE0)
- RESET       -> Pin 22 RPi (GPIO 25)
- DC / RS     -> Pin 18 RPi (GPIO 24)
- SDI (MOSI)  -> Pin 19 RPi (GPIO 10 / MOSI)
- SCK (CLK)   -> Pin 23 RPi (GPIO 11 / SCLK)
- LED         -> Pin 17 RPi (3.3V Retroiluminación)
"""

from __future__ import annotations

import logging
import threading
import time
from typing import Optional, Tuple

logger = logging.getLogger("FocusLock.Display")

HAVE_SPI = False
HAVE_GPIO = False
HAVE_PIL = False

try:
    import spidev  # type: ignore
    HAVE_SPI = True
except ImportError:
    pass

try:
    import RPi.GPIO as GPIO  # type: ignore
    HAVE_GPIO = True
except ImportError:
    pass

try:
    from PIL import Image, ImageDraw, ImageFont  # type: ignore
    HAVE_PIL = True
except ImportError:
    pass


class ILI9341SPIDriver:
    """
    Controlador SPI para Pantalla TFT 2.8" ILI9341 en orientación Vertical (Portrait 240x320)
    con el conector de pines en la parte superior.
    """
    WIDTH = 240
    HEIGHT = 320

    def __init__(
        self,
        dc_pin: int = 24,    # Pin Físico 18 (GPIO 24)
        rst_pin: int = 25,   # Pin Físico 22 (GPIO 25)
        cs_pin: int = 8,     # Pin Físico 24 (GPIO 8)
        spi_bus: int = 0,
        spi_dev: int = 0,
        speed_hz: int = 24000000,
        rotation: int = 0,   # 0: Portrait (Pines arriba), 2: Portrait 180°
    ) -> None:
        self.dc_pin = dc_pin
        self.rst_pin = rst_pin
        self.cs_pin = cs_pin
        self.rotation = rotation

        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.dc_pin, GPIO.OUT, initial=GPIO.HIGH)
        GPIO.setup(self.rst_pin, GPIO.OUT, initial=GPIO.HIGH)

        self.spi = spidev.SpiDev()
        self.spi.open(spi_bus, spi_dev)
        self.spi.max_speed_hz = speed_hz
        self.spi.mode = 0

        self.reset()
        self.init_display()

    def reset(self) -> None:
        GPIO.output(self.rst_pin, GPIO.HIGH)
        time.sleep(0.05)
        GPIO.output(self.rst_pin, GPIO.LOW)
        time.sleep(0.05)
        GPIO.output(self.rst_pin, GPIO.HIGH)
        time.sleep(0.15)

    def write_cmd(self, cmd: int) -> None:
        GPIO.output(self.dc_pin, GPIO.LOW)
        self.spi.writebytes([cmd])

    def write_data(self, data) -> None:
        GPIO.output(self.dc_pin, GPIO.HIGH)
        if isinstance(data, int):
            self.spi.writebytes([data])
        elif isinstance(data, (list, bytearray)):
            chunk_size = 4096
            for i in range(0, len(data), chunk_size):
                self.spi.writebytes(list(data[i:i + chunk_size]))

    def init_display(self) -> None:
        self.write_cmd(0x01)  # Software Reset
        time.sleep(0.12)
        self.write_cmd(0x28)  # Display OFF

        # Orientación Vertical Portrait sin efecto espejo
        # Registro 0x36 MADCTL:
        # 0x08 = Portrait normal (BGR)
        # 0x48 = Portrait con corrección de columna si se requiriese
        self.write_cmd(0x36)
        madctl = 0x08 if self.rotation == 0 else 0xC8
        self.write_data(madctl)

        # Formato de píxel: 16-bit RGB565
        self.write_cmd(0x3A)
        self.write_data(0x55)

        self.write_cmd(0x11)  # Sleep Out
        time.sleep(0.12)

        self.write_cmd(0x29)  # Display ON
        time.sleep(0.02)

    def set_window(self, x0: int, y0: int, x1: int, y1: int) -> None:
        self.write_cmd(0x2A)
        self.write_data([x0 >> 8, x0 & 0xFF, x1 >> 8, x1 & 0xFF])
        self.write_cmd(0x2B)
        self.write_data([y0 >> 8, y0 & 0xFF, y1 >> 8, y1 & 0xFF])
        self.write_cmd(0x2C)

    def display_image(self, img: Image.Image) -> None:
        if img.size != (self.WIDTH, self.HEIGHT):
            img = img.resize((self.WIDTH, self.HEIGHT))
        if img.mode != "RGB":
            img = img.convert("RGB")

        self.set_window(0, 0, self.WIDTH - 1, self.HEIGHT - 1)
        pixels = img.tobytes()

        # Conversión de RGB888 a RGB565
        buffer = bytearray(self.WIDTH * self.HEIGHT * 2)
        idx = 0
        for i in range(0, len(pixels), 3):
            r = pixels[i] >> 3
            g = pixels[i + 1] >> 2
            b = pixels[i + 2] >> 3
            rgb565 = (r << 11) | (g << 5) | b
            buffer[idx] = (rgb565 >> 8) & 0xFF
            buffer[idx + 1] = rgb565 & 0xFF
            idx += 2

        self.write_data(buffer)


class DisplayController:
    """
    Controlador unificado de visualización para FocusLock.
    Gestiona la pantalla TFT física en vertical (240x320) y el búfer en memoria.
    """

    def __init__(self) -> None:
        self._lock = threading.RLock()
        self.line1: str = "FOCUSLOCK"
        self.line2: str = "Iniciando..."
        self.tft_driver: Optional[ILI9341SPIDriver] = None
        self.is_hardware_connected: bool = False

        if HAVE_SPI and HAVE_GPIO:
            try:
                self.tft_driver = ILI9341SPIDriver()
                self.is_hardware_connected = True
                logger.info("✅ Pantalla TFT 2.8\" SPI (ILI9341) inicializada correctamente en modo Vertical.")
            except Exception as ex:
                logger.error("❌ Error al iniciar TFT SPI: %s", ex)

        self.show_idle()

    def _render_tft(self, title: str, subtitle: str, theme_color: str = "#22C55E") -> None:
        if not self.is_hardware_connected or self.tft_driver is None or not HAVE_PIL:
            return

        try:
            # Lienzo vertical 240 ancho x 320 alto (Pines arriba)
            img = Image.new("RGB", (240, 320), color="#0B132B")
            draw = ImageDraw.Draw(img)

            # Barra superior con marca
            draw.rectangle([(0, 0), (240, 48)], fill="#1C2541")
            draw.text((16, 16), "FOCUSLOCK", fill="#48CAE4")
            draw.ellipse([(210, 18), (222, 30)], fill=theme_color)

            # Tarjeta de estado principal
            draw.rounded_rectangle([(12, 65), (228, 290)], radius=14, fill="#1C2541", outline=theme_color, width=3)

            # Texto de estado
            draw.text((24, 100), "ESTADO:", fill="#8D99AE")
            draw.text((24, 130), title, fill="#FFFFFF")

            # Separador sutil
            draw.line([(24, 175), (216, 175)], fill="#3A506B", width=1)

            # Texto secundario / Temporizador destacado
            draw.text((24, 195), subtitle, fill=theme_color)

            # Pie de tarjeta
            draw.text((24, 255), "Estacion Inteligente", fill="#5BC0BE")

            self.tft_driver.display_image(img)
        except Exception as ex:
            logger.debug("Error al renderizar TFT: %s", ex)

    def show_message(self, line1: str, line2: str = "", theme: str = "#22C55E") -> None:
        with self._lock:
            self.line1 = line1.strip()
            self.line2 = line2.strip()
            self._render_tft(self.line1, self.line2, theme_color=theme)

    def show_idle(self) -> None:
        self.show_message("SISTEMA LISTO", "Inicie sesion...", theme="#22C55E")

    def show_waiting_phone(self, remaining_sec: int) -> None:
        self.show_message("COLOQUE CELULAR", f"Espera: {remaining_sec:02d} seg", theme="#EAB308")

    def show_grace_period(self, seconds_left: int) -> None:
        self.show_message("ATENCION: CIERRE", f"Caja en: {seconds_left:02d} seg", theme="#F97316")

    def show_locked_focus(self, time_str: str) -> None:
        self.show_message("ENFOQUE ACTIVO", f"Restante: {time_str}", theme="#EF4444")

    def show_break(self, time_str: str) -> None:
        self.show_message("TIEMPO DESCANSO", f"Libre: {time_str}", theme="#10B981")

    def show_emergency(self) -> None:
        self.show_message("! EMERGENCIA !", "Caja abierta", theme="#DC2626")

    def get_display_text(self) -> Tuple[str, str]:
        with self._lock:
            return self.line1, self.line2
