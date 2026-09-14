# syntax=docker/dockerfile:1

# ============================================================
# 阶段 1：构建前端
# ============================================================
FROM node:22-alpine AS web-builder

WORKDIR /app/web

COPY web/package*.json ./
RUN npm ci

COPY web/ ./
RUN npm run build

# ============================================================
# 阶段 2：后端运行时
# ============================================================
FROM python:3.13-slim AS backend

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir -r requirements.txt

COPY app.py config.py database.py logger.py main.py ./
COPY core ./core
COPY handler ./handler
COPY middleware ./middleware
COPY model ./model
COPY router ./router
COPY schema ./schema
COPY service ./service
COPY utils ./utils
COPY --from=web-builder /app/web/dist-app ./web/dist-app

# 默认端口与 config.json.example 保持一致
EXPOSE 8000

# 健康检查：每 30 秒探测一次 /docs 端点
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/docs')"]

CMD ["python", "main.py"]
