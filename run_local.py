"""
FocusLock — Lanzador directo del Módulo Local
Ejecutar con: python run_local.py
"""
import os
import sys

# Agregar la carpeta local-module al sys.path
module_dir = os.path.join(os.path.dirname(__file__), "local-module")
sys.path.insert(0, module_dir)

from main import main

if __name__ == "__main__":
    main()
