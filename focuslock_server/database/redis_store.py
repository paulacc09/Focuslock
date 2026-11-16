"""
FocusLock — Base de Datos NoSQL y Caché en Tiempo Real (Redis)
Propósito:
  1. Almacenar la telemetría viva de alta frecuencia (cámara, decibelios de ruido, atención).
  2. Actuar como bus Pub/Sub entre réplicas del servidor FastAPI detrás del balanceador de carga Nginx.
  3. Servir de buffer ultrarrápido para el dashboard web en tiempo real.
"""

from __future__ import annotations

import json
import logging
import os
import threading
import time
from typing import Any, Callable, Dict, List, Optional

logger = logging.getLogger("FocusLock.Redis")

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

_redis_client = None
_in_memory_cache: Dict[str, Any] = {}
_in_memory_noise_history: List[Dict[str, Any]] = []
_in_memory_subscribers: List[Callable[[Dict[str, Any]], None]] = []
_lock = threading.Lock()
_using_real_redis = False


def init_redis():
    """Inicializa la conexión a Redis o activa el motor en memoria si no está disponible."""
    global _redis_client, _using_real_redis

    try:
        import redis

        client = redis.from_url(REDIS_URL, decode_responses=True, socket_connect_timeout=2)
        client.ping()
        _redis_client = client
        _using_real_redis = True
        logger.info("Conectado exitosamente a Redis en: %s", REDIS_URL)
        return _redis_client
    except Exception as exc:
        _using_real_redis = False
        _redis_client = None
        logger.info("Redis no disponible en %s (%s). Usando motor NoSQL/Caché en memoria.", REDIS_URL, exc)
        return None


def set_live_telemetry(telemetry_data: Dict[str, Any], ttl_seconds: int = 60) -> bool:
    """Guarda la telemetría viva más reciente en Redis con expiración."""
    global _redis_client, _using_real_redis

    payload = json.dumps(telemetry_data)
    if _using_real_redis and _redis_client:
        try:
            _redis_client.set("focuslock:live_telemetry", payload, ex=ttl_seconds)
            return True
        except Exception as e:
            logger.debug("Error escribiendo en Redis: %s", e)

    with _lock:
        _in_memory_cache["focuslock:live_telemetry"] = telemetry_data
        _in_memory_cache["focuslock:live_telemetry_ts"] = time.time()
    return True


def get_live_telemetry() -> Dict[str, Any]:
    """Obtiene la última telemetría almacenada."""
    global _redis_client, _using_real_redis

    if _using_real_redis and _redis_client:
        try:
            val = _redis_client.get("focuslock:live_telemetry")
            if val:
                return json.loads(val)
        except Exception as e:
            logger.debug("Error leyendo de Redis: %s", e)

    with _lock:
        return _in_memory_cache.get("focuslock:live_telemetry", {})


def push_noise_sample(sample: Dict[str, Any], max_items: int = 60) -> None:
    """Inserta una muestra acústica en el búfer circular de Redis."""
    global _redis_client, _using_real_redis

    payload = json.dumps(sample)
    if _using_real_redis and _redis_client:
        try:
            pipe = _redis_client.pipeline()
            pipe.lpush("focuslock:noise:history", payload)
            pipe.ltrim("focuslock:noise:history", 0, max_items - 1)
            pipe.execute()
            return
        except Exception as e:
            logger.debug("Error en push_noise_sample de Redis: %s", e)

    with _lock:
        _in_memory_noise_history.insert(0, sample)
        if len(_in_memory_noise_history) > max_items:
            _in_memory_noise_history.pop()


def get_recent_noise_samples(limit: int = 30) -> List[Dict[str, Any]]:
    """Devuelve las muestras acústicas más recientes."""
    global _redis_client, _using_real_redis

    if _using_real_redis and _redis_client:
        try:
            items = _redis_client.lrange("focuslock:noise:history", 0, limit - 1)
            return [json.loads(i) for i in items]
        except Exception as e:
            logger.debug("Error en get_recent_noise_samples de Redis: %s", e)

    with _lock:
        return list(_in_memory_noise_history[:limit])


def publish_telemetry_event(event_dict: Dict[str, Any], channel: str = "focuslock:events") -> None:
    """Publica un evento en el canal Pub/Sub para que todas las réplicas del balanceador lo reciban."""
    global _redis_client, _using_real_redis

    payload = json.dumps(event_dict)
    if _using_real_redis and _redis_client:
        try:
            _redis_client.publish(channel, payload)
        except Exception as e:
            logger.debug("Error publicando en canal Redis %s: %s", channel, e)

    with _lock:
        for sub in list(_in_memory_subscribers):
            try:
                sub(event_dict)
            except Exception:
                pass


def subscribe_telemetry_events(callback: Callable[[Dict[str, Any]], None], channel: str = "focuslock:events") -> None:
    """Registra un callback para recibir eventos del bus compartido."""
    global _redis_client, _using_real_redis

    with _lock:
        _in_memory_subscribers.append(callback)

    if _using_real_redis and _redis_client:
        def _listen():
            try:
                pubsub = _redis_client.pubsub()
                pubsub.subscribe(channel)
                for message in pubsub.listen():
                    if message["type"] == "message":
                        data = json.loads(message["data"])
                        callback(data)
            except Exception as e:
                logger.warning("Conexión pubsub de Redis cerrada: %s", e)

        t = threading.Thread(target=_listen, daemon=True, name="RedisPubSubThread")
        t.start()
