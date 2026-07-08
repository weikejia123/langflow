# Langflow Docker 部署

> V2-20260708

## 现状

本地已通过 Docker Compose 运行 `langflow-test` 项目，使用**二开镜像** `langflow-wkj:dev`。

| 容器 | 端口 | 状态 |
|------|------|------|
| langflow-test-langflow-1 | 7860 → 7860 | 运行中 |
| langflow-test-postgres-1 | 5434 → 5432 | 运行中（healthy）|

## 镜像策略

```
langflow-wkj:dev
  └─ FROM langflowai/langflow:latest  ← 基础层（OS/Python/venv/全部依赖）
       ├─ pip install toolguard        ← 加装缺失依赖
       └─ pip install src/lfx/         ← 覆盖 lfx 包（含 settings）
       └─ pip install src/backend/base/ ← 覆盖 langflow-base 包
       └─ pip install .                ← 覆盖 langflow 主包
       └─ 恢复 frontend/               ← 保留官方构建的前端产物
```

设计原则：**最大化复用官方镜像层**，只用 pip install 替换源码层。

## 二开镜像构建

```bash
cd projects/my-forks/langflow-ai/langflow/my-docker
bash build.sh                          # 构建 langflow-wkj:dev
```

一次构建后，后续增量构建很快（Docker layer caching）。

## 配置

Compose 文件位于项目外部的 `docker/compose/langflow/compose.yaml`：

```yaml
name: langflow-test

services:
  langflow:
    image: langflow-wkj:dev
    pull_policy: never
    ports:
      - "7860:7860"
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - LANGFLOW_DATABASE_URL=postgresql://langflow:***@postgres:5432/langflow
      - LANGFLOW_AUTO_LOGIN=true
      - LANGFLOW_SUPERUSER=admin
      - LANGFLOW_SUPERUSER_PASSWORD=langflow2024
    volumes:
      - langflow-data:/app/langflow

  postgres:
    image: postgres:16-trixie
    environment:
      POSTGRES_USER: langflow
      POSTGRES_PASSWORD: langflow
      POSTGRES_DB: langflow
    ports:
      - "5434:5432"
```

## 访问

- **Web UI**: http://localhost:7860
- **超级管理员**: admin / langflow2024
- **PostgreSQL**: localhost:5434, user=langflow, password=langflow, db=langflow

## 加装依赖清单

| 依赖包 | 原因 | 安装方式 |
|--------|------|----------|
| toolguard | PoliciesComponent 必需 | `pip install toolguard` |

如需加装更多依赖，在 `my-docker/Dockerfile` 的 `RUN pip install` 行追加即可。

## 构建日志

- 2026-07-08: v1 首次构建成功，`HTTP 200 @ :7860`
