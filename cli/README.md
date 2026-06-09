# lark-cli - 飞书多 Agent 协作系统的本地命令行工具

基于飞书 CLI 的多 Profile 架构，实现本地控制三个 Bot 身份。

## 快速开始

```powershell
cd cli

# 查看所有身份
.\lark-cli.ps1 profile list

# 检查认证状态
.\lark-cli.ps1 auth status

# 使用产品总监身份发送消息
.\lark-cli.ps1 --profile director im +messages-send --chat-id oc_xxx --text "你好"

# 使用产品经理身份发送
.\lark-cli.ps1 --profile abot im +messages-send --chat-id oc_xxx --text "你好"

# 使用研发身份发送
.\lark-cli.ps1 --profile bbot im +messages-send --chat-id oc_xxx --text "你好"
```

## 内置 Profiles

| 名称 | 身份 | App ID |
|------|------|--------|
| `director` | 产品总监 | cli_aaad7bd6d33a5bcf |
| `abot` | 产品经理 | cli_aaad306c77b91bc3 |
| `bbot` | 研发工程师 | cli_aaad323347a4dbc4 |

## 群聊 ID

`oc_88cdd7c54cf79fca0b959644630f9b6d`

## 命令参考

| 命令 | 说明 |
|------|------|
| `profile list` | 列出所有可用身份 |
| `auth status` | 查看当前身份认证状态 |
| `im +messages-send --chat-id --text` | 发送文本消息 |
| `im +chat-messages-list --chat-id` | 查看群聊最新消息 |
| `event consume --chat-id` | 轮询监听新消息 |

## 示例：手动模拟团队对话

```powershell
# 产品总监开场
.\lark-cli.ps1 im +messages-send --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "@产品经理 分析一下AI客服方案"

# 产品经理回复
.\lark-cli.ps1 --profile abot im +messages-send --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "@产品总监 从用户场景来看..."

# 研发回复
.\lark-cli.ps1 --profile bbot im +messages-send --chat-id oc_88cdd7c54cf79fca0b959644630f9b6d --text "@产品总监 技术上可行..."
```
