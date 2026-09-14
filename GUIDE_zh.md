# 玄幕红队智能体 — 使用入门手册

> 版本：v0.2.1（黑板架构版）

---

## 目录

1. [快速安装](#quick-install)
   - [Docker 部署（推荐）](#docker-deploy)
   - [本地安装（Linux）](#local-install)
2. [配置 LLM](#configure-llm)
3. [启动与登录](#start--login)
4. [创建你的第一个项目](#create-project)
5. [使用 Playground 对话](#playground)
6. [理解智能体团队](#agent-team)
7. [使用黑板（Blackboard）](#blackboard)
8. [使用自定义技能（Skills）](#custom-skills)
9. [理解证据平面](#evidence-plane)
10. [常见问题](#faq)

---

<a id="quick-install"></a>
## 1. 快速安装 / Quick Install

XuanMu 提供两种安装方式。**Docker 部署**是推荐方式，支持 macOS / Linux / Windows 三大平台，无需手动安装依赖；**本地安装**适用于需要在 Kali Linux 等环境直接运行的场景。

---

<a id="docker-deploy"></a>
### 方式一：Docker 部署（推荐）

Docker 方式将应用、数据库全部打包在容器中，一条命令完成部署。

#### 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | macOS / Linux / Windows（任一） |
| Docker | Docker Desktop（macOS/Windows）或 Docker Engine（Linux） |
| 磁盘 | 至少 4GB 可用空间 |
| 内存 | 建议 4GB+ |

#### 安装 Docker

如果你还没有安装 Docker：

| 平台 | 安装方式 |
|------|---------|
| **macOS** | 下载 [Docker Desktop](https://www.docker.com/products/docker-desktop/)，或 `brew install --cask docker` |
| **Windows** | 下载 [Docker Desktop](https://www.docker.com/products/docker-desktop/)，确保启用 WSL 2 后端 |
| **Linux** | `curl -fsSL https://get.docker.com \| sh && sudo usermod -aG docker $USER`（注销重新登录） |

安装后确认 Docker 已启动：

```bash
docker --version
docker compose version
```

#### 一键部署

```bash
# 克隆仓库
git clone https://github.com/err0rr0/XuanMu.git
cd XuanMu

# 运行 Docker 部署脚本
bash docker-setup.sh
```

脚本会自动完成以下步骤：

1. 检测操作系统和 Docker 环境
2. 生成 `.env` 文件（端口和数据库配置）
3. 生成 `.xuanmu/config.json`（自动适配 Docker 内部网络）
4. 交互式引导配置 LLM API Key（也可跳过，稍后手动配置）
5. 构建 Docker 镜像并启动所有服务

首次构建大约需要 5-15 分钟（取决于网络速度），后续启动只需几秒。

部署成功后你会看到：

```
  XuanMu 部署成功！

  Web 界面:    http://localhost:8000
  API 文档:    http://localhost:8000/docs
  管理员登录:  admin@xuanmu.local / admin123
```

#### 常用运维命令

```bash
bash docker-setup.sh start     # 启动服务
bash docker-setup.sh stop      # 停止服务
bash docker-setup.sh restart   # 重启服务
bash docker-setup.sh status    # 查看容器状态
bash docker-setup.sh logs      # 查看实时日志（Ctrl+C 退出）
bash docker-setup.sh clean     # 停止并清理所有数据（数据库会被删除！）
```

#### Windows 用户注意事项

Windows 用户需要通过以下任一终端运行脚本：

- **Git Bash**（推荐，安装 [Git for Windows](https://git-scm.com/download/win) 后自带）
- **WSL 2 终端**（推荐，Windows 子系统 Linux）
- **PowerShell**（需要 Git Bash 在系统 PATH 中）

在 Git Bash 或 WSL 中操作和 macOS / Linux 完全一致：

```bash
git clone https://github.com/err0rr0/XuanMu.git
cd XuanMu
bash docker-setup.sh
```

#### Docker 部署文件说明

| 文件 | 用途 |
|------|------|
| `docker-setup.sh` | 一键部署 + 运维管理脚本 |
| `docker-compose.prod.yml` | Docker Compose 编排定义 |
| `.env.example` | 环境变量模板（复制为 `.env` 使用） |
| `.env` | 实际环境变量（含密码，不提交 Git） |
| `Dockerfile` | 应用镜像构建定义 |
| `.xuanmu/config.json` | 应用配置（含 LLM API Key） |

> 💡 Docker 模式下，端口和数据库配置通过 `.env` 文件管理，环境变量会自动覆盖 `config.json` 中的对应字段。你不需要手动同步两边的配置。

#### 自定义端口和数据库

所有可配置项集中在 `.env` 一个文件中，改完重启即可生效：

```bash
vi .env
```

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `XUANMU_PORT` | Web 访问端口 | `8000` |
| `POSTGRES_PORT` | PostgreSQL 外部端口（调试用） | `5400` |
| `POSTGRES_USER` | 数据库用户名 | `root` |
| `POSTGRES_PASSWORD` | 数据库密码 | `xuanmu2025` |
| `POSTGRES_DB` | 数据库名 | `z3r0` |

**改端口示例：**

```bash
# 把 8000 改成 9000
sed -i 's/XUANMU_PORT=8000/XUANMU_PORT=9000/' .env

# 重启服务（不需要重新构建镜像）
bash docker-setup.sh stop
bash docker-setup.sh start
```

> 改数据库密码注意：如果已经启动过（数据卷已创建），需要先 `bash docker-setup.sh clean` 清除旧数据卷，再重新部署。PostgreSQL 只在首次初始化时读取密码。

---

<a id="local-install"></a>
### 方式二：本地安装（Linux）

适用于需要在宿主机直接运行的场景（如 Kali Linux 渗透测试环境）。

#### 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | **Linux**（推荐 Kali Linux / Debian 12） |
| Python | >= 3.12 |
| Node.js | >= 18（前端构建需要） |
| PostgreSQL | 安装脚本会自动安装 |
| 硬盘 | 至少 2GB 可用空间 |

#### 一键安装

```bash
# 克隆仓库
git clone https://github.com/err0rr0/XuanMu.git
cd XuanMu

# 运行安装脚本
bash setup.sh
```

安装过程大约 3-10 分钟（取决于网络速度），脚本会自动：

1. 安装系统依赖（包括 PostgreSQL、Node.js）
2. 创建 PostgreSQL 数据库和用户
3. 创建 Python 虚拟环境并安装后端依赖
4. 构建前端界面
5. 检查安装结果
6. 创建便捷的 `start.sh` 和 `stop.sh` 脚本

> 安装脚本需要 `sudo` 权限来安装系统包和配置 PostgreSQL。
> 建议在**干净的虚拟机或专用机器**上运行。

安装成功后你会看到：

```
[OK] 安装完成
[..] 创建便捷脚本...
[OK] 便捷脚本已创建
```

---

<a id="configure-llm"></a>
## 2. 配置 LLM / Configure LLM

安装完成后，需要配置 LLM API 才能让智能体工作。

> 如果你使用 Docker 部署并在 `docker-setup.sh` 中已完成了 API Key 配置，可以跳过此步。

### 方式一：交互式配置（本地安装推荐）

```bash
bash config-tool.sh
```

按照提示一步步输入：
1. 选择要配置的角色（或「全部角色统一设置」）
2. 输入 API Key
3. 输入 API 地址（默认 `https://api.deepseek.com/v1`）
4. 输入模型名（默认 `deepseek-chat`）

### 方式二：手动编辑 JSON

```bash
vi .xuanmu/config.json
```

配置文件结构如下：

```json
{
  "agents": {
    "cso": {
      "name": "XuanMu",
      "base_url": "https://api.deepseek.com/v1",
      "api_key": "sk-你的API密钥",
      "model": "deepseek-chat"
    },
    "cae": { "...相同结构..." },
    "cie": { "...相同结构..." },
    "cpe": { "...相同结构..." },
    "cre": { "...相同结构..." },
    "cce": { "...相同结构..." }
  }
}
```

> 💡 **提示**：
> - 所有角色可以用同一个 API Key 和模型
> - 也可以为不同角色配置不同的模型
> - 支持任何 OpenAI 兼容的 API（DeepSeek / Qwen / GLM / Kimi 等）

### 支持的服务商

| 服务商 | API 地址 | 推荐模型 |
|--------|----------|----------|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| 阿里通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| 智谱 GLM | `https://open.bigmodel.cn/api/paas/v4` | `glm-4-plus` |
| 月之暗面 Kimi | `https://api.moonshot.cn/v1` | `moonshot-v1-8k` |

---

<a id="start--login"></a>
## 3. 启动与登录 / Start & Login

### Docker 部署方式

```bash
# 启动
bash docker-setup.sh start

# 停止
bash docker-setup.sh stop

# 查看日志
bash docker-setup.sh logs
```

### 本地安装方式

#### 启动

```bash
bash start.sh
```

启动成功后会显示：

```
Backend started on http://localhost:8000
Frontend built
```

#### 停止

```bash
bash stop.sh
```

### 登录

打开浏览器访问 **http://localhost:8000**

默认管理员账号：

| 字段 | Docker 部署 | 本地安装 |
|------|------------|---------|
| 邮箱 | `admin@xuanmu.local` | `admin@admin.com` |
| 密码 | `admin123` | `admin123` |

> ⚠️ **首次使用请立即修改默认密码！**
> 点击左侧「系统管理」→「用户管理」修改密码。

---

<a id="create-project"></a>
## 4. 创建你的第一个项目 / Create Project

项目（WorkProject）是 XuanMu 的核心组织单位——所有资产、发现、推理过程都归属于一个项目。

### 操作步骤

1. 登录后在左侧导航栏点击 **「项目管理」**
2. 点击右上角 **「创建项目」**
3. 填写项目信息：

| 字段 | 说明 | 示例 |
|------|------|------|
| 项目名称 | 简短标识 | `内部渗透测试` |
| 项目描述 | 目标范围说明 | `对 10.0.0.0/24 内网进行渗透测试` |
| 项目类型 | `渗透测试` 或 `代码审计` | 渗透测试 |
| 资产列表 | 初始目标（可后续添加） | `10.0.0.1`, `10.0.0.2` |

4. 点击 **「创建」**

### 项目状态

| 状态 | 含义 |
|------|------|
| `working` | 进行中 — 智能体正在工作 |
| `completed` | 已完成 — 目标达成 |
| `canceled` | 已取消 — 手动中止 |

---

<a id="playground"></a>
## 5. 使用 Playground 对话 / Playground

Playground 是你与智能体团队交互的主要界面。

### 开始对话

1. 点击左侧 **「Playground」**
2. 在页面顶部选择或创建一个 WorkProject（必须绑定项目才能使用黑板）
3. 在输入框中输入你的任务

### 常用指令示例

```
# 启动渗透测试
"对 10.0.0.1 进行端口扫描和漏洞探测"

# 注入黑板 Hint
"注意：目标可能有 WAF，建议用慢速扫描"

# 查看当前进度
"当前进度如何？"

# 查询发现
"报告发现的漏洞"
```

### 智能体回复结构

每个回复包含：
- **主管的思考** — CSO 的分析和决策
- **委派记录** — 哪些专家被分派了什么任务
- **工具调用** — 执行了哪些命令
- **黑板更新** — 记录了哪些 Fact/Intent

### 会话管理

- 左侧可以查看历史会话列表
- 每个会话独立，互不干扰
- 会话绑定项目后，所有写入该项目的数据共享

---

<a id="agent-team"></a>
## 6. 理解智能体团队 / Agent Team

### 角色分工

| 代号 | 名称 | 专长 |
|------|------|------|
| **CSO** | 玄幕 | 安全主管 — 任务分解、团队协调、最终决策 |
| **CAE** | 守拙 | 代码审计 — 源码安全审查、漏洞模式识别 |
| **CIE** | 观星 | 情报侦察 — 信息收集、资产发现、子域名枚举 |
| **CPE** | 破军 | 渗透测试 — 端口扫描、漏洞利用、内网横向 |
| **CRE** | 溯源 | 逆向分析 — 二进制分析、调试、反混淆 |
| **CCE** | 破阵 | 密码分析 — 加密协议分析、弱口令检测 |

### 协作方式

1. **你发出任务** → CSO 接收
2. **CSO 分析** → 读取黑板，了解当前状态
3. **CSO 委派** → 分配合适的专家
4. **专家执行** → 使用工具，记录 Fact 到黑板
5. **CSO 汇总** → 读取黑板，总结进展，决定下一步
6. **回复你** → 汇报结果

整个过程中，所有智能体通过**共享黑板**协调，不互相打断。

---

<a id="blackboard"></a>
## 7. 使用黑板（Blackboard） / Blackboard

黑板是本平台的核心特色，记录智能体的完整推理过程。

### 查看黑板

**方式一：在项目工作区查看**

1. 进入「项目管理」
2. 点击项目名称进入工作区
3. 切换到 **Blackboard** 标签页

**方式二：在对话中查看**

1. 在 Playground 右上角点击项目信息按钮
2. 切换到 **Blackboard** 标签页

### 黑板节点类型

| 图标 | 类型 | 含义 | 生命周期 |
|------|------|------|---------|
| 🟢 | **Fact** | 已确认的客观发现 | proposed → confirmed / rejected |
| 🔵 | **Intent** | 声明的探索方向 | proposed → in_progress → confirmed / rejected |
| 🟠 | **Hint** | 人类或AI注入的指引 | 持久存在 |

### 节点状态

| 状态 | 含义 |
|------|------|
| `proposed` | 刚提出，尚未开始 |
| `in_progress` | 正在执行中 |
| `confirmed` | 已确认（Fact 有证据，Intent 已完成） |
| `rejected` | 此路不通（避免重复劳动） |
| `superseded` | 被更好的节点替代 |

### 典型黑板演进过程

以一个渗透测试为例，黑板会这样演进：

```
阶段 1：侦察
  Intent: "扫描 10.0.0.1 的开放端口"
  Fact: "发现端口 22 (SSH), 80 (HTTP), 443 (HTTPS)"

阶段 2：Web 探测
  Intent: "识别 80 端口 Web 服务"
  Fact: "nginx 1.2.3，存在 CVE-2024-xxx"
  Intent: "尝试 CVE-2024-xxx 利用"

阶段 3：尝试与结果
  Fact: "CVE-2024-xxx 利用失败 — 目标已修补"  (rejected)
  Intent: "转向 SSH 弱口令爆破"
  Fact: "SSH root/toor 登录成功"  (confirmed)

阶段 4：内网横向
  Intent: "从 10.0.0.1 横向移动到 10.0.0.2"
  ...
```

你可以随时在黑板中注入 Hint 来引导方向：

```
在对话中说："先在 80 端口上多花点时间，不急着扫 SSH"
→ CSO 会自动写入一个 Hint 节点，所有专家都能看到
```

### 黑板的价值

| 场景 | 没有黑板 | 有黑板 |
|------|---------|--------|
| 专家 A 试过某方向失败 | 专家 B 可能再试一次 | B 看到 `rejected` 直接跳过 |
| 你想给中间指引 | 只能重复说 | 写一个 Hint，全员可见 |
| Agent 超时退出 | 进度全丢 | 回来读黑板，从断点继续 |
| 复盘整个过程 | 翻对话历史 | 沿着 Fact→Intent 回溯 |
| 多个项目对比 | 凭记忆 | 看黑板图的模式和差异 |

---

<a id="custom-skills"></a>
## 8. 使用自定义技能（Skills） / Custom Skills

### 什么是 Skill

Skill 是 Agent 可以动态加载的**领域知识模块**。每个 Skill 对应一个工具或方法论，Agent 在执行任务时通过 `load_skill` 获取用法说明，然后按照说明操作。

### 两种模式

XuanMu 有两种 Skill 模式，路径和用途不同：

| 模式 | 路径 | 用途 | 何时生效 |
|------|------|------|---------|
| **本地模式** | `项目根目录/.agents/skills/` | 用户自定义 Skill | 无需 Docker，直接可用 |
| **沙箱模式** | `sandbox/.agents/skills/` | 内置工具 Skill（nmap 等） | 仅 Docker 沙箱容器内生效 |

### 本地模式（你自建的 Skill）

在**项目根目录**下的 `.agents/skills/` 中创建，无需 Docker，无需改代码。Skill 可以是纯知识类文档，也可以包含可执行脚本：

```bash
# 在项目根目录下操作（比如 /root/Desktop/XuanMu-RedTeam-Agent/）
mkdir -p .agents/skills/my-skill
```

目录结构：

```
项目根目录/
└── .agents/
    └── skills/                   ← 手动创建这个目录
        ├── sql-injection-guide/  ← 纯知识类（只有 SKILL.md）
        │   └── SKILL.md
        ├── windows-privesc/      ← 纯知识类
        │   └── SKILL.md
        └── my-scanner/           ← 带脚本的（SKILL.md + 资源文件）
            ├── SKILL.md
            ├── scan.sh
            └── payloads.txt
```

### 沙箱模式（内置工具 Skill）

`sandbox/.agents/skills/` 中的 Skill 是项目内置的，**仅在 Docker 沙箱容器内生效**。这些 Skill 对应容器里预装的命令行工具。如果你没启用沙箱（本地模式），它们不会被加载。

### SKILL.md 格式

两种模式的 SKILL.md 格式完全一样：

````markdown
---
name: my-tool
description: 用 my-tool 做某事的简明说明。
---

# My Tool

使用 `my-tool` 的命令格式和注意事项...

## 帮助优先

先执行帮助命令获取真实选项：

```sh
my-tool --help
```

## 输出规范

- 报告做了什么、结果是什么
````

### Agent 如何使用 Skill

1. **`list_skills`** — Agent 查看有哪些可用技能
2. **`load_skill("my-tool")`** — Agent 加载 SKILL.md 全文到上下文
3. Agent 按照 SKILL.md 的指引执行命令
4. 如果 Skill 目录下有辅助脚本，Agent 可以读取路径后引用

### 内置 Skill 清单（沙箱模式专用）

以下 Skill 仅在**启用沙箱容器**时生效，全部位于 `sandbox/.agents/skills/`：

| Skill | 用途 |
|-------|------|
| `nmap` | 端口扫描、服务识别、NSE 脚本 |
| `sqlmap` | SQL 注入自动检测与利用 |
| `httpx` | HTTP 探测、技术栈指纹 |
| `binwalk` | 固件分析、文件提取 |
| `jadx` | APK/DEX 反编译 |
| `apktool` | APK 解包/重打包 |
| `ghidra` | 二进制逆向分析 |
| `openssl` | 证书分析、TLS 诊断 |
| `dns-whois` | DNS 查询、WHOIS 信息收集 |
| `observer-ward` | Web 指纹识别 |
| `archive-file-triage` | 压缩包分类与解包 |
| `sandbox-shell` | 沙箱环境基础 Shell 操作 |

> 这些 Skill 主要在**沙箱容器模式**下使用。本地模式（无需 Docker）下只加载 `.agents/skills/` 中的自定义 Skill。

### Skills 与 Knowledges 的区别

XuanMu 有两套独立的知识加载系统：

| | Skills | Knowledges |
|------|--------|------------|
| 路径 | `.agents/skills/` | `.xuanmu/agents/{角色}/knowledges/` |
| 作用域 | **共享** — 所有 Agent 可用 | **专属** — 每个角色自己的知识库 |
| 工具 | `list_skills` / `load_skill` | `find_knowledge` / `load_knowledge` |
| 适合放什么 | 通用工具说明、共享方法论 | 角色专属方法论、行业标准 |

> Skills 放「怎么用 nmap」，Knowledges 放「渗透测试方法论」。各管各的，互不干扰。

---

<a id="evidence-plane"></a>
## 9. 理解证据平面 / Evidence Plane

证据平面（Evidence Plane）是项目的结构化数据层，与黑板互补：

```
黑板（过程层）：为什么查 → 查到什么 → 下一步查什么
证据平面（结果层）：资产清单 → 漏洞发现 → 关系图 → 攻击路径
```

### 标签页说明

| 标签 | 内容 | 谁在用 |
|------|------|--------|
| **Assets** | 资产清单（IP、域名、服务等） | 所有人 |
| **Findings** | 漏洞发现（标题、严重等级、状态） | 报告编写者 |
| **Attack Paths** | 攻击链（从入口到目标的完整路径） | 渗透测试报告 |
| **Graph** | 资产关系图（可视化网络拓扑） | 全局视图 |
| **Blackboard** | 推理过程图（AI 的思考链路） | 审计与复盘 |

### 与黑板的关系

```
黑板上：
  Fact: "10.0.0.1:80 是 nginx 1.2.3"
  Fact: "存在 CVE-2024-xxx"
  Fact: "利用失败（已修补）"

证据平面上：
  Asset: 10.0.0.1:80  (service)
  Finding: "nginx 1.2.3 已修补" (info)
```

黑板记录的是「尝试过、失败了」——这是推理过程。
证据平面只记录「存在什么、确认了什么」——这是最终结果。

---

<a id="faq"></a>
## 10. 常见问题 / FAQ

### Q: 智能体不按预期工作怎么办？

1. 检查 `.xuanmu/config.json` 中 API Key 是否正确
2. 检查模型是否支持工具调用（Function Calling）
3. 尝试在对话中给出更具体的指令
4. 查看黑板了解智能体当前的推理状态

### Q: 如何重置项目？

删除项目后重新创建即可。删除项目会同时清理所有关联数据（资产、发现、黑板节点等）。

### Q: 黑板数据太多怎么办？

黑板是 append-only 的，但项目级别的黑板通常不会太大。如果需要清理，可以删除项目重建。

### Q: 如何更换 LLM 模型？

重新运行 `bash config-tool.sh` 或在 `.xuanmu/config.json` 中修改对应角色的 `base_url` 和 `model` 字段。

### Q: 忘记管理员密码怎么办？

通过命令行重置：

```bash
source .venv/bin/activate
python << 'EOF'
from database import get_sync_session
from model.system.users import SystemUser
from passlib.hash import bcrypt
with get_sync_session() as s:
    user = s.query(SystemUser).filter(SystemUser.email == "admin@admin.com").first()
    user.password = bcrypt.hash("admin123")
    s.commit()
EOF
```

### Q: 如何升级到最新版本？

**Docker 部署：**

```bash
git pull
bash docker-setup.sh stop
bash docker-setup.sh start    # 会自动重新构建镜像
```

**本地安装：**

```bash
git pull
source .venv/bin/activate
pip install -r requirements.txt
cd web && npm install && npm run build && cd ..
```

### Q: Docker 构建失败怎么办？

1. 确认 Docker Desktop 已启动且正常运行
2. 检查网络连接（构建需要下载依赖）
3. 尝试清理 Docker 缓存后重建：`docker builder prune && bash docker-setup.sh start`
4. 如果磁盘不足，清理无用镜像：`docker system prune`

### Q: Docker 部署后如何修改 LLM 配置？

直接编辑 `.xuanmu/config.json`，然后重启服务：

```bash
vi .xuanmu/config.json
bash docker-setup.sh restart
```

也可以使用配置工具（本地需要 Python）：`bash config-tool.sh`

### Q: Docker 部署和本地安装能共存吗？

可以，但要注意端口冲突。Docker 默认使用 8000 端口，如果本地也在运行，需要修改 `.env` 中的 `XUANMU_PORT` 为其他值。数据库也各自独立——Docker 用容器内的 PostgreSQL，本地用宿主机的 PostgreSQL。

### Q: 如何备份 Docker 部署的数据？

数据库数据存储在 Docker 命名卷 `xuanmu-pgdata` 中。备份方式：

```bash
# 导出数据库
docker exec xuanmu-postgres pg_dump -U root z3r0 > backup.sql

# 恢复数据库
cat backup.sql | docker exec -i xuanmu-postgres psql -U root z3r0
```
