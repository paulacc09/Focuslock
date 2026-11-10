#!/bin/bash
# FocusLock — Script de inicio del Servidor API REST
cd "$(dirname "$0")"
echo "=========================================================="
echo "  🚀 INICIANDO SERVIDOR FOCUSLOCK (API REST) EN RASPBERRY PI"
echo "=========================================================="
echo "IP Local de la Raspberry Pi:"
hostname -I
echo "=========================================================="
python3 main.py

