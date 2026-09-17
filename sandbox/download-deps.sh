#!/usr/bin/env bash
# ============================================================
# XuanMu Sandbox - 依赖下载脚本
# 从各工具的官方 Release 下载构建沙箱镜像所需的二进制依赖
#
# 使用方式：
#   cd sandbox
#   bash download-deps.sh        # 下载所有依赖
#   bash download-deps.sh --skip-existing   # 跳过已存在的文件
#   docker build -t sandbox-runtime:latest .   # 构建镜像
# ============================================================
set -e

cd "$(dirname "$0")"

# ---------- 版本号（与 Dockerfile ARG 保持一致）----------
GHIDRA_VERSION="12.1"
GHIDRA_BUILD="20260513"
JADX_VERSION="1.5.5"
HTTPX_VERSION="1.9.0"
OBSERVER_WARD_VERSION="2026.4.8"
AGENT_BROWSER_VERSION="0.3.4"

# ---------- 颜色 ----------
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
info() { echo -e "${BLUE}[..]${NC} $1"; }
err()  { echo -e "${RED}[ERR]${NC} $1"; exit 1; }

SKIP_EXISTING=false
[ "${1:-}" = "--skip-existing" ] && SKIP_EXISTING=true

# 下载函数：如果文件已存在且 --skip-existing 则跳过
download() {
    local url="$1"
    local output="$2"
    local desc="$3"

    if [ "$SKIP_EXISTING" = true ] && [ -f "$output" ]; then
        log "$desc 已存在，跳过"
        return
    fi

    info "下载 $desc ..."
    if curl -fSL --retry 3 --retry-delay 5 -o "$output" "$url"; then
        local size
        size=$(du -h "$output" | cut -f1)
        log "$desc 下载完成 ($size)"
    else
        rm -f "$output"
        err "$desc 下载失败: $url"
    fi
}

echo ""
echo "========================================"
echo "  XuanMu Sandbox 依赖下载"
echo "========================================"
echo ""

# ---------- 1. Ghidra ----------
download \
    "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_BUILD}.zip" \
    "ghidra.zip" \
    "Ghidra ${GHIDRA_VERSION}"

# ---------- 2. JADX ----------
download \
    "https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip" \
    "jadx.zip" \
    "JADX ${JADX_VERSION}"

# ---------- 3. httpx (ProjectDiscovery) ----------
download \
    "https://github.com/projectdiscovery/httpx/releases/download/v${HTTPX_VERSION}/httpx_${HTTPX_VERSION}_linux_amd64.zip" \
    "httpx.zip" \
    "httpx ${HTTPX_VERSION}"

# ---------- 4. observer-ward ----------
download \
    "https://github.com/emo-crab/observer_ward/releases/download/v${OBSERVER_WARD_VERSION}/observer_ward_amd64.deb" \
    "observer-ward.deb" \
    "observer-ward ${OBSERVER_WARD_VERSION}"

# ---------- 5. agent-browser-cli (npm tgz) ----------
download \
    "https://registry.npmjs.org/@anthropic-ai/agent-browser-cli-linux-x64/-/agent-browser-cli-linux-x64-${AGENT_BROWSER_VERSION}.tgz" \
    "agent-browser-cli.tgz" \
    "agent-browser-cli ${AGENT_BROWSER_VERSION}"

# ---------- 6. chrome-extensions ----------
# agent-browser 的 Chrome 扩展，从 vercel-labs/agent-browser 仓库的 npm 主包中提取
if [ "$SKIP_EXISTING" = true ] && [ -f "chrome-extensions.zip" ]; then
    log "chrome-extensions.zip 已存在，跳过"
else
    info "下载 agent-browser Chrome 扩展 ..."
    TMPDIR_EXT=$(mktemp -d)
    if curl -fSL --retry 3 -o "$TMPDIR_EXT/agent-browser.tgz" \
        "https://registry.npmjs.org/@anthropic-ai/agent-browser-cli/-/agent-browser-cli-${AGENT_BROWSER_VERSION}.tgz" 2>/dev/null; then
        # 从 npm 包中提取 chrome-extension 目录并打包成 zip
        tar xzf "$TMPDIR_EXT/agent-browser.tgz" -C "$TMPDIR_EXT" 2>/dev/null
        EXT_DIR=$(find "$TMPDIR_EXT/package" -type f -name "manifest.json" -path "*/chrome-extension/*" -exec dirname {} \; 2>/dev/null | head -1)
        if [ -n "$EXT_DIR" ] && [ -f "$EXT_DIR/manifest.json" ]; then
            (cd "$EXT_DIR" && zip -qr - .) > chrome-extensions.zip
            log "chrome-extensions.zip 已从 npm 包提取"
        else
            warn "无法从 npm 包中提取 Chrome 扩展"
            warn "请手动准备 chrome-extensions.zip（包含 manifest.json 等扩展文件）"
        fi
    else
        warn "Chrome 扩展下载失败，尝试备用方式 ..."
        warn "请手动准备 chrome-extensions.zip"
    fi
    rm -rf "$TMPDIR_EXT"
fi

# ---------- 检查结果 ----------
echo ""
echo "========================================"
echo "  下载结果"
echo "========================================"
echo ""

ALL_OK=true
for f in ghidra.zip jadx.zip httpx.zip observer-ward.deb agent-browser-cli.tgz chrome-extensions.zip; do
    if [ -f "$f" ]; then
        size=$(du -h "$f" | cut -f1)
        printf "  %-30s %s\n" "$f" "$size"
    else
        echo -e "  ${RED}$f${NC}  缺失"
        ALL_OK=false
    fi
done

echo ""
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}所有依赖已就绪！${NC}"
    echo ""
    echo "  下一步：构建沙箱镜像"
    echo "    docker build -t sandbox-runtime:latest ."
    echo ""
    echo "  或使用构建脚本："
    echo "    bash build.sh"
else
    echo -e "${YELLOW}部分依赖缺失，请手动下载后再构建。${NC}"
fi
