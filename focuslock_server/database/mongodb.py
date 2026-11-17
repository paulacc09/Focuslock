"""
FocusLock — Base de Datos NoSQL Documental (MongoDB)
Propósito:
  Almacenar documentos de telemetría de alta resolución (snapshots,
  auditoría de decibelios, eventos de atención) y documentos históricos de sesiones.
Diseño: Totalmente no intrusivo; si MONGODB_URI no está definido o la base de datos
no responde, el sistema continúa funcionando con normalidad sin interrumpir ningún servicio.
"""

from __future__ import annotations

import logging
import os
from datetime import datetime
from typing import Any, Dict, List, Optional

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

logger = logging.getLogger("FocusLock.MongoDB")

MONGODB_URI = os.getenv("MONGODB_URI") or os.getenv("MONGO_URI", "")
DB_NAME = os.getenv("MONGODB_DB_NAME", "focuslock_db")

_mongo_client = None
_mongo_db = None
_is_connected = False


def init_mongodb():
    """Inicializa la conexión a MongoDB de forma segura y no bloqueante."""
    global _mongo_client, _mongo_db, _is_connected

    if not MONGODB_URI:
        logger.info("MONGODB_URI no configurado. Modo MongoDB en espera (sin afectar operaciones).")
        _is_connected = False
        return None

    try:
        import pymongo

        client = pymongo.MongoClient(
            MONGODB_URI,
            serverSelectionTimeoutMS=4000,
            connectTimeoutMS=4000,
        )
        # Verificar conexión con ping
        client.admin.command("ping")
        _mongo_client = client
        _mongo_db = client[DB_NAME]
        _is_connected = True
        logger.info("✅ Conexión exitosa a MongoDB en base de datos: '%s'", DB_NAME)

        # Crear índices para consultas eficientes
        try:
            _mongo_db["telemetry_logs"].create_index([("timestamp", pymongo.DESCENDING)])
            _mongo_db["sessions"].create_index([("session_id", pymongo.ASCENDING)])
        except Exception:
            pass

        return _mongo_db
    except Exception as exc:
        logger.warning("No se pudo conectar a MongoDB (%s). Continuando sin alterar el sistema.", exc)
        _is_connected = False
        _mongo_client = None
        _mongo_db = None
        return None


def is_mongodb_active() -> bool:
    """Indica si MongoDB está actualmente conectado."""
    return _is_connected and _mongo_db is not None


def save_mongo_telemetry(telemetry_data: Dict[str, Any]) -> bool:
    """Guarda un documento de telemetría en la colección 'telemetry_logs' de MongoDB."""
    if not is_mongodb_active():
        return False

    try:
        doc = dict(telemetry_data)
        doc["received_at"] = datetime.utcnow()
        _mongo_db["telemetry_logs"].insert_one(doc)
        return True
    except Exception as exc:
        logger.debug("Error guardando telemetría en MongoDB: %s", exc)
        return False


def save_mongo_session(session_data: Dict[str, Any]) -> bool:
    """Guarda o actualiza un documento de sesión en MongoDB."""
    if not is_mongodb_active():
        return False

    try:
        s_id = session_data.get("id") or session_data.get("session_id")
        if not s_id:
            return False

        doc = dict(session_data)
        doc["updated_at"] = datetime.utcnow()
        _mongo_db["sessions"].update_one(
            {"session_id": s_id},
            {"$set": doc, "$setOnInsert": {"created_at": datetime.utcnow()}},
            upsert=True,
        )
        return True
    except Exception as exc:
        logger.debug("Error guardando sesión en MongoDB: %s", exc)
        return False


def get_mongo_recent_telemetry(limit: int = 20) -> List[Dict[str, Any]]:
    """Obtiene los últimos documentos de telemetría desde MongoDB."""
    if not is_mongodb_active():
        return []

    try:
        cursor = _mongo_db["telemetry_logs"].find({}, {"_id": 0}).sort("received_at", -1).limit(limit)
        return list(cursor)
    except Exception as exc:
        logger.debug("Error consultando MongoDB: %s", exc)
        return []
