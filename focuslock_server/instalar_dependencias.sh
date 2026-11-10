#!/bin/bash
# FocusLock — Instalador de dependencias en Raspberry Pi OS (Debian Bookworm / Bullseye)
cd "$(dirname "$0")"
echo "=========================================================="
echo "  📦 INSTALANDO DEPENDENCIAS EN RASPBERRY PI 4"
echo "=========================================================="

sudo apt update
sudo apt install -y python3-pip python3-rpi.gpio python3-smbus i2c-tools

# En Raspberry Pi OS Bookworm (Python 3.11+), pip requiere --break-system-packages para entornos globales
pip3 install -r requirements.txt --break-system-packages || pip3 install -r requirements.txt

echo "=========================================================="
echo "  ✅ INSTALACIÓN COMPLETADA EXITOSAMENTE"
echo "=========================================================="

