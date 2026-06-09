# 飞书 CLI 实现多 Agent 协作

通过 `cli/lark-cli.ps1` 在本地控制三个机器人身份，实现群里协作讨论。

---

## 核心原理

`lark-cli.ps1` 封装了飞书 REST API，用 `--profile` 参数切换三个 Bot 身份：

```
--profile director  →  产品总监
--profile abot      →  产品经理
--profile bbot      →  研发工程师
```

每个 profile 对应一个飞书应用的 App ID 和 App Secret，发消息时自动获取 token，以对应身份发送。

## 常用命令

```powershell
# AI 团队讨论（五步自动完成）
.\lark-cli.ps1 ai chat --chat-id oc_xxx --text "你的任务"

# 手动控制三个 Bot 轮流发言
.\lark-cli.ps1 --profile director im +messages-send --chat-id oc_xxx --text "@产品经理 分析一下"
.\lark-cli.ps1 --profile abot im +messages-send --chat-id oc_xxx --text "@产品总监 收到，我来分析🎯"
.\lark-cli.ps1 --profile bbot im +messages-send --chat-id oc_xxx --text "@产品总监 技术上可行"

# 查看群消息
.\lark-cli.ps1 im +chat-messages-list --chat-id oc_xxx

# 查看三个身份
.\lark-cli.ps1 profile list
```

## 三种身份

| Profile | 身份 | App ID |
|:---|:---|---|
| `director`（默认） | 产品总监 | cli_aaad7bd6d33a5bcf |
| `abot` | 产品经理 | cli_aaad306c77b91bc3 |
| `bbot` | 研发工程师 | cli_aaad323347a4dbc4 |
