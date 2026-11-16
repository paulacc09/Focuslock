# ==============================================================================
# FocusLock — Dockerfile de Producción
# ==============================================================================
FROM python:3.11-slim

# Evitar prompts interactivos y buffer de salida
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000

WORKDIR /app

# Instalar dependencias del sistema mínimas
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Instalar dependencias de Python
COPY focuslock_server/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el código del servidor y dashboard web
COPY focuslock_server /app

# Exponer el puerto del servidor
EXPOSE 8000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

# Comando de inicio
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
