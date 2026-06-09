# lark-cli - 本地命令行工具

> 不需要服务器，不需要配置，一个命令让三个 Bot 在群里协作讨论。

## 快速开始

```powershell
# 进入 cli 目录
cd cli

# 发起 AI 团队讨论（五大步骤自动完成）
.\lark-cli.ps1 ai chat --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "我们想做AI客服，分析一下"
```

执行后，飞书群里会依次出现：

```
产品总监: 收到任务。@产品经理 你先做产品分析。
产品经理: @产品总监 从用户场景来看...🎯
产品总监: @研发 你评估技术可行性。
研发:     @产品总监 技术上可行，建议...
产品总监: 【总结】产品分析结论 + 技术评估 + 下一步行动
```

## 所有命令

### AI 团队讨论

```powershell
.\lark-cli.ps1 ai chat --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "你的需求"
```

自动完成：产品总监开场 → 产品经理分析 → 总监指派 → 研发评估 → 总监总结

### 手动发消息

```powershell
# 产品总监发言（默认身份）
.\lark-cli.ps1 im +messages-send --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "内容"

# 产品经理发言
.\lark-cli.ps1 --profile abot im +messages-send --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "内容"

# 研发工程师发言
.\lark-cli.ps1 --profile bbot im +messages-send --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "内容"
```

### 其他命令

```powershell
# 查看三个 Bot 身份
.\lark-cli.ps1 profile list

# 查看认证状态
.\lark-cli.ps1 auth status

# 查看群聊最新消息
.\lark-cli.ps1 im +chat-messages-list --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d

# 轮询监听新消息（按 Ctrl+C 停止）
.\lark-cli.ps1 event consume --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d
```

## 参数说明

| 参数 | 作用 | 示例 |
|:---|:---|:---|
| `--profile director` | 使用产品总监身份 | 默认 |
| `--profile abot` | 使用产品经理身份 | `--profile abot` |
| `--profile bbot` | 使用研发工程师身份 | `--profile bbot` |
| `--chat-id oc_xxx` | 指定群聊 | `--chat-id oc_88...` |
| `--text "内容"` | 消息内容或任务描述 | `--text "分析XX"` |

## 常见问题

**Q: 提示无法执行脚本？**
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**Q: 控制台中文乱码？**
不影响飞书群里的消息，是 PowerShell 的显示问题。

**Q: 需要什么依赖？**
什么都不需要。PowerShell 5.1+ 自带，直接运行。
