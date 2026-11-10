#!/usr/bin/env python3
"""
FocusLock — Script de Diagnóstico Rápido de Hardware (LCD I2C y Servomotores)
Ejecutar en la Raspberry Pi 4 con: python3 test_hardware.py
"""

import sys
import time

print("=" * 65)
print("🔍 FOCUSLOCK — DIAGNÓSTICO DE PANTALLA LCD Y SERVOMOTORES")
print("=" * 65)

# -------------------------------------------------------------
# 1. PRUEBA DE I2C Y PANTALLA LCD
# -------------------------------------------------------------
print("\n[1/3] Verificando bus I2C y Pantalla LCD...")
try:
    import smbus2 as smbus
except ImportError:
    try:
        import smbus
    except ImportError:
        smbus = None

if smbus is None:
    print("❌ ERROR: La librería 'smbus' o 'smbus2' no está instalada.")
    print("   Ejecuta: sudo apt update && sudo apt install -y python3-smbus i2c-tools")
else:
    try:
        bus = smbus.SMBus(1)
        found_addrs = []
        for addr in (0x27, 0x3F, 0x26, 0x20):
            try:
                bus.write_quick(addr)
                found_addrs.append(hex(addr))
            except Exception:
                pass

        if found_addrs:
            print(f"✅ ¡Módulo I2C detectado en: {', '.join(found_addrs)}!")
            from display import DisplayController
            disp = DisplayController()
            disp.show_message("FOCUSLOCK TEST", "LCD FUNCIONANDO!")
            print("   -> Enviando mensaje de prueba a la pantalla LCD...")
            print("   -> Si la pantalla sigue viéndose en blanco/azul, GIRA EL")
            print("      TORNILLO AZUL (potenciómetro) detrás de la pantalla para ajustar el contraste.")
        else:
            print("⚠️ No se detectó ninguna pantalla en el bus I2C.")
            print("   Verificaciones obligatorias:")
            print("   a) ¿El I2C está habilitado en la Raspberry? Ejecuta: sudo raspi-config nonint do_i2c 0")
            print("   b) Pines LCD I2C:")
            print("      - VCC -> Pin 2 o 4 (5V obligatorio)")
            print("      - GND -> Pin 6 o cualquier GND")
            print("      - SDA -> Pin 3 (GPIO 2)")
            print("      - SCL -> Pin 5 (GPIO 3)")
    except Exception as e:
        print(f"❌ Error al abrir bus I2C: {e}")
        print("   Solución: Ejecuta 'sudo raspi-config nonint do_i2c 0' y reinicia la Pi.")

# -------------------------------------------------------------
# 2. PRUEBA DE SERVOMOTORES (Pines Físicos 12 y 33)
# -------------------------------------------------------------
print("\n[2/3] Verificando Servomotores SG90...")
try:
    import RPi.GPIO as GPIO
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)

    PIN_TAPA = 18    # Pin Físico 12 (GPIO 18)
    PIN_BLOQUEO = 13 # Pin Físico 33 (GPIO 13)

    GPIO.setup(PIN_TAPA, GPIO.OUT)
    GPIO.setup(PIN_BLOQUEO, GPIO.OUT)

    pwm_tapa = GPIO.PWM(PIN_TAPA, 50)
    pwm_bloqueo = GPIO.PWM(PIN_BLOQUEO, 50)
    pwm_tapa.start(0)
    pwm_bloqueo.start(0)

    print("\n   ⚠️ REVISIÓN CRÍTICA DE CABLES DE LOS SERVOS:")
    print("   - Cable MARRÓN o NEGRO -> GND (Tierra de la Pi, ej. Pin 6, 9, 14, 20)")
    print("   - Cable ROJO           -> 5V (Alimentación, Pin 2 o Pin 4)")
    print("   - Cable NARANJA/AMARILLO (Señal):")
    print("       * Servo Tapa:    PIN FÍSICO 12 (GPIO 18) [6to pin del lado derecho]")
    print("       * Servo Bloqueo: PIN FÍSICO 33 (GPIO 13) [17mo pin del lado izquierdo]")

    print("\n--- Probando SERVO TAPA (GPIO 18 / Pin Físico 12) ---")
    print("Moviendo a 0° (Abierta)...")
    pwm_tapa.ChangeDutyCycle(5.0)
    time.sleep(1.0)
    print("Moviendo a 90° (Cerrada)...")
    pwm_tapa.ChangeDutyCycle(10.0)
    time.sleep(1.0)
    print("Volviendo a 0°...")
    pwm_tapa.ChangeDutyCycle(5.0)
    time.sleep(1.0)
    pwm_tapa.ChangeDutyCycle(0)

    print("\n--- Probando SERVO BLOQUEO (GPIO 13 / Pin Físico 33) ---")
    print("Moviendo a 0° (Desbloqueado)...")
    pwm_bloqueo.ChangeDutyCycle(5.0)
    time.sleep(1.0)
    print("Moviendo a 90° (Bloqueado)...")
    pwm_bloqueo.ChangeDutyCycle(10.0)
    time.sleep(1.0)
    print("Volviendo a 0°...")
    pwm_bloqueo.ChangeDutyCycle(5.0)
    time.sleep(1.0)
    pwm_bloqueo.ChangeDutyCycle(0)

    pwm_tapa.stop()
    pwm_bloqueo.stop()
    GPIO.cleanup()
    print("\n✅ Prueba de servos enviada correctamente.")

except Exception as e:
    print(f"❌ Error al controlar GPIO: {e}")

print("\n" + "=" * 65)

