#!/bin/bash
# XuanMu Sandbox 一键部署脚本 (Ubuntu amd64 服务器)
# 用法: curl -sSL <url> | bash 或 bash deploy-ubuntu.sh
#
# 前提: 服务器已安装 Docker

set -euo pipefail

echo "=== XuanMu Sandbox 快速部署 ==="
echo ""

# 检查 Docker
if ! command -v docker &>/dev/null; then
    echo "[!] Docker 未安装，正在安装..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo "[✓] Docker 安装完成"
fi

# 检查架构
ARCH=$(uname -m)
if [ "$ARCH" != "x86_64" ]; then
    echo "[!] 警告: 当前架构为 $ARCH，sandbox 镜像为 amd64，可能需要 QEMU 模拟"
fi

echo "[*] 开始构建 sandbox 镜像..."
echo "    (Ubuntu amd64 原生构建，通常 5-10 分钟)"
echo ""

cd "$(dirname "$0")"

# 检查是否有预下载文件，没有就下载
download_if_missing() {
    local file="$1" url="$2"
    if [ ! -f "$file" ]; then
        echo "[*] 下载 $file ..."
        curl --retry 5 --retry-delay 5 --retry-all-errors -fSL "$url" -o "$file"
    else
        echo "[✓] $file 已存在，跳过下载"
    fi
}

AGENT_BROWSER_VERSION=0.3.4
GHIDRA_VERSION=12.1
GHIDRA_BUILD=20260513
JADX_VERSION=1.5.5
OBSERVER_WARD_VERSION=2026.6.28
HTTPX_VERSION=1.9.0

download_if_missing "ghidra.zip" \
    "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_BUILD}.zip"

download_if_missing "jadx.zip" \
    "https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip"

download_if_missing "chrome-extensions.zip" \
    "https://github.com/sleepinginsummer/agent-browser-cli/releases/download/v${AGENT_BROWSER_VERSION}/chrome-extensions.zip"

download_if_missing "agent-browser-cli.tgz" \
    "https://github.com/sleepinginsummer/agent-browser-cli/releases/download/v${AGENT_BROWSER_VERSION}/sleepinsummer-agent-browser-cli-linux-x64-${AGENT_BROWSER_VERSION}.tgz"

download_if_missing "observer-ward.deb" \
    "https://github.com/emo-crab/observer_ward/releases/download/v${OBSERVER_WARD_VERSION}/observer-ward_v${OBSERVER_WARD_VERSION}_x86_64-unknown-linux-musl.deb"

download_if_missing "httpx.zip" \
    "https://github.com/projectdiscovery/httpx/releases/download/v${HTTPX_VERSION}/httpx_${HTTPX_VERSION}_linux_amd64.zip"

echo ""
echo "[*] 构建 Docker 镜像..."
docker build -t sandbox-runtime:latest .

echo ""
echo "[✓] 镜像构建完成!"
echo ""

# 启动容器
CONTAINER_NAME="xuanmu-sandbox"
TOKEN=$(openssl rand -base64 32 | tr -d '/+=')

# 停掉旧容器
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "[*] 启动 sandbox 容器..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p 18000:8000 \
    -p 18080:8080 \
    -e SANDBOX_CONTROL_PROXY_TOKEN="$TOKEN" \
    sandbox-runtime:latest

echo ""
echo "=========================================="
echo "  XuanMu Sandbox 部署完成!"
echo "=========================================="
echo ""
echo "  容器名称: $CONTAINER_NAME"
echo "  API 端口: 18000 (sandbox-proxy)"
echo "  VNC 端口: 18080 (noVNC 浏览器桌面)"
echo "  Token:    $TOKEN"
echo ""
echo "  验证: curl -H 'Authorization: Bearer $TOKEN' http://localhost:18000/"
echo "  VNC:  http://localhost:18080"
echo ""
echo "  将此 token 配置到 XuanMu 主应用中即可使用。"
echo "=========================================="
