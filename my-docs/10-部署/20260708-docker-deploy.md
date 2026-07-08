# Langflow Docker 部署

> V1-20260708

## 现状

本地已通过 Docker Compose 运行 `langflow-test` 项目，使用官方镜像。

| 容器 | 端口 | 状态 |
|------|------|------|
| langflow-test-langflow-1 | 7860 → 7860 | 运行中 |
| langflow-test-postgres-1 | 5434 → 5432 | 运行中（healthy）|

## 配置

Compose 文件位于项目外部的 `docker/compose/langflow/compose.yaml`：

```yaml
name: langflow-test

services:
  langflow:
    image: langflowai/langflow:latest
    pull_policy: always
    ports:
      - "7860:7860"
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

## 二开部署计划（TODO）

当前使用官方镜像，后续二开需切换为自编译镜像：

1. 在 `wkj-dev` 分支修改源码
2. 本地构建 Docker 镜像
3. 更新 compose.yaml 使用自编译镜像
4. 重启容器验证
