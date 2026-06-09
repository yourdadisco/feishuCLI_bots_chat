# CLI 本地方案（方案一）

> 运行 `lark-cli.ps1` 让三个 Bot 在群里协作讨论，即用即走。

## 快速开始

```powershell
cd cli
.\lark-cli.ps1 ai chat --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "我们想做AI客服，分析一下"
```

执行后飞书群里自动出现五步讨论：

```
产品总监: 收到任务。@产品经理 你做产品分析
产品经理: @产品总监 从用户场景来看...🎯
产品总监: @研发 你评估技术可行性
研发:     @产品总监 技术上可行，建议...
产品总监: 【总结】产品分析 + 技术评估 + 下一步
```

## 所有命令

```powershell
# AI 团队讨论（五步自动完成）
.\lark-cli.ps1 ai chat --chat-id oc_xxx --text "你的需求"

# 手动发消息（产品总监，默认身份）
.\lark-cli.ps1 im +messages-send --chat-id oc_xxx --text "内容"

# 手动发消息（产品经理）
.\lark-cli.ps1 --profile abot im +messages-send --chat-id oc_xxx --text "内容"

# 手动发消息（研发）
.\lark-cli.ps1 --profile bbot im +messages-send --chat-id oc_xxx --text "内容"

# 查看群消息
.\lark-cli.ps1 im +chat-messages-list --chat-id oc_xxx

# 查看三个身份
.\lark-cli.ps1 profile list

# 轮询监听消息
.\lark-cli.ps1 event consume --chat-id oc_xxx
```

## 参数说明

| 参数 | 作用 | 默认 |
|:---|:---|---|
| `--profile director` | 产品总监身份 | ✅ 默认 |
| `--profile abot` | 产品经理身份 | |
| `--profile bbot` | 研发工程师身份 | |
| `--chat-id oc_xxx` | 群聊 ID | 必填 |
| `--text "内容"` | 消息/任务内容 | 必填 |

## 优缺点

| 优点 | 缺点 |
|:---|:---|
| 无需服务器，即开即用 | 需要手动触发 |
| 完全本地控制，数据不外泄 | 仅限 Windows PowerShell |
| 不依赖任何外部服务 | 不能自动响应群消息 |
| 改代码随时调整人设 | |