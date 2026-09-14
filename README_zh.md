<p align="center">
  <a href="README.md">English</a> ·
  <strong>中文</strong>
</p>

<p align="center">
  <strong>开源红队多智能体协作平台 · 内置 Cairn 风格共享推理黑板</strong>
</p>

<p align="center">
  <a href="#概述">概述</a> ·
  <a href="#架构">架构</a> ·
  <a href="#黑板">黑板</a> ·
  <a href="#快速开始">快速开始</a>
</p>

---

> **安全声明**
>
> 本项目仅限在合法且获得明确授权的范围内用于安全测试、风险评估和学术研究。
> 严禁用于任何未经授权的系统、网络或数据。
> **作者不对使用者造成的任何后果或损失负责。**

---

## 概述

玄幕红队智能体（XuanMu）是一个**面向红队协作的控制平面型多智能体平台**，适用于授权渗透测试、漏洞挖掘、代码审计与安全研究。

它将以下能力整合在一个平台中：
- **React 操作台**（Playground 对话 + 项目工作区）
- **FastAPI 控制平面**（REST + WebSocket）
- **会话级多智能体运行时**（主管 + 5 个专家智能体）
- **结构化证据平面**（资产、发现、关系图、攻击路径）
- **共享推理黑板**（Cairn 风格的 Fact-Intent 图，实现智能体间接协调）

设计目标是让智能体辅助的安全工作**边界清晰、完全可复核**。对话不是唯一事实来源——项目范围、资产、漏洞发现、关系图、攻击路径、可回放时间线，以及**智能体的推理过程**，都作为显式应用数据持久化管理。

---

## 架构

```
                     ┌─────────────────────────────────────┐
                     │         React 操作台                 │
                     │    Playground · 项目工作区           │
                     └──────────────┬──────────────────────┘
                                    │ REST + WebSocket
                     ┌──────────────▼──────────────────────┐
                     │        FastAPI 控制平面               │
                     │   系统 · 用户 · 智能体 · 项目         │
                     └──────────────┬──────────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         │                          │                          │
   ┌─────▼──────┐           ┌───────▼───────┐          ┌──────▼──────┐
   │ 智能体     │           │   共享黑板     │          │  证据平面    │
   │ 运行时     │◄──────────►   推理图       │          │  资产       │
   │ 会话 +     │  读写     │   Fact/Intent │          │  发现       │
   │ 委派      │           │   /Hint       │          │  关系边     │
   │ CSO + 5   │           │               │          │  攻击路径   │
   │ 专家      │           │               │          │             │
   └─────┬──────┘           └───────────────┘          └──────┬──────┘
         │                                                    │
         └──────────────────────┬─────────────────────────────┘
                                │
                     ┌──────────▼──────────┐
                     │      PostgreSQL     │
                     └─────────────────────┘
```

### 智能体团队

| 代号 | 名称 | 角色 |
|------|------|------|
| `cso` | 玄幕 (XuanMu) | 安全主管 — 任务分解、团队协调、推理 |
| `cae` | 守拙 (ShouZhuo) | 代码审计专家 |
| `cie` | 观星 (GuanXing) | 情报侦察专家 |
| `cpe` | 破军 (PoJun) | 渗透测试专家 |
| `cre` | 溯源 (SuYuan) | 逆向分析专家 |
| `cce` | 破阵 (PoZhen) | 密码分析专家 |

### 执行层

命令通过 Python asyncio 子进程在宿主机上直接执行——**无需 Docker**。执行层支持：

- 同步命令执行（带超时控制）
- 后台异步任务（完成后通知恢复智能体）
- 输出文件按行范围读取
- 技能系统（`.xuanmu/agents/skills/` 中的可复用工具定义）
- 知识库（结构化方法论文档）

---

## 黑板

黑板是本平台的核心特色，受 [Cairn](https://github.com/oritera/Cairn) 的 Fact-Intent 图启发实现。它提供 **Stigmergy（间接协调）** 机制——所有智能体通过读写同一张黑板来共享信息，而不是互相喊话打断。

### 节点类型

| 类型 | 含义 | 生命周期 |
|------|------|---------|
| **Fact** | 已确认的客观发现 | proposed → confirmed / rejected |
| **Intent** | 声明的探索方向 | proposed → in_progress → confirmed / rejected / superseded |
| **Hint** | 人类或智能体注入的指引 | 持久存在 |

### 智能体工作流

```
1. read_blackboard()    — 看全貌
2. create_intent()      — 动手前先声明方向
3. [执行探索工具]
4. create_fact()        — 记录发现，链接到对应的 Intent
5. update_node_status() — 此路不通则标 rejected
```

黑板层与证据平面（Asset / Finding / GraphEdge）互补：证据层记录**「发现了什么」**，黑板层记录**「为什么查、查到什么、下一步查什么」**。

### REST API

| 端点 | 方法 | 说明 |
|------|------|------|
| `GET /api/blackboard/{project_id}` | 查询 | 获取完整推理图快照 |
| `POST /api/blackboard/{project_id}/nodes` | 创建 | 新建 Fact / Intent / Hint |
| `PUT /api/blackboard/{project_id}/nodes/{node_id}` | 更新 | 修改状态或内容 |
| `DELETE /api/blackboard/{project_id}/nodes/{node_id}` | 删除 | 删除节点 |

---

## 技术亮点

| 特性 | 说明 |
|------|------|
| 多智能体编排 | 主管协调专家，通过委派 + 黑板实现协作 |
| 结构化证据平面 | 资产、发现、关系图、攻击路径全部持久化 |
| 共享推理黑板 | Cairn 风格 Fact-Intent 图，让推理过程可追溯 |
| 可回放时间线 | 标准化事件流，可实时查看或后期回放 |
| 无需 Docker | 本地模式下命令通过 asyncio 子进程直接在宿主机运行 |
| Docker 一键部署 | 支持 macOS / Linux / Windows，一条命令完成全部部署 |
| 知识库 | 结构化的安全方法论文档，智能体可查阅 |
| 全功能 Web UI | 对话操作台 + 项目工作区，含图可视化 |
| 国产 LLM 友好 | 直接 API 调用，支持 DeepSeek / Qwen / GLM 等 |

---

## 快速开始

> 📖 **首次使用？请先阅读 [使用入门手册](GUIDE_zh.md)**，包含从安装到实战的完整指引。

### 方式一：Docker 部署（推荐）

Docker 部署是最简单的方式，支持 **macOS / Linux / Windows** 三大平台。只需安装 Docker，无需手动配置 Python、Node.js 或 PostgreSQL。

#### 环境要求

| 项目 | 要求 |
|------|------|
| Docker | Docker Desktop（macOS/Windows）或 Docker Engine（Linux） |
| 磁盘 | 至少 4GB 可用空间 |
| 内存 | 建议 4GB+ |

#### 一键部署

```bash
git clone https://github.com/err0rr0/XuanMu.git
cd XuanMu
bash docker-setup.sh
```

脚本会自动完成：
1. 检测系统环境和 Docker 是否就绪
2. 生成 `.env`（端口和数据库配置）
3. 生成 `.xuanmu/config.json`（自动适配 Docker 网络）
4. 交互式引导配置 LLM API Key
5. 构建镜像并启动所有服务

部署成功后访问 **http://localhost:8000**，默认管理员账号 `admin@xuanmu.local` / `admin123`。

#### 常用命令

```bash
bash docker-setup.sh start     # 启动服务
bash docker-setup.sh stop      # 停止服务
bash docker-setup.sh restart   # 重启服务
bash docker-setup.sh status    # 查看容器状态
bash docker-setup.sh logs      # 查看实时日志
bash docker-setup.sh clean     # 停止并清理所有数据（慎用）
```

#### 自定义端口

8000 端口被占了？只需改 `.env` 一个文件：

```bash
# 编辑 .env，把 XUANMU_PORT 改成你想要的端口
vi .env
# XUANMU_PORT=9000

# 重启服务即可生效
bash docker-setup.sh stop
bash docker-setup.sh start
```

数据库密码同理，改 `.env` 中的 `POSTGRES_PASSWORD` 即可（首次部署前改；已部署的需要先 `clean` 再重建）。

#### Windows 用户说明

Windows 用户需要先安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/)，然后通过以下任一方式运行脚本：

- **Git Bash**（安装 Git for Windows 后自带）：直接运行 `bash docker-setup.sh`
- **WSL 2**（推荐）：在 WSL 终端中克隆仓库并运行
- **PowerShell**：直接运行 `bash docker-setup.sh`（需要 Git Bash 在 PATH 中）

---

### 方式二：本地安装（Linux）

适用于需要直接在宿主机运行的场景（如 Kali Linux 渗透测试环境）。

#### 环境要求

- **Linux**（推荐 Kali / Debian）
- **Python >= 3.12**
- **PostgreSQL**（安装脚本会自动安装）
- **Node.js >= 18**（用于构建前端）

#### 安装

```bash
git clone https://github.com/err0rr0/XuanMu.git
cd XuanMu
bash setup.sh
```

#### 配置 LLM

```bash
vi .xuanmu/config.json
```

填入每个智能体角色的 API Key、接口地址和模型名。
示例默认使用 DeepSeek —— 支持任何 OpenAI 兼容接口。

也可以使用交互式配置工具：

```bash
bash config-tool.sh
```

#### 启动

```bash
bash start.sh
```

打开浏览器访问 **http://localhost:8000**，登录账号 `admin@admin.com` / `admin123`。

---

## 仓库结构

```
core/           智能体规格、运行时、委派、上下文、工具
service/        领域服务（智能体、用户、项目、黑板）
router/         FastAPI 路由声明
handler/        HTTP 和 WebSocket 请求处理
model/          SQLModel 数据库模型
schema/         Pydantic API 契约
blackboard/     共享推理黑板模块
  model/        数据库模型
  schema/       API 契约
  service/      业务逻辑
  handler/      HTTP 处理
  router/       API 路由
web/            React 前端（操作台 + 管理后台）
.xuanmu/        运行时配置、智能体提示词、知识文件
```

---

## 许可证

本项目基于 [MIT 许可证](LICENSE) 开源。

---

## 致谢

- [Cairn](https://github.com/oritera/Cairn) — 基于事实-意图图的协作探索协议，黑板架构的灵感来源
- [Z3r0](https://github.com/yv1ing/Z3r0) — 本项目最初 fork 的开源红队协作工作台
