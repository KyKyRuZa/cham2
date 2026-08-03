# Полный план исправлений проекта cham2

## Разбивка по компонентам

---

## CLIENT

---

### C.1 Безопасность: production IP в .env и истории git

**Файл:** `client/.env`, строка 6

**Проблема:** В репозитории закоммичен production IP-адрес `87.228.10.101`. Это разглашение инфраструктуры и упрощение целевой атаки. IP уже виден в истории git.

**Исправление:**

1. Удалить IP из `.env`, заменить на `http://localhost` или плейсхолдер
2. Обновить `.env.example` аналогично
3. Очистить историю git: `git filter-repo --path client/.env --invert-paths`
4. Добавить `.env` в `.gitignore` (уже есть на уровне корня)

**Строки для изменения:**

- `client/.env:6` — заменить `SERVER_URL=http://87.228.10.101` на `SERVER_URL=http://localhost`
- `client/.env.example:6` — заменить `SERVER_URL=http://87.228.10.101` на `SERVER_URL=https://your-domain.com`

---

### C.2 Стабильность: отсутствие `INTERNET` permission в AndroidManifest

**Файл:** `client/android/app/src/main/AndroidManifest.xml`

**Проблема:** Нет `android.permission.INTERNET` — Android блокирует все сетевые запросы. Нет `android:usesCleartextTraffic="true"` — Android 9+ блокирует HTTP по умолчанию.

**Исправление:** Добавить в `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

И в `<application>`:

```xml
android:usesCleartextTraffic="true"
```

---

### C.3 Производительность: клиент отправляет изображения до 1920px

**Файл:** `client/lib/utils/image_processing_service.dart` (предположительно), `client/lib/services/segmentation_service.dart`

**Проблема:** Клиент отправляет изображения до 1920px, а сервер ресайзит до 1024×1024. Половина загружаемых байт бесполезна, увеличивает время загрузки и трафик.

**Исправление:** Добавить клиентскую компрессию перед отправкой. В `segmentation_service.dart` при создании `MultipartFile` использовать сжатие:

```dart
request.files.add(
  http.MultipartFile.fromBytes(
    'image',
    imageBytes,
    filename: 'image.jpg',
    contentType: MediaType('image', 'jpeg'),
  ),
);
```

Лучше — предварительно сжать изображение на клиенте до 1024px и quality 75–80%.

---

### C.4 Клиент: таймаут запроса фиксированный 60 секунд

**Файл:** `client/lib/services/segmentation_service.dart`, строка 121

**Проблема:** Таймаут 60 секунд фиксированный. Для complex mode (30 шагов) на слабом сервере этого может быть недостаточно.

**Исправление:** Сделать таймаут конфигурируемым:

```dart
final timeoutSeconds = int.fromEnvironment('REQUEST_TIMEOUT', defaultValue: 90);
final streamedResponse = await request.send().timeout(
  Duration(seconds: timeoutSeconds),
);
```

---

### C.5 Клиент: устаревшая версия `http`

**Файл:** `client/pubspec.yaml`, строка 51

**Проблема:** `http: ^0.13.6` — устаревшая версия. В `http 1.x` лучший API и типизация.

**Исправление:**

```diff
-   http: ^0.13.6
+   http: ^1.2.0
```

---

### C.6 Рефакторинг `AppState` (God Object)

**Файл:** `client/lib/models/app_state.dart`

**Проблема:** `AppState` — God Object (453 строки): проекты, маска, палитра, текстуры, язык, режим превью, локализация.

**Исправление:** Разбить на отдельные `ChangeNotifier`:

- `SelectionState` — маска, точка, инструмент
- `ProjectState` — проекты, загрузка/сохранение
- `SettingsState` — язык, тема, режим превью
- `RecolorState` — результат перекраски, загрузка

---

### C.7 Удаление dead code из `image_processing_service.dart`

**Файл:** `client/lib/utils/image_processing_service.dart`

**Проблема:** 1428 строк. Большинство методов (`recolorDarkPixelsWithScreen`, `recolorAllWithScreen`, `recolorAllWithOverlay`, `recolorBrightWithOverlayFromGrayscale`, `applyGrabCutSegmentation`, `createPolygonMask`, `createBrushMask`, `createLassoMask`, `expandSelectionWithTolerance`, `computeExteriorMask`, `filterMaskByColorTolerance`) не используются в текущем UI.

**Исправление:** Удалить неиспользуемые методы. Оставить только `recolorImage` (если используется).

---

### C.8 Удаление неиспользуемых методов в `segmentation_service.dart`

**Файл:** `client/lib/services/segmentation_service.dart`, строки 137–174

**Проблема:** `_rleDecode` и `_maskToUint8List` не используются нигде в коде.

**Исправление:** Удалить строки 137–174.

---

### C.9 Дебаг-принты в релизной сборке

**Файл:** `client/lib/screens/editor_screen.dart`, строки 423–424

**Проблема:** `debugPrint('AI recolor: position=...')` и другие `debugPrint` в продакшене. В debug-сборках наносят ущерб производительности.

**Исправление:** Заменить на условный `kDebugMode` или удалить:

```dart
if (kDebugMode) {
  debugPrint('AI recolor: position=$position, imageSize=$imageSize');
}
```

---

### C.10 `withValues` deprecated в Flutter

**Файл:** `client/lib/main.dart`, строка 86

**Проблема:** `Color(0xFFF5C518).withValues(alpha: 0.3)` — в новых версиях Flutter `withValues` deprecated в пользу `withAlpha`.

**Исправление:**

```diff
-        shadowColor: const Color(0xFFF5C518).withValues(alpha: 0.3),
+        shadowColor: const Color(0xFFF5C518).withAlpha((0.3 * 255).round()),
```

---

### C.11 `_colorCategories` пересоздаётся на каждый `build()`

**Файл:** `client/lib/screens/color_palette_screen.dart`, строка 30

**Проблема:** `_colorCategories = [...]` создаётся заново на каждый `build()`. Лишние аллокации.

**Исправление:** Вынести в `static const` или инициализировать один раз в `initState`:

```dart
static const _colorCategories = [
  // ... same content
];
```

---

### C.12 `_decodedImageRgba` хранится постоянно в памяти

**Файл:** `client/lib/widgets/selection_canvas.dart`, строки 64–66

**Проблема:** `_decodedImageRgba` (сырой RGBA-буфер на 4MB для 1024×1024) хранится в состоянии постоянно, даже когда не используется.

**Исправление:** Освобождать после использования или хранить только `Uint8List` для eyedropper.

---

### C.13 Логирование: `print`/`debugPrint` вместо `logging`

**Файл:** `client/lib/` (множественные файлы)

**Проблема:** В клиенте используются `debugPrint()` без проверки `kDebugMode`.

**Исправление:** В клиенте заменить все `debugPrint()` на условные:

```dart
if (kDebugMode) {
  debugPrint('...');
}
```

---

### C.14 Клиент: unit/widget-тесты

**Файл:** `client/test/`

**Проблема:** Нет тестов на клиенте. Для коммерческого продукта это рискованно.

**Исправление:**

- Клиент: widget-тесты (`test_recolor_flow.dart`)

---

## SERVER

---

### S.1 Безопасность: `DISABLE_SAFETY_CHECKER=True`

**Файл:** `docker-compose.yml`, строка 32

> **Примечание:** хотя правка физически находится в `docker-compose.yml`, эта переменная управляет сервером безопасности HuggingFace и затрагивает сервер-компонент.

**Проблема:** Переменная `DISABLE_SAFETY_CHECKER=True` отключает встроенную проверку безопасности HuggingFace. Позволяет генерировать нежелательный контент.

**Исправление:** Изменить на `False` или удалить строку.

```diff
-      - DISABLE_SAFETY_CHECKER=True
+      - DISABLE_SAFETY_CHECKER=False
```

---

### S.2 Безопасность: hardcoded CUDA device

**Файл:** `server/app.py`, строка 117

**Проблема:** `_pipe.to("cuda")` — устройство для FLUX.2 захардкожено в `"cuda"`, хотя переменная `_device` определяется динамически (`cuda` или `cpu`). На машине без GPU пайплайн упадет при старте.

**Исправление:**

```diff
-        _pipe.to("cuda")
+        _pipe.to(_device)
```

Также добавить `enable_sequential_cpu_offload()` и `enable_attention_slicing()` для стабильной работы на GPU с ограниченной VRAM:

```diff
         _pipe = Flux2KleinInpaintPipeline.from_pretrained(
             "black-forest-labs/FLUX.2-klein-4B",
             torch_dtype=torch.bfloat16
         )
-        _pipe.to("cuda")
+        _pipe.to(_device)
+        _pipe.enable_sequential_cpu_offload()
+        _pipe.enable_attention_slicing()
+        _pipe.enable_vae_slicing()
```

---

### S.3 Безопасность: валидация `color_hex` без обработки ошибок

**Файл:** `server/app.py`, строки 489–492

**Проблема:** `int(color_hex, 16)` без обработки `ValueError`. При невалидном hex (например, `0xZZZZ`) возвращается необработанный 500 вместо 400.

**Исправление:**

```diff
     if color_hex.startswith("0x") or color_hex.startswith("0X"):
         color_hex_int = int(color_hex, 16)
     else:
-        color_hex_int = int(color_hex)
+        try:
+            color_hex_int = int(color_hex)
+        except ValueError:
+            raise HTTPException(400, f"Invalid color_hex format: '{color_hex}'")
```

---

### S.4 Безопасность: нет валидации диапазона color_hex

**Файл:** `server/app.py`, строки 489–492

**Проблема:** `int(color_hex, 16)` принимает значения больше `0xFFFFFF` (например, `0xFFFFFFFF`), что выходит за пределы RGB.

**Исправление:** Добавить проверку после парсинга:

```dart
// После строки 492 (после int(color_hex, 16)):
if not (0 <= color_hex_int <= 0xFFFFFF):
    raise HTTPException(400, f"color_hex out of RGB range: '{color_hex}'")
```

---

### S.5 Безопасность: утечка traceback в HTTPException

**Файл:** `server/app.py`, строка 825

**Проблема:** `raise HTTPException(500, str(e))` возвращает внутреннюю ошибку (traceback, пути файлов, внутренние структуры) клиенту.

**Исправление:**

```diff
-         raise HTTPException(500, str(e))
+         logger.error(f"Internal error: {traceback.format_exc()}")
+         raise HTTPException(500, "Internal server error")
```

---

### S.6 Стабильность: блокирующий event loop

**Файл:** `server/app.py`, строка 798

**Проблема:** `run_recolor_job()` — синхронная тяжёлая функция (10–30 сек), вызывается напрямую из async-эндпоинта. Полностью блокирует event loop. При 2+ одновременных запросах второй клиент ждёт indefinitely.

**Исправление:** Обернуть в `asyncio.to_thread()`:

```diff
-         response_content = run_recolor_job(
+         response_content = await asyncio.to_thread(run_recolor_job,
              img_bytes,
              point_x,
              point_y,
              material,
              color_hex,
              color_name,
              object_name,
              strength,
              guidance_scale,
              num_inference_steps,
              patina,
              color_r,
              color_g,
              color_b,
              from_pipette,
          )
```

Также добавить `import asyncio` в начало файла (строка 16).

---

### S.7 Стабильность: таймаут на инференс

**Файл:** `server/app.py`, строка 798

**Проблема:** Нет таймаута на инференс. Если SAM-2 или FLUX.2 зависнет, запрос будет висеть вечно, блокируя воркер.

**Исправление:** Обернуть вызов `run_recolor_job` в `asyncio.wait_for`:

```dart
response_content = await asyncio.wait_for(
    asyncio.to_thread(run_recolor_job, ...),
    timeout=90.0,
)
```

---

### S.8 Производительность: 5 последовательных инференсов SAM-2

**Файл:** `server/app.py`, строки 501–531

**Проблема:** 5 последовательных вызовов `_predictor.predict` (1 исходный + 4 jitter). Каждый запуск ~0.1–0.2с на RTX 4090, итого +0.5–1с задержки. На слабом GPU это +4–8с.

**Исправление:** Снизить до 3 прогонов (1 исходный + 2 jitter):

```diff
     # Генерируем 4 джиттер-точки вокруг исходной точки клика
-    jitter_offsets = [(8, 0), (-8, 0), (0, 8), (0, -8)]
+    jitter_offsets = [(8, 0), (0, -8)]
```

---

### S.9 Производительность: очистка памяти после каждого запроса

**Файл:** `server/app.py`, строки 707–710

**Проблема:** `torch.cuda.empty_cache()` + `gc.collect()` после каждого запроса. Паузы GC до 300–500мс. На RTX 4090 с 24GB VRAM это не нужно.

**Исправление:** Вызывать `gc.collect()` раз в N запросов (например, раз в 10). `empty_cache()` оставить только при OOM:

```python
# Добавить глобальный счётчик
_request_counter = 0

# В run_recolor_job, после возврата результата:
global _request_counter
_request_counter += 1
if _request_counter % 10 == 0:
    gc.collect()
```

---

### S.10 Дублирующиеся проверки `source_image is None`

**Файл:** `server/app.py`, строки 454, 465, 497, 626, 632, 637

**Проблема:** Многократные дублирующиеся проверки `if source_image is None`.

**Исправление:** Оставить одну проверку сразу после декодирования (строка 448–456).

---

### S.11 `run_recolor_job` принимает 14 позиционных аргументов

**Файл:** `server/app.py`, строки 423–438

**Проблема:** 14 позиционных аргументов — сложно читать, легко ошибиться при вызове.

**Исправление:** Использовать `@dataclass`:

```python
from dataclasses import dataclass

@dataclass
class RecolorTask:
    img_bytes: bytes
    point_x: float
    point_y: float
    material: str
    color_hex: str
    color_name: str
    object_name: str
    strength: float
    guidance_scale: float
    num_inference_steps: int
    patina: bool
    color_r: int | None = None
    color_g: int | None = None
    color_b: int | None = None
    from_pipette: bool = False
```

---

### S.12 Рефакторинг `server/app.py` (834 строки)

**Файл:** `server/app.py`

**Проблема:** Файл 834 строки. Всё смешано: конфиг, промпты, утилиты цветов, хэндлеры, heavy job. Нет модульности.

**Исправление:** Разбить на пакеты:

```
server/
  app.py              # Только FastAPI app, lifespan, middleware
  routes/
    ai.py             # Эндпоинты /health, /ai-recolor
  services/
    color.py          # get_color_hex_name(), BRIGHTNESS_MODIFIERS
    sam2.py           # SAM-2 загрузка и предсказание
    flux.py           # FLUX.2 загрузка и генерация
    prompts.py        # MATERIAL_PROMPTS, DEFAULT_PROMPT
  schemas/
    requests.py       # Pydantic модели для запросов
  config.py           # Конфигурация из env
```

---

### S.13 Логирование: `print`/`debugPrint` вместо `logging`

**Файл:** `server/app.py` (множественные строки)

**Проблема:** Используется `logger.info()`, `logger.debug()`, `logger.warning()`, `logger.error()` — это уже хорошо, но стоит добавить структурированное (JSON) логирование для продакшена.

**Исправление:**

1. Добавить JSON-формат логов в `server/app.py`

---

### S.14 Нет graceful shutdown

**Файл:** `server/app.py`, строка 833

**Проблема:** При остановке контейнера текущий запрос может быть прерван, и модель может остаться в неконсистентном состоянии.

**Исправление:** Добавить обработку сигналов в `lifespan`:

```python
import signal

async def lifespan(app: FastAPI):
    # ... load models ...
    yield
    # ... cleanup ...
```

---

### S.15 Нет ограничения на количество одновременных запросов

**Файл:** `server/app.py`, строка 716

**Проблема:** Rate limiter `10/minute` ограничивает запросы с одного IP, но нет ограничения на количество одновременных запросов к GPU. При 3+ одновременных запросов GPU будет перегружен.

**Исправление:** Добавить semaphore для ограничения параллелизма:

```python
import asyncio

MAX_CONCURRENT_REQUESTS = 2
_semaphore = asyncio.Semaphore(MAX_CONCURRENT_REQUESTS)

@app.post("/ai-recolor")
@limiter.limit("10/minute")
async def ai_recolor(request: Request, ...):
    async with _semaphore:
        # ... process ...
```

---

### S.16 Мониторинг и логирование в продакшене

**Файл:** `server/app.py`

**Проблема:** Нет структурированного логирования, нет метрик, нет трейсинга. При проблемах в продакшене будет сложно диагностировать.

**Исправление:**

1. Добавить JSON-формат логов в `server/app.py`
2. Добавить Prometheus метрики (latency, throughput, GPU utilization)
3. Добавить OpenTelemetry трейсинг

---

### S.17 Развёртывание: зависимости без версионирования

**Файл:** `server/requirements.ai.txt`

**Проблемы:**

- Строка 15: `xformers>=0.0.23` без верхней границы — при обновлении torch xformers может сломать сборку
- Строка 21: `git+https://github.com/facebookresearch/sam2.git` без тега/коммита — при изменении main-ветки сборка сломается
- Строка 13: `transformers>=4.38.0` без верхней границы

**Исправление:** Закрепить версии:

```diff
- xformers>=0.0.23
+ xformers==0.0.23.post1

- git+https://github.com/facebookresearch/sam2.git
+ git+https://github.com/facebookresearch/sam2.git@v1.0.1

- transformers>=4.38.0
+ transformers==4.38.0
```

---

### S.18 Server: unit-тесты

**Файл:** `server/test/`

**Проблема:** Нет тестов на сервере.

**Исправление:**

- Сервер: тесты валидации (`test_color_hex.py`, `test_sanitize_prompt.py`)

---

## NGINX

---

### N.1 Развёртывание: нет HTTPS

**Файл:** `nginx/nginx.conf`

**Проблема:** Вся коммуникация идёт по HTTP. API-ключи и изображения передаются в открытом виде. Для коммерческого продукта это неприемлемо.

**Исправление:** Добавить блок `server { listen 443 ssl; ... }` с сертификатами. Пример:

```nginx
server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/ssl/server.crt;
    ssl_certificate_key /etc/nginx/ssl/server.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location /ai-recolor {
        proxy_pass http://ai_server;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 120s;
        proxy_read_timeout 120s;
        client_max_body_size 50M;
        proxy_buffering off;
        proxy_request_buffering off;
    }

    location /health {
        proxy_pass http://ai_server;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
```

Также добавить в `docker-compose.yml`:

```yaml
volumes:
  - ./nginx/ssl:/etc/nginx/ssl:ro
```

---

### N.2 Мониторинг: ротация логов в nginx

**Файл:** `nginx/nginx.conf`

**Проблема:** Нет ротации логов nginx. При долгом запуске в продакшене логи могут заполнить диск.

**Исправление:** Настроить ротацию логов через `logrotate` или использовать `stderr`/`stdout` для Docker (логи в `json-file` драйвере Docker).

---

## DOCKER

---

### D.1 Стабильность: healthcheck использует curl, которого нет в контейнере

**Файл:** `docker-compose.yml`, строка 56

**Проблема:** Healthcheck использует `curl`, но в Dockerfile `curl` не установлен. Healthcheck не работает, контейнер может быть помечен как unhealthy без причины.

**Исправление:** Заменить на `python3` (уже есть в контейнере):

```yaml
healthcheck:
  test: ["CMD", "python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8001/health')"]
```

(Уже исправлено в текущем `docker-compose.yml`)

---

### D.2 Безопасность: порт 8001 проброшен наружу

**Файл:** `docker-compose.yml`, строки 25–26 (было ранее)

**Проблема:** Порт `8001:8001` проброшен наружу. Сервер ML-инференса должен быть доступен только через nginx.

**Исправление:** Убрать строки `ports` у `ai-server`.

```diff
-    ports:
-      - "8001:8001"
```

---

### D.3 Безопасность: `ipc: host`

**Файл:** `docker-compose.yml`, строка 31

**Проблема:** `ipc: host` даёт контейнеру доступ к IPC namespace хоста. Увеличивает attack surface.

**Исправление:** Удалить строку `ipc: host`. `shm_size: 16g` уже обеспечивает достаточный shared memory.

```diff
-    ipc: host                   # Доступ к IPC хоста
```

---

### D.4 Развёртывание: нет multi-stage Dockerfile

**Файл:** `server/Dockerfile`

**Проблема:** Нет multi-stage build. Финальный образ содержит `python3-dev`, `git`, `ca-certificates` и инструменты сборки. Увеличивает attack surface и размер образа.

**Исправление:** Разделить на `builder` и `runtime`:

```dockerfile
# Stage 1: Builder
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04 AS builder
RUN apt-get update && apt-get install -y python3-pip python3-dev git ca-certificates libglib2.0-0 libsm6 libxext6 libxrender1 libgl1-mesa-glx
WORKDIR /app
COPY requirements.ai.txt .
RUN pip3 install --user -r requirements.ai.txt --no-cache-dir
COPY app.py .

# Stage 2: Runtime
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04
RUN apt-get update && apt-get install -y python3 libglib2.0-0 libsm6 libxext6 libxrender1 libgl1-mesa-glx && rm -rf /var/lib/apt/lists/*
RUN useradd -m appuser
WORKDIR /app
COPY --from=builder /root/.local /home/appuser/.local
COPY --from=builder /app/app.py .
RUN chown -R appuser:appuser /app
USER appuser
EXPOSE 8001
CMD ["python3", "app.py"]
```

---

### D.5 Развёртывание: контейнер работает от root

**Файл:** `server/Dockerfile`, строка 2 (текущий)

**Проблема:** Контейнер работает от root. При компрометации атакующий получает root в контейнере.

**Исправление:** Добавить не-root пользователя (см. multi-stage Dockerfile выше).

---

### D.6 Развёртывание: `env_file` указывает на несуществующий файл

**Файл:** `docker-compose.yml`, строки 33–34

**Проблема:** `env_file: - .env` указывает на `server/.env`, который не существует. При запуске `docker-compose` будет предупреждение.

**Исправление:** Либо создать `server/.env` из `server/.env.example`, либо удалить `env_file` и использовать только секцию `environment` (которая уже есть).

---

### D.7 Развёртывание: нет `mem_limit`/`cpus` на сервисе

**Файл:** `docker-compose.yml`

**Проблема:** Нет ограничения памяти и CPU на уровне сервиса. При утечке памяти в Python/PyTorch контейнер может съесть всю RAM хоста.

**Исправление:** Добавить в секцию `ai-server`:

```yaml
deploy:
  resources:
    limits:
      memory: 12G
      cpus: "4"
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

---

### D.8 Развёртывание: `shm_size` захардкожен

**Файл:** `docker-compose.yml`, строка 25

**Проблема:** `shm_size: 16g` захардкожен. Для inference на 1024×1024 с SAM-2 + FLUX.2 достаточно 4–8GB. На серверах с ограниченной памятью 16GB может не влезт.

**Исправление:** Сделать переменной окружения:

```diff
-    shm_size: 16g
+    shm_size: ${SHM_SIZE:-8g}
```

---

### D.9 Развёртывание: graceful shutdown в docker-compose

**Файл:** `docker-compose.yml`

**Проблема:** При остановке контейнера текущий запрос может быть прерван, и модель может остаться в неконсистентном состоянии.

**Исправление:** Добавить в `docker-compose.yml`:

```yaml
stop_grace_period: 30s
```

---

## ИТОГОВАЯ СВОДКА

| Компонент                  | Кол-во задач | Приоритет        |
| -------------------------- | ------------ | ---------------- |
| **Client**                 | 13           | 🔴 / 🟠 / 🟡     |
| **Server**                 | 13           | 🔴 / 🟠 / 🟡     |
| **Nginx**                  | 2            | 🟠 / 🟡          |
| **Docker**                 | 9            | 🔴 / 🟠          |

**Всего:** 37 задач

### Порядок выполнения

#### Сначала (сегодня) — критично для релиза:

**Server:**
1. Исправить `server/app.py` — `_pipe.to(_device)` (S.2)
2. Добавить обработку `ValueError` для `color_hex` (S.3, S.4)
3. Обернуть `run_recolor_job` в `asyncio.to_thread` (S.6)
4. Добавить таймаут на инференс (S.7)
5. Заменить `raise HTTPException(500, str(e))` на безопасное сообщение (S.5)

**Docker:**
6. Убрать `ports` и `ipc: host` из `docker-compose.yml` (D.2, D.3)
7. Включить `DISABLE_SAFETY_CHECKER=False` (S.1)

**Client:**
8. Удалить production IP из `client/.env` и истории git (C.1)
9. Добавить `INTERNET` permission и `usesCleartextTraffic` в `AndroidManifest.xml` (C.2)

**Docker:**
10. Пересобрать и перезапустить контейнеры

#### Затем (завтра):

**Server:**
11. Сократить SAM-2 до 3 прогонов (S.8)
12. Оптимизировать очистку памяти (S.9)
13. Закрепить версии зависимостей (S.17)

**Docker:**
14. Добавить `mem_limit`/`cpus` в docker-compose (D.7)
15. Исправить `shm_size` на переменную окружения (D.8)

**Client:**
16. Сделать таймаут конфигурируемым (C.4)

#### Пост-релиз:

17. Multi-stage Dockerfile + non-root (D.4, D.5)
18. Добавить HTTPS в nginx (N.1)
19. Рефакторинг `app.py` на модули (S.12)
20. Разбить `AppState` на отдельные стейты (C.6)
21. Удалить dead code (C.7, C.8)
22. Добавить тесты (S.18, C.14)
23. Мониторинг и логирование (S.16, N.2)
24. Graceful shutdown (S.14, D.9)
25. Semaphore для ограничения параллелизма (S.15)
