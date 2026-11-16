"""
FocusLock — Base de Datos Relacional (PostgreSQL con Fallback SQLite)
Propósito: Persistencia transaccional de sesiones de estudio Pomodoro,
métricas de concentración, auditoría de ruido y eventos de hardware.
"""

from __future__ import annotations

import json
import logging
import os
import sqlite3
import threading
from datetime import datetime
from typing import Any, Dict, List, Optional

logger = logging.getLogger("FocusLock.PostgreSQL")

DATABASE_URL = os.getenv("DATABASE_URL", "")

# Flags y conexiones
_using_postgres = False
_sqlite_conn: Optional[sqlite3.Connection] = None
_sqlite_lock = threading.Lock()


def get_connection():
    """Obtiene una conexión compatible según DATABASE_URL."""
    global _using_postgres, _sqlite_conn

    if DATABASE_URL.startswith("postgresql://") or DATABASE_URL.startswith("postgres://"):
        try:
            import psycopg2
            from psycopg2.extras import RealDictCursor

            conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
            _using_postgres = True
            return conn
        except Exception as exc:
            logger.warning("No se pudo conectar a PostgreSQL (%s). Activando fallback SQLite local.", exc)

    _using_postgres = False
    with _sqlite_lock:
        if _sqlite_conn is None:
            db_path = os.path.join(os.path.dirname(__file__), "focuslock_local.db")
            _sqlite_conn = sqlite3.connect(db_path, check_same_thread=False)
            _sqlite_conn.row_factory = sqlite3.Row
        return _sqlite_conn


def init_postgres() -> None:
    """Aplica migraciones DDL automáticas para crear las tablas relacionales."""
    logger.info("Ejecutando migraciones de Base de Datos Relacional...")

    try:
        if DATABASE_URL.startswith("postgresql://") or DATABASE_URL.startswith("postgres://"):
            try:
                import psycopg2

                conn = psycopg2.connect(DATABASE_URL)
                with conn.cursor() as cur:
                    # 1. Tabla de sesiones Pomodoro
                    cur.execute(
                        """
                        CREATE TABLE IF NOT EXISTS focus_sessions (
                            id VARCHAR(64) PRIMARY KEY,
                            session_name VARCHAR(128) NOT NULL,
                            mode VARCHAR(32) NOT NULL DEFAULT 'standard',
                            target_minutes INT NOT NULL DEFAULT 25,
                            remaining_seconds INT NOT NULL DEFAULT 1500,
                            status VARCHAR(32) NOT NULL DEFAULT 'IDLE',
                            distractions_count INT NOT NULL DEFAULT 0,
                            noise_violations_count INT NOT NULL DEFAULT 0,
                            started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
                            ended_at TIMESTAMP WITH TIME ZONE
                        );
                        """
                    )
                    # 2. Tabla de eventos de concentración y hardware
                    cur.execute(
                        """
                        CREATE TABLE IF NOT EXISTS focus_events (
                            id SERIAL PRIMARY KEY,
                            session_id VARCHAR(64),
                            event_type VARCHAR(64) NOT NULL,
                            event_data JSONB,
                            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                        );
                        """
                    )
                    # 3. Tabla de auditoría acústica / decibelios
                    cur.execute(
                        """
                        CREATE TABLE IF NOT EXISTS noise_audit_logs (
                            id SERIAL PRIMARY KEY,
                            session_id VARCHAR(64),
                            decibels NUMERIC(5, 2) NOT NULL,
                            is_violation BOOLEAN NOT NULL DEFAULT FALSE,
                            ambient_status VARCHAR(32) NOT NULL,
                            created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                        );
                        """
                    )
                conn.commit()
                conn.close()
                logger.info("Migraciones en PostgreSQL aplicadas exitosamente.")
                seed_postgres()
                return
            except Exception as e:
                logger.warning("Error aplicando DDL en PostgreSQL (%s). Fallback a SQLite...", e)

        # Fallback local DDL SQLite
        with _sqlite_lock:
            conn = get_connection()
            cur = conn.cursor()
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS focus_sessions (
                    id TEXT PRIMARY KEY,
                    session_name TEXT NOT NULL,
                    mode TEXT NOT NULL DEFAULT 'standard',
                    target_minutes INTEGER NOT NULL DEFAULT 25,
                    remaining_seconds INTEGER NOT NULL DEFAULT 1500,
                    status TEXT NOT NULL DEFAULT 'IDLE',
                    distractions_count INTEGER NOT NULL DEFAULT 0,
                    noise_violations_count INTEGER NOT NULL DEFAULT 0,
                    started_at TEXT DEFAULT CURRENT_TIMESTAMP,
                    ended_at TEXT
                );
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS focus_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT,
                    event_type TEXT NOT NULL,
                    event_data TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                );
                """
            )
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS noise_audit_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT,
                    decibels REAL NOT NULL,
                    is_violation INTEGER NOT NULL DEFAULT 0,
                    ambient_status TEXT NOT NULL,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                );
                """
            )
            conn.commit()
            logger.info("Migraciones en SQLite local aplicadas exitosamente.")
            seed_postgres()
    except Exception as exc:
        logger.error("Error al inicializar la base de datos relacional: %s", exc)


def seed_postgres() -> None:
    """Siembra datos iniciales (seeds) si las tablas están vacías."""
    try:
        conn = get_connection()
        if _using_postgres:
            with conn.cursor() as cur:
                cur.execute("SELECT COUNT(*) AS total FROM focus_sessions;")
                res = cur.fetchone()
                total = res["total"] if isinstance(res, dict) else res[0]
                if total == 0:
                    cur.execute(
                        """
                        INSERT INTO focus_sessions (id, session_name, mode, target_minutes, remaining_seconds, status, distractions_count, noise_violations_count, ended_at)
                        VALUES 
                        ('seed-sesion-inicial', 'Sesión de Demostración Inicial', 'demo', 25, 0, 'COMPLETED', 0, 0, CURRENT_TIMESTAMP),
                        ('seed-sesion-matutina', 'Bloque de Estudio Profundo', 'standard', 45, 0, 'COMPLETED', 1, 0, CURRENT_TIMESTAMP);
                        """
                    )
                    conn.commit()
                    logger.info("Seeds iniciales insertados en PostgreSQL.")
            conn.close()
        else:
            with _sqlite_lock:
                cur = conn.cursor()
                cur.execute("SELECT COUNT(*) AS total FROM focus_sessions;")
                row = cur.fetchone()
                total = row["total"] if isinstance(row, sqlite3.Row) else row[0]
                if total == 0:
                    cur.execute(
                        """
                        INSERT INTO focus_sessions (id, session_name, mode, target_minutes, remaining_seconds, status, distractions_count, noise_violations_count, ended_at)
                        VALUES 
                        ('seed-sesion-inicial', 'Sesión de Demostración Inicial', 'demo', 25, 0, 'COMPLETED', 0, 0, CURRENT_TIMESTAMP),
                        ('seed-sesion-matutina', 'Bloque de Estudio Profundo', 'standard', 45, 0, 'COMPLETED', 1, 0, CURRENT_TIMESTAMP);
                        """
                    )
                    conn.commit()
                    logger.info("Seeds iniciales insertados en SQLite.")
    except Exception as exc:
        logger.warning("No se pudieron insertar los seeds relacionales: %s", exc)


def save_session(session_data: Dict[str, Any]) -> bool:
    """Crea o actualiza una sesión de estudio en la base de datos."""
    s_id = session_data.get("id") or f"sess_{int(datetime.utcnow().timestamp())}"
    s_name = session_data.get("session_name", "Sesión FocusLock")
    mode = session_data.get("mode", "standard")
    target_m = int(session_data.get("target_minutes", 25))
    rem_s = int(session_data.get("remaining_seconds", target_m * 60))
    status = session_data.get("status", "IDLE")
    distractions = int(session_data.get("distractions_count", 0))
    noise_viol = int(session_data.get("noise_violations_count", 0))

    try:
        conn = get_connection()
        if _using_postgres:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO focus_sessions (id, session_name, mode, target_minutes, remaining_seconds, status, distractions_count, noise_violations_count)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (id) DO UPDATE SET
                        remaining_seconds = EXCLUDED.remaining_seconds,
                        status = EXCLUDED.status,
                        distractions_count = EXCLUDED.distractions_count,
                        noise_violations_count = EXCLUDED.noise_violations_count;
                    """,
                    (s_id, s_name, mode, target_m, rem_s, status, distractions, noise_viol),
                )
            conn.commit()
            conn.close()
        else:
            with _sqlite_lock:
                cur = conn.cursor()
                cur.execute(
                    """
                    INSERT INTO focus_sessions (id, session_name, mode, target_minutes, remaining_seconds, status, distractions_count, noise_violations_count)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        remaining_seconds = excluded.remaining_seconds,
                        status = excluded.status,
                        distractions_count = excluded.distractions_count,
                        noise_violations_count = excluded.noise_violations_count;
                    """,
                    (s_id, s_name, mode, target_m, rem_s, status, distractions, noise_viol),
                )
                conn.commit()
        return True
    except Exception as exc:
        logger.error("Error guardando sesión en BD: %s", exc)
        return False


def update_session_status(session_id: str, status: str, remaining_seconds: Optional[int] = None) -> bool:
    """Actualiza el estado de la sesión."""
    try:
        conn = get_connection()
        if _using_postgres:
            with conn.cursor() as cur:
                if remaining_seconds is not None:
                    cur.execute(
                        "UPDATE focus_sessions SET status = %s, remaining_seconds = %s WHERE id = %s",
                        (status, remaining_seconds, session_id),
                    )
                else:
                    cur.execute(
                        "UPDATE focus_sessions SET status = %s WHERE id = %s",
                        (status, session_id),
                    )
            conn.commit()
            conn.close()
        else:
            with _sqlite_lock:
                cur = conn.cursor()
                if remaining_seconds is not None:
                    cur.execute(
                        "UPDATE focus_sessions SET status = ?, remaining_seconds = ? WHERE id = ?",
                        (status, remaining_seconds, session_id),
                    )
                else:
                    cur.execute(
                        "UPDATE focus_sessions SET status = ? WHERE id = ?",
                        (status, session_id),
                    )
                conn.commit()
        return True
    except Exception as exc:
        logger.error("Error actualizando sesión %s: %s", session_id, exc)
        return False


def log_focus_event(session_id: Optional[str], event_type: str, data: Dict[str, Any]) -> None:
    """Registra un evento de atención o transición de estado."""
    try:
        conn = get_connection()
        data_str = json.dumps(data)
        if _using_postgres:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO focus_events (session_id, event_type, event_data) VALUES (%s, %s, %s)",
                    (session_id, event_type, data_str),
                )
            conn.commit()
            conn.close()
        else:
            with _sqlite_lock:
                cur = conn.cursor()
                cur.execute(
                    "INSERT INTO focus_events (session_id, event_type, event_data) VALUES (?, ?, ?)",
                    (session_id, event_type, data_str),
                )
                conn.commit()
    except Exception as exc:
        logger.debug("Error registrando evento de enfoque: %s", exc)


def log_noise_audit(session_id: Optional[str], decibels: float, is_violation: bool, status: str) -> None:
    """Guarda un registro acústico de ruido capturado."""
    try:
        conn = get_connection()
        if _using_postgres:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO noise_audit_logs (session_id, decibels, is_violation, ambient_status)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (session_id, decibels, is_violation, status),
                )
            conn.commit()
            conn.close()
        else:
            with _sqlite_lock:
                cur = conn.cursor()
                cur.execute(
                    """
                    INSERT INTO noise_audit_logs (session_id, decibels, is_violation, ambient_status)
                    VALUES (?, ?, ?, ?)
                    """,
                    (session_id, decibels, 1 if is_violation else 0, status),
                )
                conn.commit()
    except Exception as exc:
        logger.debug("Error registrando auditoría de ruido: %s", exc)


def get_recent_sessions(limit: int = 10) -> List[Dict[str, Any]]:
    """Devuelve las sesiones más recientes."""
    try:
        conn = get_connection()
        if _using_postgres:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM focus_sessions ORDER BY started_at DESC LIMIT %s", (limit,))
                rows = cur.fetchall()
            conn.close()
            return [dict(r) for r in rows]
        else:
            with _sqlite_lock:
                cur = conn.cursor()
                cur.execute("SELECT * FROM focus_sessions ORDER BY started_at DESC LIMIT ?", (limit,))
                rows = cur.fetchall()
                return [dict(r) for r in rows]
    except Exception as exc:
        logger.error("Error obteniendo sesiones recientes: %s", exc)
        return []


def get_session_by_id(session_id: str) -> Optional[Dict[str, Any]]:
    """Consulta una sesión por su ID."""
    try:
        conn = get_connection()
        if _using_postgres:
            with conn.cursor() as cur:
                cur.execute("SELECT * FROM focus_sessions WHERE id = %s", (session_id,))
                row = cur.fetchone()
            conn.close()
            return dict(row) if row else None
        else:
            with _sqlite_lock:
                cur = conn.cursor()
                cur.execute("SELECT * FROM focus_sessions WHERE id = ?", (session_id,))
                row = cur.fetchone()
                return dict(row) if row else None
    except Exception as exc:
        logger.error("Error consultando sesión %s: %s", session_id, exc)
        return None
