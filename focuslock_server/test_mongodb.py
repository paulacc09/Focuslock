"""
FocusLock — Script de Verificación de Conexión a MongoDB Atlas
=============================================================
Prueba la conexión real contra tu clúster de MongoDB Atlas:
  1. Realiza un ping al clúster.
  2. Inserta un documento de prueba en 'telemetry_logs'.
  3. Consulta y lee el documento recién guardado.
  4. Muestra estadísticas y estado de las colecciones.
"""

from __future__ import annotations

import os
import sys
from datetime import datetime

# Cargar variables de entorno desde .env
try:
    from dotenv import load_dotenv
    # Buscar .env en la raíz del proyecto
    env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    if os.path.exists(env_path):
        load_dotenv(env_path)
    else:
        load_dotenv()
except ImportError:
    pass

try:
    import pymongo
except ImportError:
    print("\n❌ Error: La librería 'pymongo' no está instalada.")
    print("Instálala ejecutando: pip install pymongo dnspython\n")
    sys.exit(1)

MONGODB_URI = os.getenv("MONGODB_URI") or os.getenv("MONGO_URI")
DB_NAME = os.getenv("MONGODB_DB_NAME", "focuslock_db")

print("\n" + "=" * 65)
print("  🍃 FOCUSLOCK — VERIFICADOR DE CONEXIÓN A MONGO DB")
print("=" * 65)

if not MONGODB_URI:
    print("\n❌ Error: No se encontró la variable MONGODB_URI en el archivo .env.")
    print("Asegúrate de que el archivo .env contenga tu URI de conexión.")
    sys.exit(1)

# Ocultar la contraseña en la impresión para seguridad
safe_uri = MONGODB_URI
if "@" in safe_uri and ":" in safe_uri:
    parts = safe_uri.split("@")
    prefix = parts[0].split(":")[0] + ":****"
    safe_uri = prefix + "@" + parts[1]

print(f"  • URI Destino    : {safe_uri}")
print(f"  • Base de Datos  : {DB_NAME}")
print("  • Estado         : Conectando al clúster Atlas...")
print("-" * 65)

try:
    client = pymongo.MongoClient(
        MONGODB_URI,
        serverSelectionTimeoutMS=7000,
        connectTimeoutMS=7000,
    )

    # 1. Ping de verificación
    print("1️⃣  Ejecutando comando 'ping' de administración...")
    ping_result = client.admin.command("ping")
    print(f"    ✅ PING EXITOSO: {ping_result}")

    # 2. Acceso a la base de datos y colecciones
    db = client[DB_NAME]
    telemetry_col = db["telemetry_logs"]
    sessions_col = db["sessions"]

    # 3. Insertar documento de prueba
    print("\n2️⃣  Insertando documento de telemetría de prueba en 'telemetry_logs'...")
    test_doc = {
        "event_type": "VERIFICACION_SISTEMA",
        "attention_score": 0.98,
        "face_detected": True,
        "distraction_detected": False,
        "decibels": 42.5,
        "noise_violation": False,
        "test_verified": True,
        "timestamp": datetime.utcnow().isoformat(),
        "client_info": "FocusLock Test Runner",
    }
    insert_res = telemetry_col.insert_one(test_doc)
    doc_id = insert_res.inserted_id
    print(f"    ✅ DOCUMENTO GUARDADO. ID generado: {doc_id}")

    # 4. Leer documento insertado
    print("\n3️⃣  Consultando el documento desde MongoDB Atlas...")
    found_doc = telemetry_col.find_one({"_id": doc_id})
    if found_doc:
        print("    ✅ DOCUMENTO LEÍDO CORRECTAMENTE:")
        print(f"       • Tipo Evento   : {found_doc.get('event_type')}")
        print(f"       • Atención (%)  : {int(found_doc.get('attention_score', 0) * 100)}%")
        print(f"       • Decibelios    : {found_doc.get('decibels')} dB")
        print(f"       • Timestamp     : {found_doc.get('timestamp')}")
    else:
        print("    ⚠️ Advertencia: No se pudo recuperar el documento recién creado.")

    # 5. Listar colecciones y conteos
    collections = db.list_collection_names()
    print(f"\n4️⃣  Colecciones activas en '{DB_NAME}': {collections}")
    print(f"    • Total registros en 'telemetry_logs': {telemetry_col.count_documents({})}")
    print(f"    • Total registros en 'sessions': {sessions_col.count_documents({})}")

    print("\n" + "=" * 65)
    print("  🎉 ¡TODO FUNCIONA PERFECTAMENTE! MongoDB Atlas está 100% operativo.")
    print("=" * 65 + "\n")

except pymongo.errors.ServerSelectionTimeoutError as err:
    print("\n❌ ERROR DE CONEXIÓN (Timeout): No se pudo alcanzar el clúster de MongoDB Atlas.")
    print(f"Detalle: {err}")
    print("\n💡 Posible causa más común en MongoDB Atlas:")
    print("   En el panel de MongoDB Atlas (cloud.mongodb.com):")
    print("   1. Ve a 'Security' ➔ 'Network Access'.")
    print("   2. Asegúrate de que tu IP actual esté permitida, o añade '0.0.0.0/0' (Allow access from anywhere).")
    sys.exit(1)
except pymongo.errors.OperationFailure as err:
    print(f"\n❌ ERROR DE AUTENTICACIÓN / PERMISOS: {err}")
    print("Verifica que el usuario y la contraseña tengan permisos 'Read and write to any database'.")
    sys.exit(1)
except Exception as err:
    print(f"\n❌ ERROR INESPERADO: {err}")
    sys.exit(1)
