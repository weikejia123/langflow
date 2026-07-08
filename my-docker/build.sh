#!/usr/bin/env bash
# langflow 二开镜像构建脚本
set -euo pipefail

cd "$(dirname "$0")"

IMAGE_TAG="${1:-langflow-wkj:dev}"

echo "==> 构建镜像: $IMAGE_TAG"
docker build \
  -t "$IMAGE_TAG" \
  -f Dockerfile \
  .

echo ""
echo "==> 构建完成: $IMAGE_TAG"
echo "==> 使用方法:"
echo "   修改 docker/compose/langflow/compose.yaml"
echo "   将 image 改为 $IMAGE_TAG"
echo "   然后 docker compose up -d"
