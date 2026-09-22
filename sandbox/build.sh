#!/usr/bin/env bash
# ============================================================
# XuanMu Sandbox - 构建沙箱镜像
# 自动检查依赖，缺失时调用 download-deps.sh 下载
#
# 使用方式：
#   cd sandbox
#   bash build.sh
# ============================================================
set -e

cd "$(dirname "$0")"

REQUIRED_FILES="ghidra.zip jadx.zip httpx.zip observer-ward.deb agent-browser-cli.tgz chrome-extensions.zip"

# 检查依赖是否齐全
missing=false
for f in $REQUIRED_FILES; do
    if [ ! -f "$f" ]; then
        missing=true
        break
    fi
done

if [ "$missing" = true ]; then
    echo "检测到依赖文件缺失，开始下载 ..."
    bash download-deps.sh --skip-existing "$@"

    # 再次检查
    for f in $REQUIRED_FILES; do
        if [ ! -f "$f" ]; then
            echo "错误：$f 仍然缺失，无法构建"
            exit 1
        fi
    done
fi

echo ""
echo "开始构建沙箱镜像 ..."
echo ""

docker build -t sandbox-runtime:latest .

echo ""
echo "构建完成！镜像：sandbox-runtime:latest"
echo ""
echo "在 XuanMu 前端的 Sandbox Images 页面添加此镜像："
echo "  Image Name:    sandbox-runtime:latest"
echo "  Control Port:  8000"
