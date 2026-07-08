# Langflow 二开镜像
# 基于官方镜像，加装缺失的 optional 依赖
#
# 构建:
#   docker build -t langflow-wkj:dev -f Dockerfile .
# 或使用构建脚本:
#   bash build.sh
#
# 使用:
#   修改 docker/compose/langflow/compose.yaml 中 image 为 langflow-wkj:dev

FROM langflowai/langflow:latest

LABEL maintainer="wkj" \
      description="Langflow 二开镜像 — 基于官方镜像 + 额外依赖"

USER root

# 安装缺失的 optional extras
RUN pip install --no-cache-dir \
    'langflow-base[toolguard]' \
    && rm -rf /root/.cache/pip

USER langflow

EXPOSE 7860

CMD ["langflow", "run"]
