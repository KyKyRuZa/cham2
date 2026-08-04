# Stage 1: Builder
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev git ca-certificates \
    libglib2.0-0 libsm6 libxext6 libxrender1 libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

# uv — dramatically faster pip replacement
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app
COPY requirements.ai.txt .
COPY vendor/sam2 /app/vendor/sam2
COPY vendor/diffusers /app/vendor/diffusers

# BuildKit cache mount persists downloads between builds.
# --no-cache keeps the image layer small; cache lives in BuildKit storage.
RUN --mount=type=cache,target=/root/.cache/uv \
    uv venv /opt/venv && \
    uv pip install --python /opt/venv/bin/python --no-cache -r requirements.ai.txt

# Stage 2: Runtime
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m appuser
WORKDIR /app

# Copy only the installed virtualenv from builder
COPY --from=builder /opt/venv /opt/venv

COPY server/ ./server/

RUN chown -R appuser:appuser /app
USER appuser
ENV PATH=/opt/venv/bin:$PATH
EXPOSE 8001
CMD ["python3", "-m", "server.app"]
