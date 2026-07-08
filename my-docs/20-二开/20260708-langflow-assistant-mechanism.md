# Langflow 助手（FlowBuilderAssistant）深度分析报告

> **Langflow 版本**: 1.10.2  
> **分析日期**: 2026-07-08  
> **分析时间**: 15:30 UTC+8  
> **分析人**: 大总管（my-agent-group）

---

## 目录

1. [概述](#1-概述)
2. [整体架构](#2-整体架构)
3. [FlowBuilderAssistant 核心流程](#3-flowbuilderassistant-核心流程)
4. [工作流创建工具集详解](#4-工作流创建工具集详解)
5. [工作流规格格式（Flow Spec）](#5-工作流规格格式flow-spec)
6. [工作流 JSON 文件 Schema](#6-工作流-json-文件-schema)
7. [助手系统提示词（FLOW_BUILDER_PROMPT）](#7-助手系统提示词flow_builder_prompt)
8. [意图识别与路由](#8-意图识别与路由)
9. [验证与重试机制](#9-验证与重试机制)
10. [前端交互流程](#10-前端交互流程)
11. [组件注册表机制](#11-组件注册表机制)
12. [典型工作流创建全流程](#12-典型工作流创建全流程)
13. [附录：关键源码位置](#13-附录关键源码位置)

---

## 1. 概述

Langflow 助手（正式名称为 **FlowBuilderAssistant**）是 Langflow 内置的 AI Agent，能够通过自然语言对话：
- **自动创建完整的工作流** — 从用户描述生成整个流程
- **增量编辑现有工作流** — 添加/删除/修改组件
- **运行工作流并返回结果** — 在画布上执行并反馈

核心机制是：**一个配置了 12 个 MCP 工具的 LLM Agent**，这些工具封装了组件搜索、描述、添加、连接、配置、生成、运行等全部能力。Agent 通过 `build_flow_from_spec` 接收一种**文本规格格式**（Flow Spec），将其解析为完整的 JSON 工作流文件，推送到前端画布。

---

## 2. 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                     前端 (React/TypeScript)                  │
│  ┌─────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ AssistantPanel │  │ FlowBuilderWelcome │  │ Canvas (ReactFlow)│
│  │ (侧边栏对话面板)│  │ （空画布欢迎弹窗） │  │  (工作流画布)    │
│  └──────┬──────┘  └────────┬─────────┘  └───────┬───────┘  │
│         │                  │                     │           │
│         └──────────────────┴─────────────────────┘           │
└─────────────────────────────┬───────────────────────────────┘
                              │ POST /api/v1/run/{assistantFlowId}
                              │        (SSE 流式响应)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  后端 (FastAPI / Python)                      │
│                                                               │
│  ┌─────────────────┐    ┌──────────────────────────────┐    │
│  │  agentic/api/    │    │  agentic/services/           │    │
│  │  router.py       │───▶│  assistant_service.py       │    │
│  │  (API 路由)      │    │  (意图分类+执行+重试循环)    │    │
│  └─────────────────┘    └───────────┬──────────────────┘    │
│                                      │                       │
│  ┌───────────────────────────────────▼──────────────────┐   │
│  │            FlowBuilderAssistant 流程                   │   │
│  │                                                       │   │
│  │  ┌────────────┐  ┌──────────────┐  ┌──────────────┐  │   │
│  │  │ ChatInput  │─▶│ Agent (LLM)  │─▶│ ChatOutput   │  │   │
│  │  │ (用户输入)  │  │ (12个MCP工具) │  │ (助手回复)    │  │   │
│  │  └────────────┘  └──────┬───────┘  └──────────────┘  │   │
│  │                         │                              │   │
│  │  ┌──────────────────────▼────────────────────┐        │   │
│  │  │          MCP 工具集 (12 tools)              │        │   │
│  │  │                                            │        │   │
│  │  │  发现: search_components                   │        │   │
│  │  │        describe_component                   │        │   │
│  │  │        get_field_value                      │        │   │
│  │  │        describe_flow_io                     │        │   │
│  │  │                                            │        │   │
│  │  │  计划: propose_plan                         │        │   │
│  │  │                                            │        │   │
│  │  │  构建: build_flow (从Spec创建完整流程)        │        │   │
│  │  │        add_component                        │        │   │
│  │  │        remove_component                     │        │   │
│  │  │        connect_components                   │        │   │
│  │  │        configure_component                   │        │   │
│  │  │        propose_field_edit                    │        │   │
│  │  │                                            │        │   │
│  │  │  运行: run_flow                              │        │   │
│  │  │        generate_component                    │        │   │
│  │  └────────────────────────────────────────────┘        │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │           lfx 层 (独立可部署 CLI)                       │   │
│  │                                                       │   │
│  │  ┌─────────────┐  ┌────────────┐  ┌───────────────┐  │   │
│  │  │ graph/       │  │ graph/     │  │ graph/        │  │   │
│  │  │ flow_builder │  │ flow_builder│  │ flow_builder/ │  │   │
│  │  │ builder.py   │  │ spec.py    │  │ flow.py       │  │   │
│  │  │ (构建引擎)   │  │ (规格解析器)│  │ (空画布创建)   │  │   │
│  │  └─────────────┘  └────────────┘  └───────────────┘  │   │
│  │  ┌─────────────────────────────────────────────────┐  │   │
│  │  │  mcp/flow_builder_tools/                         │  │   │
│  │  │  ├── _state.py (请求级状态管理+SSE事件推送)      │  │   │
│  │  │  ├── read_tools.py (Search/Describe/GetField)     │  │   │
│  │  │  ├── edit_tools.py (ProposeFieldEdit)             │  │   │
│  │  │  ├── mutate_tools.py (Add/Remove/Connect/Configure)│  │   │
│  │  │  └── run_tools.py (Build/Run/ProposePlan/Generate) │  │   │
│  │  └────────────────────────────────────────────────┘  │   │
│  └───────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 分层说明

| 层 | 路径 | 职责 |
|----|------|------|
| **frontend** | `src/frontend/src/components/core/assistantPanel/` | 对话UI、SSE事件渲染、用户确认交互 |
| **agentic/api** | `src/backend/base/langflow/agentic/api/` | REST API 路由、请求解析 |
| **agentic/services** | `src/backend/base/langflow/agentic/services/` | 意图分类、执行编排、验证重试循环 |
| **flows** | `src/backend/base/langflow/agentic/flows/flow_builder_assistant.py` | FlowBuilderAssistant 流程定义、系统提示词 |
| **lfx/mcp** | `src/lfx/src/lfx/mcp/flow_builder_tools/` | MCP 工具实现（独立于 backend 可部署） |
| **lfx/graph** | `src/lfx/src/lfx/graph/flow_builder/` | 工作流规格解析、构建、布局 |

---

## 3. FlowBuilderAssistant 核心流程

### 3.1 流程定义

FlowBuilderAssistant 本身就是一个 Langflow 工作流，定义在 `flow_builder_assistant.py` 的 `get_graph()` 函数中：

```python
async def get_graph(provider, model_name, api_key_var) -> Graph:
    chat_input = ChatInput()
    tools = await build_toolkit()
    
    agent = AgentComponent()
    agent.set_input_value("model", build_model_config(provider, model_name))
    agent.set(
        input_value=chat_input.message_response,
        system_prompt=FLOW_BUILDER_PROMPT,   # ← 关键：系统提示词
        tools=tools,                          # ← 关键：12个MCP工具
        temperature=0.1,
    )
    
    chat_output = ChatOutput()
    chat_output.set(input_value=agent.message_response)
```

### 3.2 执行流程

```
用户输入 → 意图分类 → FlowBuilderAgent执行 → 验证 → 重试(最多3次) → 结果输出
```

**意图分类（TranslationFlow）** 在 `agentic/services/helpers/intent_classification.py` 中，将用户输入分为：

| 意图 | 说明 | Action |
|------|------|--------|
| `build_flow` | 用户要创建/构建工作流 | → FlowBuilderAssistant |
| `generate_component` | 用户要创建新组件 | → FlowBuilderAssistant |
| `manage_files` | 文件操作 | → FlowBuilderAssistant |
| `question` | 询问信息 | → FlowBuilderAssistant |
| `off_topic` | 非Langflow相关 | → 拒绝回复 |

### 3.3 重试循环

在 `assistant_service.py` 中实现了三层验证：

```
Layer 1: Security Scan (代码安全扫描)
Layer 2: Code Validation (语法+导入验证)
Layer 3: Runtime Validation (实际运行验证)
                  ↓
         Flow Verification (构建后验证运行)
```

- **组件生成重试**: 最多 `MAX_VALIDATION_RETRIES = 3` 次
- **工作流验证重试**: 最多 `MAX_FLOW_VALIDATION_ATTEMPTS = 3` 次
- **运行验证重试**: 最多 `MAX_FLOW_VERIFICATION_ATTEMPTS = 3` 次

每次验证失败时，错误信息被注入到 Agent 的上下文中，要求其修正后重试。

---

## 4. 工作流创建工具集详解

### 4.1 发现类工具

#### `SearchComponentTypes`
- **用途**: 按名称/类别搜索组件
- **无参数**: 列出所有组件
- **返回**: 匹配的组件类型列表

#### `DescribeComponentType`
- **用途**: 获取组件的输入、输出、字段定义
- **至关重要**: Agent 在生成边之前必须调用此工具，确保 `input_name` 和 `output_type` 精确匹配

#### `GetFieldValue`
- **用途**: 读取画布上指定组件的当前字段值
- **可选**: 不指定 field_name 时列出所有字段

#### `DescribeFlowIO`
- **用途**: 解析工作流的输入/输出组件
- **核心**: 计算工作流的真实输入/输出组件，避免 Agent 凭猜测操作

### 4.2 计划类工具

#### `ProposePlan`
- **用途**: 向用户展示一个 Markdown 计划并等待确认
- **事件**: `propose_plan` → 前端渲染 Continue/Dismiss 卡片
- **使用时机**: 仅当请求模糊或涉及破坏性替换时才使用。明确的请求直接执行

### 4.3 构建类工具

#### `BuildFlowFromSpec`（核心中的核心）
- **用途**: 从文本规格字符串创建完整工作流
- **⚠️ 警告**: 替换整个画布
- **工作流**: 解析 Spec → 加载组件注册表 → 添加所有组件 → 配置参数 → 连接边 → 自动布局 → 前端预览
- **验证**: 自动检测孤立节点（无边连接的组件）

#### `AddComponent`
- **用途**: 向画布添加单个组件

#### `RemoveComponent`
- **用途**: 从画布移除指定组件

#### `ConnectComponents`
- **用途**: 连接两个组件的端口

#### `ConfigureComponent`
- **用途**: 设置组件的参数（接受 JSON dict 批量设置）

#### `ProposeFieldEdit`
- **用途**: 提议修改字段值（用户会看到 diff 卡片并接受/拒绝）
- **与 ConfigureComponent 的区别**: 这个操作需要用户审查，`ConfigureComponent` 是即时生效的

### 4.4 运行类工具

#### `RunFlow`
- **用途**: 执行当前画布工作流并返回结果
- **模型注入**: 运行时自动将助手已验证的模型注入到 Agent 节点
  - 用户显式指定模型 → 强制覆盖（`overwrite_existing_model=True`）
  - 未指定 → 仅填充空白模型（保留已有设置）

#### `GenerateComponent`
- **用途**: 创建全新的自定义 Langflow 组件
- **流程**: LLM 生成代码 → Security Scan → 代码+运行时验证（最多3次重试）→ 注册到用户作用域

### 4.5 文件系统工具

由 `FileSystemToolComponent` 提供，每个工具有独立沙箱（按用户 ID 隔离）：
- `read_file` - 读取沙箱文件
- `write_file` - 写入沙箱文件
- `edit_file` - 替换文件中精确子串
- `glob_search` - 按 glob 模式搜索文件
- `grep_search` - 搜索文件内容

---

## 5. 工作流规格格式（Flow Spec）

这是 **`BuildFlowFromSpec` 工具的核心输入格式**，也是 Agent 与工作流构建引擎之间的接口协议。

### 5.1 文本规格格式

定义在 `src/lfx/src/lfx/graph/flow_builder/spec.py` 的 `parse_flow_spec()` 中：

```
name: 工作流名称
description: 工作流描述

nodes:
  A: ChatInput
  B: Agent
  C: ChatOutput

edges:
  A.message -> B.input_value
  B.response -> C.input_value

config:
  B.system_prompt: |
    You are a helpful assistant.
    Multi-line values use pipe syntax.
  B.temperature: 0.1
  C.sender: Machine
```

### 5.2 解析规则

| 元素 | 格式 | 示例 |
|------|------|------|
| **name** | `name: <string>` | `name: My Flow` |
| **description** | `description: <string>` | `description: A chatbot` |
| **nodes** | `<ID>: <ComponentType>` | `A: ChatInput` |
| **edges** | `<ID>.<output> -> <ID>.<input>` | `A.message -> B.input_value` |
| **config** | `<ID>.<field>: <value>` | `B.temperature: 0.5` |

**值自动类型转换**:
- 数字字符串 → `int`/`float`
- `true`/`false` → `bool`
- `null`/`none` → `None`
- `|` 后接多行内容 → 字符串（保留缩进）

### 5.3 解析后的结构

```python
{
    "name": "My Flow",
    "description": "A chatbot",
    "nodes": [
        {"id": "A", "type": "ChatInput"},
        {"id": "B", "type": "Agent"},
        {"id": "C", "type": "ChatOutput"},
    ],
    "edges": [
        {"source_id": "A", "source_output": "message",
         "target_id": "B", "target_input": "input_value"},
        {"source_id": "B", "source_output": "response",
         "target_id": "C", "target_input": "input_value"},
    ],
    "config": {
        "B": {"system_prompt": "You are...\n", "temperature": 0.1},
        "C": {"sender": "Machine"},
    }
}
```

---

## 6. 工作流 JSON 文件 Schema

这是 Langflow 工作流文件的完整 JSON 格式。这个结构是 **语言无关的**——任何 agent 只要按照此 Schema 生成 JSON，即可被 Langflow 直接加载。

### 6.1 顶层结构

```json
{
    "data": {
        "nodes": [...],
        "edges": [...],
        "viewport": {"x": 0, "y": 0, "zoom": 1}
    },
    "description": "工作流描述",
    "endpoint_name": "endpoint-name",
    "id": "uuid-string",
    "is_component": false,
    "last_tested_version": "1.10.2",
    "name": "工作流名称",
    "tags": ["tag1", "tag2"]
}
```

### 6.2 节点结构（Node）

```json
{
    "data": {
        "description": "组件描述",
        "display_name": "显示名称",
        "id": "Component-uuid",
        "node": {
            "base_classes": ["BaseClass"],
            "custom_fields": {},
            "description": "详细描述",
            "display_name": "显示名称",
            "documentation": "",
            "edited": false,
            "field_order": ["input_value"],
            "flow": {"edges": [], "nodes": []},
            "icon": "图标名",
            "icon_bg_color": "",
            "method": "message_response",
            "output_types": [],
            "outputs": [
                {
                    "name": "message",
                    "display_name": "Message",
                    "types": ["Message"],
                    "method": "message_response"
                }
            ],
            "template": {
                "input_value": {
                    "advanced": false,
                    "display_name": "Input Value",
                    "dynamic": false,
                    "info": "信息文本",
                    "input_types": ["Message", "Text"],
                    "list": false,
                    "load_from_db": false,
                    "multiline": true,
                    "placeholder": "",
                    "required": false,
                    "show": true,
                    "title_case": false,
                    "trace_as_input": true,
                    "type": "code",
                    "value": ""
                }
            },
            "tool_mode": false,
            "type": "ChatInput"
        },
        "selected_output": "message",
        "type": "ChatInput"
    },
    "dragging": false,
    "height": 0,
    "id": "Component-uuid",
    "measured": {"width": 384, "height": 484},
    "position": {"x": 100, "y": 200},
    "positionAbsolute": {"x": 100, "y": 200},
    "selected": false,
    "type": "genericNode",
    "width": 384
}
```

### 6.3 边结构（Edge）

```json
{
    "animated": true,
    "className": "",
    "data": {
        "sourceHandle": {
            "base_classes": ["Message"],
            "name": "message",
            "output_types": ["Message"]
        },
        "targetHandle": {
            "fieldName": "input_value",
            "inputTypes": ["Message", "Text"],
            "type": "str"
        }
    },
    "id": "reactflow__edge-{source_id}message-{target_id}input_value",
    "selected": false,
    "source": "{source_node_id}",
    "sourceHandle": "{source_node_id}-message-right",
    "target": "{target_node_id}",
    "targetHandle": "{target_node_id}-input_value-left"
}
```

### 6.4 核心字段说明

| 字段 | 路径 | 说明 |
|------|------|------|
| `type` | `data.type` | 组件类型标识（如 `ChatInput`, `Agent`） |
| `display_name` | `data.display_name` | 画布上显示的组件名称 |
| `id` | `data.id`/顶层`id` | 组件唯一标识（UUID） |
| `node.template` | `data.node.template` | 所有可配置字段的定义 |
| `position` | `position` | 画布坐标 `{x, y}` |

---

## 7. 助手系统提示词（FLOW_BUILDER_PROMPT）

定义在 `flow_builder_assistant.py` 中，是整个流程的**行为契约**。核心要点：

### 7.1 角色定义

> "You are a Langflow Flow Builder assistant. You build and modify flows directly on the user's canvas."

### 7.2 决策规则（核心行为约束）

| 规则 | 内容 |
|------|------|
| **Act, do not ask** | 用户已要求的事，直接执行。不要问"要不要我继续" |
| **Never claim without doing** | 只有实际调用了工具，才能说操作已执行 |
| **BUILD vs EDIT** | 用户说"创建/构建" → BUILD模式；"更改/添加/移除" → EDIT模式 |
| **1次运行原则** | `run_flow` 每个请求只调一次，不循环运行 |
| **语言匹配** | 用用户消息的语言回复 |

### 7.3 连接规则（防止损坏的工作流）

```
- 每个添加的组件必须有至少一条边连接（禁止孤立组件）
- tools 输入只接受 component_as_tool 类型的输出
- Agent 有内置模型选择器，不需要额外添加模型组件
- 所有组件添加前必须调用 describe_component 确认端口名
```

### 7.4 模型选择优先级

```
1. 用户显式指定的模型 → 强制使用（即使有"preferred"模型）
2. 用户未指定 → 使用上下文中的 preferred 模型
3. 无 preferred → 任选一个有凭据的 provider
4. 兜底 → OpenAI gpt-4o-mini
```

---

## 8. 意图识别与路由

### 8.1 TranslationFlow

定义在 `agentic/flows/translation_flow.py`。它是一个轻量级 LLM 调用，将用户输入翻译为结构化指令：

```python
class IntentResult:
    translation: str       # 翻译后的指令
    intent: str            # generate_component / build_flow / manage_files / question / off_topic
    requested_model: str | None  # 用户显式指定的模型
    requested_provider: str | None
```

### 8.2 输入处理

```python
# assistant_service.py 中：
# 1. 空输入或者 EDIT_CONTINUATION_INPUT → 直接跳过量分类
# 2. 正常输入 → sanitize_input → classify_intent
# 3. 敏感/拒绝内容 → REFUSAL_MESSAGE
# 4. off_topic → OFF_TOPIC_REFUSAL_MESSAGE
```

### 8.3 会话缓冲

`conversation_buffer.py` 管理助手的对话历史，控制上下文窗口大小（不超过 `MAX_CANVAS_SUMMARY_CHARS = 2000` 字符）。

---

## 9. 验证与重试机制

### 9.1 组件生成验证

`agentic/helpers/validation.py` 中的多层验证：

```
代码提取 → 安全扫描(scan_code_security)
                  ↓
           语法验证(compile + AST)
                  ↓
           导入验证(所有import可解析)
                  ↓
           运行时验证(实例化组件类)
                  ↓
           注册到用户作用域(可用自定义组件)
```

### 9.2 工作流验证

```python
# 在 assistant_service.py 中的 execute_flow_with_validation()
MAX_FLOW_VALIDATION_ATTEMPTS = 3   # 静态验证重试
MAX_FLOW_VERIFICATION_ATTEMPTS = 3 # 运行验证重试
```

1. **静态验证**（`flow_static_validation.py`） — 检查图结构、连接完整性
2. **构建验证**（`flow_graph_build_check.py`） — 检查图的可执行性
3. **运行验证**（`flow_verification.py`） — 实际执行工作流，验证能否跑通

### 9.3 错误重试模板

```python
NO_ACTION_RETRY_TEMPLATE = """
Your previous reply did not change the canvas. You only described
what you would do...
ORIGINAL REQUEST: {original_input}
Do it NOW by calling the canvas tools...
"""

FLOW_VERIFICATION_RETRY_TEMPLATE = """
The flow you just built was executed to verify it works,
but the run FAILED with this error: {error}
Fix the flow so it runs end to end...
"""
```

---

## 10. 前端交互流程

### 10.1 对话面板

`assistant-panel.tsx` 是 React 组件，提供：
- 对话消息列表（`AssistantMessageItem`）
- 输入框（`AssistantInput`）
- SSE 事件渲染（实时更新画布）
- 确认/拒绝按钮（Plan 卡片、Flow 预览、Edit Diff 卡片）

### 10.2 SSE 事件流

| 事件 | 说明 |
|------|------|
| `propose_plan` | Agent 提交计划 → 前端显示 Continue/Dismiss |
| `set_flow` | 设置/替换画布工作流 |
| `add_component` | 添加组件到画布 |
| `remove_component` | 从画布移除组件 |
| `connect_components` | 连接两个组件 |
| `configure_component` | 配置组件参数 |
| `flow_ran` | 工作流运行完成 |
| `file_written` | 文件写入成功 |
| `component_generated` | 组件生成成功 |

### 10.3 欢迎弹窗

`flowBuilderWelcomeStore.ts` 管理新工作流的欢迎弹窗：
- 新画布打开时显示
- 用户在输入框中输入自然语言描述
- 提交后助理面板自动打开，消息传递过去

### 10.4 前端 API

```typescript
// useGetTemplateAssistantQuery: POST /api/v1/run/TemplateAssistant
// 全局变量通过 HTTP Headers 传递：
//   X-Langflow-Global-Var-COMPONENT_ID
//   X-Langflow-Global-Var-FLOW_ID
//   X-Langflow-Global-Var-FIELD_NAME
```

---

## 11. 组件注册表机制

### 11.1 本地注册表

`builder.py` 中的 `load_local_registry()` 加载 `lfx/_assets/component_index.json`：

```python
# 从 JSON 文件中读取所有组件模板
# 格式: { "component_type": { "template": {...}, "category": "..." } }
# 缓存到全局变量 _registry_cache，仅加载一次
```

### 11.2 用户作用域注册表

`agentic/services/user_components.py` 管理用户自定义组件：
- 通过 `GenerateComponent` 生成的组件注册到此
- 按用户 ID 隔离（`user_components_overlay.py`）
- `_load_registry_user_aware()` 合并基础注册表 + 用户自定义组件

---

## 12. 典型工作流创建全流程

### 12.1 从空白画板开始

```
1. 用户: "帮我创建一个客服聊天机器人，使用OpenAI"

2. 意图分类 → intent=build_flow

3. Agent 搜索:
   search_components("Chat")     → ChatInput, ChatOutput
   search_components("Agent")    → Agent
   describe_component("Agent")   → 输入: input_value, system_prompt, tools, ...
                                → 输出: response

4. Agent 构建工作流:
   build_flow(spec="""
     name: 客服聊天机器人
     nodes:
       A: ChatInput
       B: Agent
       C: ChatOutput
     edges:
       A.message -> B.input_value
       B.response -> C.input_value
     config:
       B.system_prompt: |
         你是一个友好的客服助手。
       B.model: [{"provider": "OpenAI", "name": "gpt-4o"}]
   """)

5. 前端: 显示工作流预览 → 用户确认 → 画布更新
```

### 12.2 增量编辑

```
1. 用户: "把模型改成 gpt-4o-mini，温度设为 0.3"

2. Agent 查找组件:
   get_field_value("Agent-uuid")  → 列出现有字段

3. Agent 执行:
   configure_component("Agent-uuid", params='{"model": [{"provider":"OpenAI","name":"gpt-4o-mini"}], "temperature": 0.3}')

4. 用户要求运行:
   run_flow(reason="验证温度更改")
```

### 12.3 自定义组件

```
1. 用户: "创建一个可以计算两个数字之和的组件"

2. Agent:
   generate_component(spec="一个输入两个数字并返回它们之和的组件")

3. 验证组件:
   Security Scan → Code Validation → Runtime Validation

4. 注册组件:
   Agent 收到生成成功 → 搜索新组件类名 → 加入工作流
```

---

## 13. 附录：关键源码位置

### 13.1 代码索引

| 功能 | 路径 | 关键文件 |
|------|------|----------|
| 助手流程定义 | `backend/base/langflow/agentic/flows/` | `flow_builder_assistant.py` |
| 助手流程提示词 | 同上 | `FLOW_BUILDER_PROMPT` 字符串（~250行） |
| 助手服务编排 | `backend/base/langflow/agentic/services/` | `assistant_service.py`（1400+行）|
| 流程类型常量 | 同上 | `flow_types.py` |
| 流程执行器 | 同上 | `flow_executor.py`, `flow_run.py` |
| 意图分类 | `agentic/services/helpers/` | `intent_classification.py` |
| 组件验证 | `agentic/services/helpers/` | `validation.py` |
| 工作流验证 | `agentic/services/` | `flow_verification.py` |
| 前端面板 | `frontend/src/components/core/assistantPanel/` | `assistant-panel.tsx` |
| 前端欢迎弹窗 | `frontend/src/stores/` | `flowBuilderWelcomeStore.ts` |
| MCP 工具总入口 | `lfx/src/lfx/mcp/flow_builder_tools/` | `__init__.py` |
| 构建工具 | 同上 | `run_tools.py`, `mutate_tools.py` |
| 读取工具 | 同上 | `read_tools.py` |
| 编辑工具 | 同上 | `edit_tools.py` |
| 状态管理 | 同上 | `_state.py` |
| 规格解析器 | `lfx/src/lfx/graph/flow_builder/` | `spec.py` |
| 构建引擎 | 同上 | `builder.py` |
| 工作流结构 | 同上 | `flow.py` |
| 组件添加 | 同上 | `component.py` |
| 连接管理 | 同上 | `connect.py` |
| 自动布局 | 同上 | `layout.py` |
| 注册表 | `lfx/src/lfx/_assets/` | `component_index.json` |

### 13.2 语言与框架

| 层 | 语言/框架 | 包管理 |
|----|-----------|--------|
| 后端 | Python 3.10+ / FastAPI | uv (pip) |
|   ├ agentic | Python / asyncio | langflow-base (venv) |
|   └ lfx | Python / CLI (Typer) | lfx (venv) |
| 前端 | TypeScript / React / Vite | npm |
| 工作流运行时 | Python / LangGraph | langgraph-checkpoint |
| 状态管理 | Python ContextVar / 前端 Zustand | - |

---

> **注意**: 本报告基于 Langflow v1.10.2 源码分析。后续版本可能存在差异。
> 如需生成 Langflow 工作流 JSON 文件，请参考第 6 节的 Schema 定义。
