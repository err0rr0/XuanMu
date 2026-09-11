#!/usr/bin/env bash
# ============================================================
# XuanMu RedTeam Agent - Docker 一键部署脚本
# 支持平台：macOS / Linux / Windows (Git Bash / WSL)
#
# 使用方式：
#   bash docker-setup.sh          # 首次部署（引导配置 + 启动）
#   bash docker-setup.sh start    # 启动服务
#   bash docker-setup.sh stop     # 停止服务
#   bash docker-setup.sh restart  # 重启服务
#   bash docker-setup.sh status   # 查看状态
#   bash docker-setup.sh logs     # 查看日志
#   bash docker-setup.sh clean    # 停止并清理所有数据
# ============================================================
set -e

cd "$(dirname "$0")"
PROJECT_DIR="$(pwd)"

# ---------- 颜色输出 ----------
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
step() { echo -e "${CYAN}[$1/$TOTAL_STEPS]${NC} $2"; }

TOTAL_STEPS=5
COMPOSE_FILE="docker-compose.prod.yml"
ENV_FILE=".env"
CONFIG_DIR=".xuanmu"
CONFIG_FILE="$CONFIG_DIR/config.json"
CONFIG_EXAMPLE="$CONFIG_DIR/config.json.example"

# ============================================================
# 工具函数
# ============================================================

detect_os() {
    case "$(uname -s)" in
        Linux*)   OS="Linux" ;;
        Darwin*)  OS="macOS" ;;
        CYGWIN*|MINGW*|MSYS*) OS="Windows" ;;
        *)        OS="Unknown" ;;
    esac
    echo "$OS"
}

# 检测可用的 docker compose 命令
detect_compose_cmd() {
    if docker compose version &>/dev/null; then
        echo "docker compose"
    elif command -v docker-compose &>/dev/null; then
        echo "docker-compose"
    else
        echo ""
    fi
}

check_docker() {
    local os="$1"

    if ! command -v docker &>/dev/null; then
        echo ""
        echo -e "${RED}未检测到 Docker！${NC}"
        echo ""
        case "$os" in
            macOS)
                echo "  macOS 安装方式："
                echo "    1. 下载 Docker Desktop: https://www.docker.com/products/docker-desktop/"
                echo "    2. 或使用 Homebrew:  brew install --cask docker"
                ;;
            Linux)
                echo "  Linux 安装方式："
                echo "    curl -fsSL https://get.docker.com | sh"
                echo "    sudo usermod -aG docker \$USER"
                echo "    # 注销并重新登录后生效"
                ;;
            Windows)
                echo "  Windows 安装方式："
                echo "    1. 下载 Docker Desktop: https://www.docker.com/products/docker-desktop/"
                echo "    2. 安装后确保 WSL 2 后端已启用"
                ;;
        esac
        echo ""
        err "请安装 Docker 后重新运行此脚本"
    fi

    # 检查 Docker 守护进程是否运行
    if ! docker info &>/dev/null; then
        echo ""
        echo -e "${RED}Docker 守护进程未运行！${NC}"
        echo ""
        case "$os" in
            macOS|Windows)
                echo "  请启动 Docker Desktop 应用程序，等待其完全启动后重试。"
                ;;
            Linux)
                echo "  请启动 Docker 服务："
                echo "    sudo systemctl start docker"
                ;;
        esac
        echo ""
        err "Docker 未运行"
    fi

    COMPOSE_CMD=$(detect_compose_cmd)
    if [ -z "$COMPOSE_CMD" ]; then
        err "未检测到 Docker Compose，请确保 Docker 版本 >= 20.10"
    fi
}

# 生成随机字符串
generate_random_key() {
    if command -v openssl &>/dev/null; then
        openssl rand -base64 32
    else
        python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || \
        cat /dev/urandom | head -c 32 | base64 | tr -d '\n'
    fi
}

# ============================================================
# 配置生成
# ============================================================

setup_env_file() {
    if [ -f "$ENV_FILE" ]; then
        log ".env 已存在，跳过"
        return
    fi

    info "从模板生成 .env ..."
    cp .env.example "$ENV_FILE"

    # 生成随机数据库密码
    local db_pass
    db_pass=$(generate_random_key | cut -c1-16)
    # 跨平台 sed
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s/POSTGRES_PASSWORD=changeme/POSTGRES_PASSWORD=${db_pass}/" "$ENV_FILE"
        sed -i '' "s/PGADMIN_PASSWORD=changeme/PGADMIN_PASSWORD=${db_pass}/" "$ENV_FILE"
    else
        sed -i "s/POSTGRES_PASSWORD=changeme/POSTGRES_PASSWORD=${db_pass}/" "$ENV_FILE"
        sed -i "s/PGADMIN_PASSWORD=changeme/PGADMIN_PASSWORD=${db_pass}/" "$ENV_FILE"
    fi

    log ".env 已生成（数据库密码已随机生成）"
}

# 从 .env 读取变量值
read_env_var() {
    local var_name="$1"
    local default_val="$2"
    if [ -f "$ENV_FILE" ]; then
        local val
        val=$(grep "^${var_name}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '\r')
        if [ -n "$val" ]; then
            echo "$val"
            return
        fi
    fi
    echo "$default_val"
}

setup_config_json() {
    mkdir -p "$CONFIG_DIR"

    if [ -f "$CONFIG_FILE" ]; then
        log "config.json 已存在，跳过"
        return
    fi

    if [ ! -f "$CONFIG_EXAMPLE" ]; then
        err "未找到 $CONFIG_EXAMPLE，仓库文件不完整"
    fi

    info "从模板生成 config.json ..."

    # 读取 .env 中的数据库配置
    local db_user db_pass db_name
    db_user=$(read_env_var "POSTGRES_USER" "root")
    db_pass=$(read_env_var "POSTGRES_PASSWORD" "changeme")
    db_name=$(read_env_var "POSTGRES_DB" "z3r0")
    local encrypt_key
    encrypt_key=$(generate_random_key)

    # 使用 Python 生成配置（跨平台兼容，不依赖 jq）
    python3 <<PYEOF
import json, sys

with open("$CONFIG_EXAMPLE", "r", encoding="utf-8") as f:
    cfg = json.load(f)

# 系统配置
cfg["system"]["listen_addr"] = "0.0.0.0"
cfg["system"]["listen_port"] = 8000
cfg["system"]["encrypt_key"] = "$encrypt_key"
cfg["system"]["bootstrap_admin"]["enabled"] = True
cfg["system"]["bootstrap_admin"]["username"] = "admin"
cfg["system"]["bootstrap_admin"]["email"] = "admin@xuanmu.local"
cfg["system"]["bootstrap_admin"]["password"] = "admin123"

# 数据库配置 —— Docker 容器间通过服务名互通
cfg["database"]["host"] = "postgres"
cfg["database"]["port"] = 5432
cfg["database"]["database"] = "$db_name"
cfg["database"]["username"] = "$db_user"
cfg["database"]["password"] = "$db_pass"

# 清空示例 API Key
for agent in cfg.get("agents", {}).values():
    agent["api_key"] = ""

with open("$CONFIG_FILE", "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=4, ensure_ascii=False)
    f.write("\n")

print("done")
PYEOF

    log "config.json 已生成"
    warn "数据库 host 已设为 'postgres'（Docker 内部服务名）"
}

# ============================================================
# LLM API Key 配置引导
# ============================================================

configure_llm_interactive() {
    # 检查是否已有 API Key
    local has_key
    has_key=$(python3 -c "
import json
with open('$CONFIG_FILE', 'r') as f:
    cfg = json.load(f)
keys = [a.get('api_key','') for a in cfg.get('agents',{}).values()]
print('yes' if any(keys) else 'no')
" 2>/dev/null || echo "no")

    if [ "$has_key" = "yes" ]; then
        log "检测到已配置 API Key，跳过配置引导"
        return
    fi

    echo ""
    echo -e "${CYAN}============================================${NC}"
    echo -e "${CYAN}  配置 LLM API Key${NC}"
    echo -e "${CYAN}============================================${NC}"
    echo ""
    echo "  XuanMu 需要 LLM API 才能工作。"
    echo "  支持 OpenAI 兼容接口：DeepSeek / Qwen / GLM 等。"
    echo ""
    echo "  常用服务商："
    echo "    DeepSeek:  https://api.deepseek.com/v1"
    echo "    通义千问:  https://dashscope.aliyuncs.com/compatible-mode/v1"
    echo "    智谱 GLM:  https://open.bigmodel.cn/api/paas/v4"
    echo ""

    read -r -p "  是否现在配置 API Key？(Y/n) " yn
    yn="${yn:-Y}"

    if [[ "$yn" =~ ^[Nn] ]]; then
        warn "跳过 API Key 配置"
        warn "稍后请手动编辑 $CONFIG_FILE 或运行 bash config-tool.sh"
        return
    fi

    echo ""
    read -r -p "  API Key: " api_key
    if [ -z "$api_key" ]; then
        warn "未输入 API Key，跳过"
        return
    fi

    read -r -p "  API 地址 (回车默认 https://api.deepseek.com/v1): " base_url
    base_url="${base_url:-https://api.deepseek.com/v1}"

    read -r -p "  模型名称 (回车默认 deepseek-chat): " model_name
    model_name="${model_name:-deepseek-chat}"

    python3 <<PYEOF
import json

with open("$CONFIG_FILE", "r", encoding="utf-8") as f:
    cfg = json.load(f)

for agent in cfg.get("agents", {}).values():
    agent["api_key"] = "$api_key"
    agent["base_url"] = "$base_url"
    agent["model"] = "$model_name"

with open("$CONFIG_FILE", "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=4, ensure_ascii=False)
    f.write("\n")
PYEOF

    log "所有智能体的 API Key 已配置"
}

# ============================================================
# Docker 操作
# ============================================================

compose_up() {
    info "构建并启动 Docker 容器 ..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d --build

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  XuanMu 部署成功！${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    local port
    port=$(read_env_var "XUANMU_PORT" "8000")
    echo "  Web 界面:    http://localhost:${port}"
    echo "  API 文档:    http://localhost:${port}/docs"
    echo "  管理员登录:  admin@xuanmu.local / admin123"
    echo ""
    echo "  常用命令："
    echo "    查看日志:  bash docker-setup.sh logs"
    echo "    停止服务:  bash docker-setup.sh stop"
    echo "    重启服务:  bash docker-setup.sh restart"
    echo "    查看状态:  bash docker-setup.sh status"
    echo ""
    warn "首次使用请立即修改默认管理员密码！"
    echo ""
}

compose_stop() {
    info "停止服务 ..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" down
    log "服务已停止"
}

compose_restart() {
    info "重启服务 ..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" restart
    log "服务已重启"
}

compose_status() {
    $COMPOSE_CMD -f "$COMPOSE_FILE" ps
}

compose_logs() {
    $COMPOSE_CMD -f "$COMPOSE_FILE" logs -f --tail=100
}

compose_clean() {
    echo ""
    warn "此操作将停止所有容器并删除数据卷（数据库数据将丢失）！"
    read -r -p "  确认清理？(y/N) " yn
    if [[ ! "$yn" =~ ^[Yy] ]]; then
        info "已取消"
        return
    fi
    $COMPOSE_CMD -f "$COMPOSE_FILE" down -v
    log "容器和数据卷已清理"
}

# ============================================================
# 主流程
# ============================================================

# 处理子命令
case "${1:-}" in
    start)
        OS=$(detect_os)
        check_docker "$OS"
        compose_up
        exit 0
        ;;
    stop)
        OS=$(detect_os)
        check_docker "$OS"
        compose_stop
        exit 0
        ;;
    restart)
        OS=$(detect_os)
        check_docker "$OS"
        compose_restart
        exit 0
        ;;
    status)
        OS=$(detect_os)
        check_docker "$OS"
        compose_status
        exit 0
        ;;
    logs)
        OS=$(detect_os)
        check_docker "$OS"
        compose_logs
        exit 0
        ;;
    clean)
        OS=$(detect_os)
        check_docker "$OS"
        compose_clean
        exit 0
        ;;
    help|--help|-h)
        echo "用法: bash docker-setup.sh [命令]"
        echo ""
        echo "命令："
        echo "  (无)       首次部署（引导配置 + 启动）"
        echo "  start      启动服务"
        echo "  stop       停止服务"
        echo "  restart    重启服务"
        echo "  status     查看容器状态"
        echo "  logs       查看实时日志"
        echo "  clean      停止并清理所有数据（慎用）"
        echo "  help       显示此帮助"
        exit 0
        ;;
esac

# ---------- 首次部署流程 ----------
echo ""
echo "========================================"
echo "  XuanMu RedTeam Agent"
echo "  Docker 一键部署"
echo "  v0.2.1"
echo "========================================"
echo ""

OS=$(detect_os)

step 1 "检测运行环境 ..."
info "操作系统: $OS ($(uname -s) $(uname -m))"

check_docker "$OS"

log "Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
log "Compose: $COMPOSE_CMD"

step 2 "生成环境变量文件 ..."
setup_env_file

step 3 "生成应用配置文件 ..."
setup_config_json

step 4 "配置 LLM API Key ..."
configure_llm_interactive

step 5 "构建并启动服务 ..."
compose_up
