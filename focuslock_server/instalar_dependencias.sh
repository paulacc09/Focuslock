#!/bin/bash
# FocusLock — Instalador de dependencias en Raspberry Pi OS (Debian Bookworm / Bullseye)
# Compatible con Raspberry Pi 5, 4 y Zero W
cd "$(dirname "$0")"
echo "=========================================================="
echo "  📦 INSTALANDO DEPENDENCIAS EN RASPBERRY PI (PI 5 / 4 / ZERO)"
echo "=========================================================="

sudo apt update

# En Raspberry Pi 5 con Bookworm, python3-rpi-lgpio provee compatibilidad RPi.GPIO sobre el chip RP1.
# En Raspberry Pi 4 y Zero se usa python3-rpi.gpio estándar.
sudo apt install -y python3-pip python3-smbus i2c-tools python3-spidev python3-pil 2>/dev/null

# Intentar instalar python3-rpi-lgpio (Pi 5) o python3-rpi.gpio (Pi 4/3/Zero)
if sudo apt install -y python3-rpi-lgpio 2>/dev/null; then
    echo "  -> Instalado driver GPIO para Raspberry Pi 5 (python3-rpi-lgpio)"
else
    sudo apt install -y python3-rpi.gpio 2>/dev/null || pip3 install rpi-lgpio --break-system-packages 2>/dev/null
    echo "  -> Instalado driver GPIO estándar (python3-rpi.gpio)"
fi

# En Raspberry Pi OS Bookworm (Python 3.11+), pip requiere --break-system-packages para entornos globales
pip3 install -r requirements.txt --break-system-packages || pip3 install -r requirements.txt

echo "=========================================================="
echo "  ✅ INSTALACIÓN COMPLETADA EXITOSAMENTE"
echo "=========================================================="


