# 🤖 Feishu CLI Multi-Bots Team

> 在飞书群里组建你的 AI 团队：**产品总监（产品总监）+ 产品经理（产品经理）+ 研发（研发工程师）**
>
> 你在群里 @产品总监 发需求 → 三人自动协作讨论 → 出结论

---

## 📖 这是什么？

一个**三 Agent 协作系统**，在飞书群聊中模拟一个产品团队：

| 角色 | 名字 | 职责 | 风格 |
|:---:|:---:|:---|:---:|
| 🟡 **总监** | 产品总监 | 调度者，拆解任务、指派分工、总结决策 | 权威不强势 |
| 🟢 **产品经理** | 产品经理 | 分析用户需求、市场机会、产品方向 | 热情，用表情 🎯 |
| 🔵 **研发工程师** | 研发 | 评估技术可行性、成本、开发周期 | 冷静，用数据说话 |

**工作流程：**
```
你在群里 @产品总监 我们想做AI客服，分析一下
         ↓
产品总监 → @产品经理 你先做产品分析
         ↓
产品经理 → @产品总监 用户需求是...，目标用户是...，建议...🎯
         ↓
产品总监 → @研发 你评估技术可行性
         ↓
研发 → @产品总监 技术上可行，周期约3个月，成本约...
         ↓
产品总监 → 【完整总结】产品分析结论 + 技术评估结论 + 综合建议
```

---

## 🚀 快速开始

### 准备工作

你需要提前准备：

1. **一个飞书企业账号**（或飞书测试企业）
2. **三个飞书应用**（已在开发者后台创建好）
3. **一个 DeepSeek API Key**（或其他兼容 OpenAI 的 LLM API）

> 如果你还没有飞书应用，请先阅读 [飞书开放平台文档](https://open.feishu.cn/document/) 创建三个应用并开启机器人能力。

### 第一步：配置应用凭证

打开项目根目录的 `bot-team.ps1`，找到这三行：

```powershell
$dc=@{AppId="你的总监应用AppId";AppSecret="你的总监应用AppSecret"}
$pc=@{AppId="你的产品经理应用AppId";AppSecret="你的产品经理应用AppSecret"}
$ec=@{AppId="你的研发工程师应用AppId";AppSecret="你的研发工程师应用AppSecret"}
```

换成你自己的三个应用的 App Id 和 App Secret。

### 第二步：设置 API Key

同样在 `bot-team.ps1` 中，找到：

```powershell
$Key="sk-你的DeepSeekApiKey"
```

换成你自己的 DeepSeek API Key（或其他 LLM 的 API Key）。

### 第三步：确认群聊 ID

找到：

```powershell
$ChatId="oc_你的群聊ID"
```

换成你的飞书群聊 ID（群聊链接末尾的 `oc_xxx` 部分）。

> 💡 **不知道怎么获取群聊 ID？**
> 打开飞书群聊 → 群设置 → 群二维码/链接 → 链接末尾 `oc_` 开头的就是

### 第四步：运行！

**本地直接运行（简单模式）：**

```powershell
cd scripts
.\bot-console.ps1
```

然后在终端输入你的任务，讨论结果会自动发到飞书群。

**想让 @产品总监 自动响应？有两种方式：**

<details>
<summary><b>方式一：部署到 Zeabur（推荐，免费，稳定）</b></summary>

1. 进入 `zeabur-bot-team/` 目录
2. 推送到 GitHub
3. 在 [Zeabur](https://zeabur.com) 导入仓库部署
4. 在 Zeabur 项目设置中添加环境变量（参考 `.env.example`）
5. 拿到 Zeabur 分配的域名
6. 去飞书开发者后台配置事件订阅：

   - 打开 [飞书开发者后台](https://open.feishu.cn/app)
   - 进入你的应用 → 「事件与回调」
   - **请求地址**填 `https://你的域名.zeabur.app`
   - 「添加事件」→ `im.message.receive_v1`
   - 保存 → 发布新版本

   > ⚠️ **三个应用都要配一遍！**

7. 在群里 @产品总监 试试！
</details>

<details>
<summary><b>方式二：localtunnel 临时测试</b></summary>

```bash
# 安装 localtunnel
npm install -g localtunnel

# 启动 webhook（一个窗口）
.\bot-webhook.ps1

# 启动隧道（另一个窗口）
lt --port 8888

# 拿到 URL（如 https://xxx.loca.lt），配置到飞书开发者后台的事件订阅
```
</details>

---

## 📁 项目结构

```
├── server.js               Zeabur 部署入口 (Node.js HTTP)
├── package.json            Node.js 配置
├── .env.example            环境变量模板
├── README.md               本文件
│
├── docs/                   文档
│   ├── 产品需求文档-PRD.md      产品需求文档
│   ├── 技术设计文档.md          技术设计文档
│   ├── 配置记录.md              应用凭证和配置
│   ├── 角色设定-产品经理.md       产品经理人设
│   ├── 角色设定-研发工程师.md     研发工程师人设
│   └── 飞书CLI实现AB机器人对话指南.md
│
├── scripts/                本地 PowerShell 脚本
│   ├── bot-console.ps1     ⭐ 交互式控制台（输入任务→群聊出结果）
│   ├── bot-team.ps1        一次性任务脚本
│   ├── bot-webhook.ps1     本地 Webhook 调试
│   ├── bot-daemon.ps1      (旧版) 双Bot自由对话
│   ├── bot-daemon-v2.ps1   (旧版) 守护模式
│   └── bot-dialogue.ps1    (旧版) 双Bot对话
│
└── examples/               参考案例
    └── AI热点解析助手-PRD.md     AI热点解析助手需求文档
    └── AI热点解析助手-技术设计.md  AI热点解析助手技术文档
```

---

## ⚙️ 环境变量（Zeabur 部署用）

| 变量名 | 说明 |
|:---|:---|
| `DIRECTOR_APP_ID` | 产品总监应用的 App ID |
| `DIRECTOR_APP_SECRET` | 产品总监应用的 App Secret |
| `PM_APP_ID` | 产品经理应用的 App ID |
| `PM_APP_SECRET` | 产品经理应用的 App Secret |
| `ENGINEER_APP_ID` | 研发工程师应用的 App ID |
| `ENGINEER_APP_SECRET` | 研发工程师应用的 App Secret |
| `CHAT_ID` | 飞书群聊 ID |
| `DEEPSEEK_API_KEY` | DeepSeek API Key |

---

## ❓ 常见问题

**Q: 在群里 @产品总监 没人回复？**

A: 检查以下几点：
- Webhook 服务是否在运行（本地模式）
- Zeabur 是否已部署成功（云模式）
- 飞书开发者后台的事件订阅 URL 是否配置正确
- 三个应用都添加了 `im.message.receive_v1` 事件并发布上线
- 三个应用都有 `im:message.group_at_msg.include_bot:readonly` 权限

**Q: 控制台输出乱码？**

A: Windows PowerShell 的显示问题，不影响飞书群里的消息。看到的英文乱码实际是正确的中文。

**Q: 响应太慢怎么办？**

A: 每轮对话之间有 3 秒等待模拟思考时间，可在脚本中调整 `Start-Sleep -Seconds 3` 的值。

**Q: 想换其他 LLM（如 GPT-4、Claude）？**

A: 修改 `Call-LLM` 函数中的 API 地址和模型名即可。

---

## 📝 License

MIT
