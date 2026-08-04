# Stage 1: Builder
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04 AS builder
RUN apt-get update && apt-get install -y \
    python3-pip python3-dev git ca-certificates \
    libglib2.0-0 libsm6 libxext6 libxrender1 libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.ai.txt .
RUN pip3 install --user -r requirements.ai.txt --no-cache-dir

# Stage 2: Runtime
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04
RUN apt-get update && apt-get install -y \
    python3 libglib2.0-0 libsm6 libxext6 libxrender1 libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*
RUN useradd -m appuser
WORKDIR /app
COPY --from=builder /root/.local /home/appuser/.local
COPY --from=builder /app/requirements.ai.txt .
COPY app.py .
COPY server/ ./server/
RUN chown -R appuser:appuser /app
USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH
EXPOSE 8001
CMD ["python3", "app.py"]
