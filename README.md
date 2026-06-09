# 🤖 Feishu Multi-Bot Team

> 三个 AI 机器人（产品总监 + 产品经理 + 研发工程师）在飞书群里协作讨论，帮你分析需求、评估方案、输出结论。

---

## 两种运行方式

### 方式一：本地 CLI（即开即用）

不需要服务器，不需要配置，下载就能跑。

```powershell
# 1. 进入 cli 目录
cd cli

# 2. 发起团队讨论（AI 自动生成五步讨论）
.\lark-cli.ps1 ai chat --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "分析AI客服方案"

# 3. 手动发消息
.\lark-cli.ps1 --profile director im +messages-send --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "你好"

# 4. 查看群消息
.\lark-cli.ps1 im +chat-messages-list --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d

# 5. 列出三个 Bot 身份
.\lark-cli.ps1 profile list
```

| 参数 | 说明 |
|:---|:---|
| `--profile director` | 用产品总监身份（默认） |
| `--profile abot` | 用产品经理身份 |
| `--profile bbot` | 用研发工程师身份 |
| `--chat-id oc_xxx` | 飞书群聊 ID |
| `--text "内容"` | 要发送的消息 / AI 讨论的任务 |

### 方式二：Zeabur 云端自动响应（24小时在线）

部署到 Zeabur 后，在群里 @产品总监 发需求，三 Agent 自动讨论出结论。

**部署步骤：**
1. 把仓库导入 [Zeabur](https://zeabur.com)
2. 设置环境变量（参考 `.env.example`）
3. 拿到域名后去飞书开发者后台配置事件订阅

详细部署说明见 `docs/`。

---

## 项目结构

```
feishuCLI_bots_chat/
├── cli/                    ★ 本地 CLI（推荐）
│   ├── lark-cli.ps1         命令行工具
│   └── README.md            使用说明
├── server.js               Zeabur 云端部署入口
├── package.json
├── .env.example            环境变量模板
├── docs/                   文档
│   ├── 产品需求文档-PRD.md
│   ├── 技术设计文档.md
│   ├── 配置记录.md
│   └── 飞书CLI实现AB机器人对话指南.md
└── README.md               本文件
```

## 注意事项

- CLI 方式需要 PowerShell，仅限 Windows
- 第一次运行可能需要设置执行策略：`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
- 控制台显示可能乱码，但不影响飞书群里的消息
