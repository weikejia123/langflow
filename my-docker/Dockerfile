# Langflow 二开镜像
#
# 策略：基于官方镜像层（OS + Python 依赖 + venv），
# 用 wkj-dev 分支源码覆盖官方的 langflow 包，
# 并加装缺失的 optional 依赖。
#
# 这样做的优势：
#   1. 避免从零构建 Python/Node 等大量编译依赖
#   2. 官方镜像更新的 base layer 可复用
#   3. 后续只需 rebase 即可同步上游更新
#
# 构建:
#   docker build -t langflow-wkj:dev -f Dockerfile ..
#   （注意末尾的 .. 表示构建上下文是项目根目录）
#
# 或使用:
#   bash build.sh

FROM langflowai/langflow:latest

LABEL maintainer="wkj" \
      description="Langflow 二开镜像 — 基于官方镜像 + wkj-dev 源码"

# ------------------------------------------------------------------
# 1) 装缺失的 optional 依赖
#    官方镜像只装了 langflow-base 核心包，部分组件需要额外 pip 包。
#    发现新的缺失依赖时在此处追加即可。
# ------------------------------------------------------------------
RUN /app/.venv/bin/pip install --no-cache-dir \
    toolguard

# ------------------------------------------------------------------
# 2) 复制二开分支源码，覆盖官方包
#    将项目根目录全部复制进来（.dockerignore 过滤无关文件），
#    然后用 venv 的 pip 安装 langflow-base 和 langflow，
#    确保在官方镜像中我们的源码优先。
# ------------------------------------------------------------------
COPY --chown=user:1000 . /tmp/build/langflow-src/

# 备份前端构建产物 → pip install 源码(含 lfx) → 恢复前端
# 官方镜像的前端已编译好，我们的源码不含此产物
RUN cp -r /app/.venv/lib/python3.14/site-packages/langflow/frontend /tmp/langflow-frontend/ && \
    cd /tmp/build/langflow-src && \
    /app/.venv/bin/pip install --no-cache-dir --no-deps \
        src/lfx/ \
        src/backend/base/ \
        . \
    && rm -rf /tmp/build /app/.venv/lib/python3.14/site-packages/langflow/frontend \
    && mv /tmp/langflow-frontend \
      /app/.venv/lib/python3.14/site-packages/langflow/frontend

# 保留官方镜像的运行时设置
USER user
WORKDIR /app
EXPOSE 7860
CMD ["langflow", "run"]
