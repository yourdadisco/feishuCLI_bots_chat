# 机器人配置记录

> **创建日期**：2026-06-09
> **最后更新**：2026-06-09（v3 生产版）

---

## Abot — 资深 AI 产品经理

| 字段 | 值 |
|---|---|
| **App ID** | `cli_aaad306c77b91bc3` |
| **App Secret** | `34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0` |
| **人设** | 热情健谈，产品思维，关注 AI 行业 |

## Bbot — 资深 AI 研发工程师

| 字段 | 值 |
|---|---|
| **App ID** | `cli_aaad323347a4dbc4` |
| **App Secret** | `UURsYT81a1bxNLq7uI6vfc72BdeKc0RB` |
| **人设** | 务实冷静，技术导向，简洁精准 |

---

## 项目文件

| 文件 | 说明 |
|---|---|
| **`bot-daemon.ps3`** | ⭐ **生产版守护脚本** — 后台运行，AI 自动对话，记录日志 |
| **`bot-dialogue.ps1`** | **一次性对话脚本** — 指定轮数后自动停止 |
| **`Abot人设.md`** | Abot 完整角色设定 |
| **`Bbot人设.md`** | Bbot 完整角色设定 |
| `飞书CLI实现AB机器人对话指南.md` | 原始技术文档（参考用） |

---

## 使用方式

### AI 智能对话（推荐 🎯）

```powershell
# 一次性对话（跑完即停）
.\bot-dialogue.ps1

# 后台持续对话（Ctrl+C 停止，推荐）
.\bot-daemon.ps1

# 指定轮数
.\bot-daemon.ps1 -MaxRounds 20

# 调整回复速度
.\bot-daemon.ps1 -Delay 5
```

控制台输出中文可能乱码，但**飞书群里的消息正常**。

### 固定台词模式（无需联网）

```powershell
.\bot-dialogue.ps1 -AI:$false
.\bot-daemon.ps1 -Mode script
```

---

## 技术说明

### 架构
```
bot-daemon.ps1 / bot-dialogue.ps1
       ↕ REST API（直接获取 token）
飞书开放平台 ←→ 群聊 oc_88cdd7c54cf79fca0b959644630f9b6d
       ↕ DeepSeek API（AI 模式）
DeepSeek Chat（deepseek-chat）
```

### 关键设计
- **直连 REST API**：通过 App ID + Secret 获取 `tenant_access_token`，绕开 lark-cli 凭据管理问题
- **本地对话记忆**：脚本维护 `$History` 变量记录对话，无需 `im:message.group_msg` 读取权限
- **UTF-8 编码**：使用 `[System.Text.Encoding]::UTF8.GetBytes()` 发送请求，解决中文乱码
- **日志文件**：守护模式自动记录到 `bot-daemon.log`

### 群聊
- **ID**: `oc_88cdd7c54cf79fca0b959644630f9b6d`
- **名称**: bots cooperation
- **成员**: Abot + Bbot

---

## 部署到服务器

```powershell
# 1. 安装 PowerShell Core
winget install Microsoft.PowerShell

# 2. 上传项目目录到服务器

# 3. 后台运行（断开 SSH 也不停）
nohup pwsh -File /path/bot-daemon.ps1 > /dev/null 2>&1 &

# 4. 查看日志
tail -f bot-daemon.log
```
