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

# 端口通过环境变量 XUANMU_LISTEN_PORT 控制，默认 8000
ENV XUANMU_LISTEN_PORT=8000
EXPOSE ${XUANMU_LISTEN_PORT}

# 健康检查：从环境变量读取端口
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD python -c "import os,urllib.request; urllib.request.urlopen(f'http://127.0.0.1:{os.environ.get(\"XUANMU_LISTEN_PORT\",8000)}/docs')"

CMD ["python", "main.py"]
