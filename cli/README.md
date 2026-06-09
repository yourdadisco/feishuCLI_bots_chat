# CLI 本地使用

运行命令，三个 AI 机器人在群里讨论你的需求。

## 发起团队讨论

```powershell
.\lark-cli.ps1 ai chat --chat-id oc_xxx --text "分析AI客服方案"
```

## 手动控制

```powershell
# 产品总监发言（默认）
.\lark-cli.ps1 im +messages-send --chat-id oc_xxx --text "内容"

# 产品经理发言
.\lark-cli.ps1 --profile abot im +messages-send --chat-id oc_xxx --text "内容"

# 研发发言
.\lark-cli.ps1 --profile bbot im +messages-send --chat-id oc_xxx --text "内容"

# 查看群消息
.\lark-cli.ps1 im +chat-messages-list --chat-id oc_xxx
```
