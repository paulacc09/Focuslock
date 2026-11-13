#!/bin/bash
# FocusLock — Script de Actualización Automática en Raspberry Pi
# Compatible con Raspberry Pi 5, 4 y Zero W
# Ejecutar desde la memoria USB en la terminal de la Raspberry Pi:
# bash actualizar_en_pi.sh

echo "============================================================"
echo "🚀 ACTUALIZANDO FOCUSLOCK EN RASPBERRY PI (PI 5 / 4 / ZERO)..."
echo "============================================================"

# Directorio donde está este script (en la USB)
DIR_USB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Habilitar SPI e I2C en la Raspberry Pi si no están activos
echo -e "\n[1/3] Habilitando interfaces SPI e I2C en Raspberry Pi..."
sudo raspi-config nonint do_spi 0
sudo raspi-config nonint do_i2c 0

# 2. Instalar librerías necesarias (incluyendo soporte Pi 5 RP1)
echo -e "\n[2/3] Instalando librerías de hardware en Raspberry Pi..."
sudo apt update && sudo apt install -y python3-spidev python3-pil python3-smbus i2c-tools
sudo apt install -y python3-rpi-lgpio 2>/dev/null || sudo apt install -y python3-rpi.gpio 2>/dev/null

# 3. Copiar archivos actualizados a la carpeta de la Pi
echo -e "\n[3/3] Copiando código actualizado a ~/focuslock_server/..."
mkdir -p ~/focuslock_server
cp -rf "$DIR_USB/focuslock_server/"* ~/focuslock_server/

echo -e "\n============================================================"
echo "✅ ¡ACTUALIZACIÓN COMPLETADA CON ÉXITO!"
echo "Para iniciar el sistema ejecuta:"
echo "   cd ~/focuslock_server && python3 main.py"
echo "============================================================"

