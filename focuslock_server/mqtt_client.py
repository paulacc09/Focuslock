"""
FocusLock — Cliente MQTT para Broker Eclipse Mosquitto (Raspberry Pi 5 / Edge)
==============================================================================
Permite que el módulo embebido en la Raspberry Pi 5 publique eventos de hardware
(sensor óptico TCRT5000, ángulos de ambos servomotores SG90, estado de la FSM)
hacia el broker local Mosquitto y reciba comandos remotos por tópicos MQTT.

Tópicos utilizados:
  - Publicación:
      * focuslock/fsm/state          -> Cambios de estado de la FSM y cronómetro
      * focuslock/hardware/telemetry -> Estado del sensor IR, servos, LEDs y buzzer
  - Suscripción:
      * focuslock/commands           -> Comandos JSON: start, cancel, emergency_unlock
"""

from __future__ import annotations

import json
import logging
import os
import threading
from typing import Any, Callable, Dict, Optional

logger = logging.getLogger("FocusLock.MQTT")

try:
    import paho.mqtt.client as mqtt  # type: ignore

    MQTT_AVAILABLE = True
except ImportError:
    mqtt = None  # type: ignore
    MQTT_AVAILABLE = False


class FocusLockMQTTClient:
    """Cliente MQTT no bloqueante con reconexión automática para Eclipse Mosquitto."""

    TOPIC_FSM_STATE = "focuslock/fsm/state"
    TOPIC_HARDWARE_TELEMETRY = "focuslock/hardware/telemetry"
    TOPIC_COMMANDS = "focuslock/commands"

    def __init__(
        self,
        broker_host: Optional[str] = None,
        broker_port: Optional[int] = None,
        on_command: Optional[Callable[[Dict[str, Any]], None]] = None,
    ) -> None:
        self.broker_host: str = broker_host or os.getenv("MQTT_BROKER_HOST", "127.0.0.1")
        self.broker_port: int = broker_port or int(os.getenv("MQTT_BROKER_PORT", "1883"))
        self.on_command = on_command
        self.connected: bool = False
        self._client: Optional[Any] = None
        self._lock = threading.Lock()

    def start(self) -> bool:
        """Inicia la conexión asíncrona en segundo plano con el broker Mosquitto."""
        if not MQTT_AVAILABLE:
            logger.warning("Librería 'paho-mqtt' no instalada. Cliente Mosquitto en modo deshabilitado.")
            return False

        try:
            # Compatible con paho-mqtt 2.x y 1.x
            if hasattr(mqtt, "CallbackAPIVersion"):
                client = mqtt.Client(
                    callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
                    client_id="focuslock_rpi5_edge",
                )
            else:
                client = mqtt.Client(client_id="focuslock_rpi5_edge")

            client.on_connect = self._handle_connect
            client.on_disconnect = self._handle_disconnect
            client.on_message = self._handle_message

            username = os.getenv("MQTT_USERNAME")
            password = os.getenv("MQTT_PASSWORD")
            if username:
                client.username_pw_set(username, password)

            client.connect_async(self.broker_host, self.broker_port, keepalive=60)
            client.loop_start()
            self._client = client
            logger.info(
                "Cliente MQTT Mosquitto iniciado (Broker %s:%d).",
                self.broker_host,
                self.broker_port,
            )
            return True
        except Exception as exc:
            logger.warning("No se pudo iniciar el cliente MQTT Mosquitto: %s", exc)
            return False

    def _handle_connect(self, client: Any, userdata: Any, flags: Any, reason_code: Any, properties: Any = None) -> None:
        if str(reason_code) in ("0", "Success"):
            self.connected = True
            client.subscribe(self.TOPIC_COMMANDS, qos=1)
            logger.info("Conectado a Eclipse Mosquitto en %s:%d (suscrito a %s).", self.broker_host, self.broker_port, self.TOPIC_COMMANDS)
        else:
            logger.warning("Conexión MQTT rechazada con código: %s", reason_code)

    def _handle_disconnect(self, client: Any, userdata: Any, disconnect_flags: Any = None, reason_code: Any = None, properties: Any = None) -> None:
        self.connected = False
        logger.warning("Desconectado del broker Mosquitto (reintentando automáticamente).")

    def _handle_message(self, client: Any, userdata: Any, msg: Any) -> None:
        try:
            payload = json.loads(msg.payload.decode("utf-8"))
            logger.info("Comando MQTT recibido en [%s]: %s", msg.topic, payload)
            if self.on_command and isinstance(payload, dict):
                self.on_command(payload)
        except Exception as exc:
            logger.warning("Error procesando mensaje MQTT: %s", exc)

    def publish_fsm_state(self, status: Dict[str, Any], event: Optional[str] = None) -> None:
        """Publica el estado actual de la FSM en Mosquitto."""
        if not self.connected or self._client is None:
            return
        payload = {
            "state": status.get("state"),
            "remaining_seconds": status.get("remaining_seconds"),
            "total_seconds": status.get("total_seconds"),
            "phone_detected": status.get("phone_detected"),
            "is_locked": status.get("is_locked"),
            "event": event,
        }
        try:
            with self._lock:
                self._client.publish(self.TOPIC_FSM_STATE, json.dumps(payload), qos=1, retain=True)
        except Exception as exc:
            logger.debug("Error publicando estado FSM en MQTT: %s", exc)

    def publish_hardware_telemetry(self, telemetry: Dict[str, Any]) -> None:
        """Publica la lectura del sensor IR y los ángulos de los 2 servomotores en Mosquitto."""
        if not self.connected or self._client is None:
            return
        payload = {
            "phone_detected": telemetry.get("stable_sensor"),
            "raw_sensor": telemetry.get("raw_sensor"),
            "lid_angle_deg": telemetry.get("lid_angle_deg"),
            "lock_angle_deg": telemetry.get("lock_angle_deg"),
            "led_red_on": telemetry.get("led_red_on"),
            "led_green_on": telemetry.get("led_green_on"),
        }
        try:
            with self._lock:
                self._client.publish(self.TOPIC_HARDWARE_TELEMETRY, json.dumps(payload), qos=0)
        except Exception as exc:
            logger.debug("Error publicando telemetría hardware en MQTT: %s", exc)

    def stop(self) -> None:
        if self._client is not None:
            try:
                self._client.loop_stop()
                self._client.disconnect()
            except Exception:
                pass
            self.connected = False
