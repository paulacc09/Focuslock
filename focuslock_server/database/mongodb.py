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
            _mongo_db["telemetry_logs"].create_index([("received_at", pymongo.DESCENDING)])
            _mongo_db["telemetry_logs"].create_index([("session_id", pymongo.ASCENDING)])
            _mongo_db["telemetry_logs"].create_index([("user_id", pymongo.ASCENDING)])
            _mongo_db["sessions"].create_index([("session_id", pymongo.ASCENDING)])
            _mongo_db["sessions"].create_index([("user_id", pymongo.ASCENDING)])
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


def _serialize_doc(doc: Dict[str, Any]) -> Dict[str, Any]:
    """Convierte tipos BSON/datetime a formatos JSON serializables."""
    out: Dict[str, Any] = {}
    for k, v in doc.items():
        if k == "_id":
            continue
        if isinstance(v, datetime):
            out[k] = v.isoformat()
        else:
            out[k] = v
    return out


def get_mongo_recent_telemetry(limit: int = 20) -> List[Dict[str, Any]]:
    """Obtiene los últimos documentos de telemetría desde MongoDB."""
    if not is_mongodb_active():
        return []

    try:
        cursor = _mongo_db["telemetry_logs"].find({}, {"_id": 0}).sort("received_at", -1).limit(limit)
        return [_serialize_doc(doc) for doc in cursor]
    except Exception as exc:
        logger.debug("Error consultando MongoDB: %s", exc)
        return []


def get_mongo_sessions(limit: int = 10, user_id: Optional[str] = None) -> List[Dict[str, Any]]:
    """Obtiene los documentos de sesión más recientes desde MongoDB."""
    if not is_mongodb_active():
        return []

    try:
        query: Dict[str, Any] = {}
        if user_id:
            query["user_id"] = user_id
        cursor = _mongo_db["sessions"].find(query, {"_id": 0}).sort("updated_at", -1).limit(limit)
        return [_serialize_doc(doc) for doc in cursor]
    except Exception as exc:
        logger.debug("Error consultando sesiones en MongoDB: %s", exc)
        return []


def get_mongo_summary(session_id: Optional[str] = None, user_id: Optional[str] = None) -> Dict[str, Any]:
    """Calcula métricas agregadas de atención y ruido acústico en MongoDB Atlas."""
    empty_summary: Dict[str, Any] = {
        "connected": is_mongodb_active(),
        "database": DB_NAME,
        "total_telemetry_docs": 0,
        "total_sessions": 0,
        "avg_attention": None,
        "avg_decibels": None,
        "max_decibels": None,
        "noise_violations": 0,
        "distraction_events": 0,
        "last_received_at": None,
        "recent_samples": [],
    }
    if not is_mongodb_active():
        return empty_summary

    try:
        match_filter: Dict[str, Any] = {}
        if session_id:
            match_filter["session_id"] = session_id
        if user_id:
            match_filter["user_id"] = user_id

        pipeline: List[Dict[str, Any]] = []
        if match_filter:
            pipeline.append({"$match": match_filter})

        pipeline.append({
            "$group": {
                "_id": None,
                "total_telemetry_docs": {"$sum": 1},
                "avg_attention": {"$avg": "$attention_score"},
                "avg_decibels": {"$avg": "$decibels"},
                "max_decibels": {"$max": "$decibels"},
                "noise_violations": {
                    "$sum": {"$cond": [{"$eq": ["$noise_violation", True]}, 1, 0]}
                },
                "distraction_events": {
                    "$sum": {
                        "$cond": [
                            {
                                "$or": [
                                    {"$eq": ["$distracted", True]},
                                    {"$lt": ["$attention_score", 60]},
                                ]
                            },
                            1,
                            0,
                        ]
                    }
                },
                "last_received_at": {"$max": "$received_at"},
            }
        })

        agg_result = list(_mongo_db["telemetry_logs"].aggregate(pipeline))
        stats = agg_result[0] if agg_result else {}

        session_filter: Dict[str, Any] = {}
        if session_id:
            session_filter["session_id"] = session_id
        if user_id:
            session_filter["user_id"] = user_id
        total_sessions = _mongo_db["sessions"].count_documents(session_filter)

        recent_cursor = (
            _mongo_db["telemetry_logs"]
            .find(match_filter, {"_id": 0})
            .sort("received_at", -1)
            .limit(10)
        )
        recent_samples = [_serialize_doc(doc) for doc in recent_cursor]

        avg_att = stats.get("avg_attention")
        avg_db = stats.get("avg_decibels")
        max_db = stats.get("max_decibels")
        last_rx = stats.get("last_received_at")

        return {
            "connected": True,
            "database": DB_NAME,
            "total_telemetry_docs": int(stats.get("total_telemetry_docs", 0)),
            "total_sessions": int(total_sessions),
            "avg_attention": round(float(avg_att), 1) if avg_att is not None else None,
            "avg_decibels": round(float(avg_db), 1) if avg_db is not None else None,
            "max_decibels": round(float(max_db), 1) if max_db is not None else None,
            "noise_violations": int(stats.get("noise_violations", 0)),
            "distraction_events": int(stats.get("distraction_events", 0)),
            "last_received_at": last_rx.isoformat() if isinstance(last_rx, datetime) else last_rx,
            "recent_samples": recent_samples,
        }
    except Exception as exc:
        logger.warning("Error calculando resumen de MongoDB: %s", exc)
        return empty_summary
