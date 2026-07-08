# langflow

| 维度 | 内容 |
|------|------|
| **用途** | AI Agent 和 RAG 应用的可视化工作流构建平台 |
| **应用场景** | 拖拽式构建 LLM 流程、Agent 编排、RAG 流水线、工具链集成 |
| **标签** | Agent编排|工作流|可视化|LLM|RAG|FastAPI|React |
| **技术栈** | Python 3.10+ | FastAPI | React/TypeScript | Vite | uv | SQLAlchemy | lfx CLI |
| **内部版本** | V2-20260708 |
| **依赖** | uv, Node.js >= 20, make, Docker |
| **关联** | fork: weikejia123/langflow | upstream: langflow-ai/langflow | gitea: dzsoft/langflow |

## 分支策略

| 分支 | 用途 |
|------|------|
| `main` | 跟踪上游 `langflow-ai/langflow` main，只拉不推 |
| `wkj-dev` | **永久开发分支** — 所有二改和文档都在此分支 |

## 双远程

| remote | URL | 用途 |
|--------|-----|------|
| `origin` | `https://github.com/weikejia123/langflow.git` | GitHub fork，代码推送 |
| `gitea` | `http://localhost:3000/dzsoft/langflow.git` | 本地 Gitea 备份 |
| `upstream` | `https://github.com/langflow-ai/langflow.git` | 官方源，只拉不推 |

## 本地部署

Docker 容器 `langflow-test` 已部署在本地，参见 `my-docs/10-部署/`。
