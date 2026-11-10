#!/bin/bash
# FocusLock — Script de Actualización Automática en Raspberry Pi
# Ejecutar desde la memoria USB en la terminal de la Raspberry Pi:
# bash actualizar_en_pi.sh

echo "============================================================"
echo "🚀 ACTUALIZANDO FOCUSLOCK EN RASPBERRY PI..."
echo "============================================================"

# Directorio donde está este script (en la USB)
DIR_USB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Habilitar SPI en la Raspberry Pi si no está activo
echo "\n[1/3] Habilitando interfaz SPI en Raspberry Pi..."
sudo raspi-config nonint do_spi 0

# 2. Instalar librerías necesarias para pantalla TFT SPI
echo "\n[2/3] Instalando librerías de Python (spidev y Pillow)..."
sudo apt update && sudo apt install -y python3-spidev python3-pil

# 3. Copiar archivos actualizados a la carpeta de la Pi
echo "\n[3/3] Copiando código actualizado a ~/focuslock_server/..."
mkdir -p ~/focuslock_server
cp -rf "$DIR_USB/focuslock_server/"* ~/focuslock_server/

echo "\n============================================================"
echo "✅ ¡ACTUALIZACIÓN COMPLETADA CON ÉXITO!"
echo "Para iniciar el sistema ejecuta:"
echo "   cd ~/focuslock_server && python3 main.py"
echo "============================================================"

