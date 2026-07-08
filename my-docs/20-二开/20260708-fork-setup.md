# Langflow 二开设置

> V1-20260708

## 背景

之前已通过官方镜像部署了 Docker 容器（`langflow-test`），但未 fork 源码。本会话补全了源码管理。

## Fork 链路

```
GitHub: langflow-ai/langflow (官方源)
    │  fork ↓
GitHub: weikejia123/langflow (我们的 fork)
    │  clone ↓
本地: projects/my-forks/langflow-ai/langflow/
    │  push ↓
Gitea: localhost:3000/dzsoft/langflow (本地备份)
```

## 分支说明

| 分支 | 基于 | 说明 |
|------|------|------|
| `main` | `upstream/main` | 跟踪上游，只拉不推 |
| `wkj-dev` | `upstream/main`（def832f409）| **永久开发分支**，所有修改和文档都在此 |

## 同步上游

```bash
git fetch upstream main
git merge upstream/main   # 在 wkj-dev 上执行
```

## 管理原则

1. **`wkj-dev` 是唯一开发分支** — 所有修改、文档、配置改动都在此
2. **`main` 不动** — 只跟踪上游，确保随时可对比差异
3. **所有文档放 `my-docs/`** — 不污染上游目录结构
4. **Docker 配置在项目外** — `docker/compose/langflow/` 下
