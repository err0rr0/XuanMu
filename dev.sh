#!/usr/bin/env bash
# ============================================================
# XuanMu RedTeam Agent - 本地开发脚本
# Docker 只跑 PostgreSQL，后端本机热跑，改代码自动重启
#
# 使用方式：
#   bash dev.sh              # 启动后端（热重载）
#   bash dev.sh --frontend   # 同时启动前端 Vite dev server
#   bash dev.sh stop         # 停止开发数据库
#   bash dev.sh db           # 只启动数据库，不启动后端
#   bash dev.sh logs         # 查看数据库日志
# ============================================================
set -e

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"
VENV_DIR="$PROJECT_DIR/.venv"
COMPOSE_FILE="docker-compose.dev.yml"
ENV_FILE=".env"
CONFIG_DIR=".xuanmu"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_EXAMPLE="$CONFIG_DIR/config.json.example"

# ---------- 颜色 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[..]${NC} $1"; }

# ---------- .env 读取 ----------
read_env_var() {
    local var_name="$1" default_val="$2"
    if [ -f "$ENV_FILE" ]; then
        local val
        val=$(grep "^${var_name}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '\r')
        [ -n "$val" ] && echo "$val" && return
    fi
    echo "$default_val"
}

# ---------- Docker Compose 命令检测 ----------
detect_compose_cmd() {
    if docker compose version &>/dev/null; then
        echo "docker compose"
    elif command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

# ============================================================
# 子命令处理
# ============================================================
case "${1:-}" in
    stop)
        COMPOSE_CMD=$(detect_compose_cmd)
        [ -z "$COMPOSE_CMD" ] && err "未检测到 Docker Compose"
        info "停止开发数据库..."
        $COMPOSE_CMD -f "$COMPOSE_FILE" down
        log "已停止"
        exit 0
        ;;
    db)
        COMPOSE_CMD=$(detect_compose_cmd)
        [ -z "$COMPOSE_CMD" ] && err "未检测到 Docker Compose"
        info "启动开发数据库..."
        $COMPOSE_CMD -f "$COMPOSE_FILE" up -d
        log "PostgreSQL 已启动（端口 $(read_env_var POSTGRES_PORT 5400)）"
        exit 0
        ;;
    logs)
        COMPOSE_CMD=$(detect_compose_cmd)
        [ -z "$COMPOSE_CMD" ] && err "未检测到 Docker Compose"
        $COMPOSE_CMD -f "$COMPOSE_FILE" logs -f --tail=50
        exit 0
        ;;
    help|--help|-h)
        echo "用法: bash dev.sh [选项]"
        echo ""
        echo "选项："
        echo "  (无)          启动数据库 + 后端（热重载）"
        echo "  --frontend    同时启动前端 Vite dev server"
        echo "  stop          停止开发数据库"
        echo "  db            只启动数据库"
        echo "  logs          查看数据库日志"
        echo "  help          显示此帮助"
        exit 0
        ;;
esac

# ============================================================
# 主流程：启动开发环境
# ============================================================
START_FRONTEND=false
if [ "${1:-}" = "--frontend" ]; then
    START_FRONTEND=true
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  XuanMu 本地开发模式${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ---- 1. 确保 .env 存在 ----
if [ ! -f "$ENV_FILE" ]; then
    info "从模板生成 .env ..."
    cp .env.example "$ENV_FILE"
    log ".env 已生成"
fi

# ---- 2. 确保 config.json 存在 ----
if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$CONFIG_EXAMPLE" ]; then
        err "未找到 $CONFIG_EXAMPLE"
    fi
    info "从模板生成 config.json ..."

    local_db_user=$(read_env_var "POSTGRES_USER" "root")
    local_db_pass=$(read_env_var "POSTGRES_PASSWORD" "xuanmu2025")
    local_db_name=$(read_env_var "POSTGRES_DB" "z3r0")
    local_db_port=$(read_env_var "POSTGRES_PORT" "5400")
    local_app_port=$(read_env_var "XUANMU_PORT" "8000")

    # 本地开发：数据库连 127.0.0.1 + 映射端口（不是 Docker 内部的 postgres:5432）
    ENCRYPT_KEY=$(openssl rand -base64 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_urlsafe(32))")

    python3 <<PYEOF
import json
with open("$CONFIG_EXAMPLE", "r", encoding="utf-8") as f:
    cfg = json.load(f)

cfg["system"]["listen_addr"] = "127.0.0.1"
cfg["system"]["listen_port"] = int("$local_app_port")
cfg["system"]["encrypt_key"] = "$ENCRYPT_KEY"
cfg["system"]["bootstrap_admin"]["enabled"] = True
cfg["system"]["bootstrap_admin"]["username"] = "admin"
cfg["system"]["bootstrap_admin"]["email"] = "admin@xuanmu.local"
cfg["system"]["bootstrap_admin"]["password"] = "admin123"

cfg["database"]["host"] = "127.0.0.1"
cfg["database"]["port"] = int("$local_db_port")
cfg["database"]["database"] = "$local_db_name"
cfg["database"]["username"] = "$local_db_user"
cfg["database"]["password"] = "$local_db_pass"

for agent in cfg.get("agents", {}).values():
    agent["api_key"] = ""

with open("$CONFIG_FILE", "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=4, ensure_ascii=False)
    f.write("\n")
PYEOF
    log "config.json 已生成（本地开发模式：127.0.0.1:$local_db_port）"
    warn "请编辑 $CONFIG_FILE 填入 LLM API Key"
fi

# ---- 3. 启动 PostgreSQL 容器 ----
COMPOSE_CMD=$(detect_compose_cmd)
[ -z "$COMPOSE_CMD" ] && err "未检测到 Docker Compose，请先安装 Docker"

info "启动 PostgreSQL ..."
$COMPOSE_CMD -f "$COMPOSE_FILE" up -d

# 等待 PostgreSQL 就绪
local_retries=0
until docker exec xuanmu-dev-postgres pg_isready -U "$(read_env_var POSTGRES_USER root)" -d "$(read_env_var POSTGRES_DB z3r0)" &>/dev/null; do
    local_retries=$((local_retries + 1))
    if [ $local_retries -ge 30 ]; then
        err "PostgreSQL 启动超时"
    fi
    sleep 1
done
log "PostgreSQL 就绪（端口 $(read_env_var POSTGRES_PORT 5400)）"

# ---- 4. Python 虚拟环境 ----
info "配置 Python 环境 ..."
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    log "虚拟环境已创建"
fi
source "$VENV_DIR/bin/activate"

# 检查依赖是否需要安装/更新
if [ ! -f "$VENV_DIR/.deps_installed" ] || [ requirements.txt -nt "$VENV_DIR/.deps_installed" ]; then
    info "安装 Python 依赖 ..."
    pip install -q --upgrade pip
    pip install -q -r requirements.txt
    touch "$VENV_DIR/.deps_installed"
    log "依赖已安装"
else
    log "依赖已就绪"
fi

# ---- 5. 启动前端（可选）----
FRONTEND_PID=""
if [ "$START_FRONTEND" = true ]; then
    if [ -d "$PROJECT_DIR/web" ] && [ -f "$PROJECT_DIR/web/package.json" ]; then
        info "启动前端 Vite dev server ..."
        if [ ! -d "$PROJECT_DIR/web/node_modules" ]; then
            (cd "$PROJECT_DIR/web" && npm install)
        fi
        (cd "$PROJECT_DIR/web" && npm run dev) &
        FRONTEND_PID=$!
        log "前端 dev server 已启动 (PID: $FRONTEND_PID)"
    else
        warn "web 目录不存在，跳过前端"
    fi
fi

# ---- 6. 启动后端（热重载）----
APP_PORT=$(read_env_var "XUANMU_PORT" "8000")
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  开发环境已就绪${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  后端 API:     http://127.0.0.1:${APP_PORT}"
echo "  API 文档:     http://127.0.0.1:${APP_PORT}/docs"
if [ "$START_FRONTEND" = true ] && [ -n "$FRONTEND_PID" ]; then
echo "  前端 (Vite):  http://127.0.0.1:5173"
fi
echo "  数据库:       127.0.0.1:$(read_env_var POSTGRES_PORT 5400)"
echo "  管理员:       admin@xuanmu.local / admin123"
echo ""
echo "  后端热重载已开启，改代码自动重启。"
echo "  按 Ctrl+C 停止后端（数据库容器继续运行）。"
echo "  停止数据库：bash dev.sh stop"
echo ""
echo "========================================"
echo ""

# 清理函数：Ctrl+C 时同时停掉前端
cleanup() {
    if [ -n "$FRONTEND_PID" ]; then
        kill "$FRONTEND_PID" 2>/dev/null
    fi
}
trap cleanup EXIT

# 热重载模式启动后端
# 通过环境变量告诉 main.py 启用 reload
export XUANMU_DEV_RELOAD=1
exec python main.py
