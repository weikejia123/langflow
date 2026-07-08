#!/usr/bin/env bash
# langflow 二开镜像构建脚本
# 注意：构建上下文需设为项目根目录（包含 src/ 源码）
set -euo pipefail

cd "$(dirname "$0")"
PROJECT_ROOT="$(cd .. && pwd)"

IMAGE_TAG="${1:-langflow-wkj:dev}"

echo "==> 构建镜像: $IMAGE_TAG"
echo "    构建上下文: $PROJECT_ROOT"
docker build \
  -t "$IMAGE_TAG" \
  -f Dockerfile \
  "$PROJECT_ROOT"

echo ""
echo "==> 构建完成: $IMAGE_TAG"
echo "==> 使用方法:"
echo "   修改 docker/compose/langflow/compose.yaml"
echo "   将 image 改为 $IMAGE_TAG"
echo "   然后 docker compose up -d"
