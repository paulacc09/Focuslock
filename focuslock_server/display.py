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
    Controlador SPI para Pantalla TFT 2.8" ILI9341 en orientación Horizontal (Landscape 320x240).
    """
    WIDTH = 320
    HEIGHT = 240

    def __init__(
        self,
        dc_pin: int = 24,    # Pin Físico 18 (GPIO 24)
        rst_pin: int = 25,   # Pin Físico 22 (GPIO 25)
        cs_pin: int = 8,     # Pin Físico 24 (GPIO 8)
        spi_bus: int = 0,
        spi_dev: int = 0,
        speed_hz: int = 24000000,
        rotation: int = 1,   # 1: Landscape 320x240 (0x68), 3: Landscape 180° (0xA8)
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

        # Orientación Horizontal Landscape (320x240)
        # Registro 0x36 MADCTL:
        # 0x68 = Landscape normal (MV=1, MX=1, BGR=1)
        # 0xA8 = Landscape rotado 180° (MV=1, MY=1, BGR=1)
        self.write_cmd(0x36)
        madctl = 0x68 if self.rotation == 1 else 0xA8
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
    Gestiona la pantalla TFT física en horizontal (320x240) y el búfer en memoria.
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
                logger.info("✅ Pantalla TFT 2.8\" SPI (ILI9341) inicializada en modo Horizontal (320x240).")
            except Exception as ex:
                logger.error("❌ Error al iniciar TFT SPI: %s", ex)

        self.show_idle()

    def _render_tft(self, title: str, subtitle: str, theme_color: str = "#22C55E") -> None:
        if not self.is_hardware_connected or self.tft_driver is None or not HAVE_PIL:
            return

        try:
            # Lienzo horizontal 320 ancho x 240 alto (Landscape)
            img = Image.new("RGB", (320, 240), color="#0B132B")
            draw = ImageDraw.Draw(img)

            # Fuentes grandes y legibles para TFT Horizontal 320x240
            try:
                font_brand = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
                font_label = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
                font_title = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
                font_subtitle = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 28)
                font_footer = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 13)
            except Exception:
                try:
                    font_brand = ImageFont.truetype("arialbd.ttf", 22)
                    font_label = ImageFont.truetype("arial.ttf", 15)
                    font_title = ImageFont.truetype("arialbd.ttf", 26)
                    font_subtitle = ImageFont.truetype("arialbd.ttf", 28)
                    font_footer = ImageFont.truetype("arial.ttf", 13)
                except Exception:
                    font_brand = font_label = font_title = font_subtitle = font_footer = ImageFont.load_default()

            # 1. Barra superior con marca y LED indicador visual
            draw.rectangle([(0, 0), (320, 48)], fill="#1C2541")
            draw.text((16, 12), "FOCUSLOCK", fill="#38BDF8", font=font_brand)
            draw.ellipse([(282, 14), (304, 36)], fill=theme_color, outline="#FFFFFF", width=2)

            # 2. Tarjeta principal de estado (diseño panorámico)
            draw.rounded_rectangle([(12, 58), (308, 228)], radius=14, fill="#1C2541", outline=theme_color, width=3)

            # Etiqueta y Título principal (Letras grandes)
            draw.text((24, 68), "ESTADO DEL SISTEMA:", fill="#94A3B8", font=font_label)
            draw.text((24, 92), title, fill="#FFFFFF", font=font_title)

            # Separador horizontal
            draw.line([(24, 134), (296, 134)], fill="#334155", width=2)

            # Subtítulo / Temporizador (Letras grandes con color del tema)
            draw.text((24, 146), subtitle, fill=theme_color, font=font_subtitle)

            # 3. Pie de tarjeta
            draw.rectangle([(15, 198), (305, 225)], fill="#141C2E")
            draw.text((24, 204), "Estacion Mecatronica Inteligente", fill="#38BDF8", font=font_footer)

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
