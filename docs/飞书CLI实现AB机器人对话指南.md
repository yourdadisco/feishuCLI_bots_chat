# 飞书 CLI 实现 Abot 与 Bbot 自动对话指南

> 使用 `lark-cli` 的多 Profile 能力，在两个机器人身份之间切换，实现群聊中的自动对话。

---

## 目录

- [一、整体架构](#一整体架构)
- [二、前置准备](#二前置准备)
- [三、配置 CLI 多账号](#三配置-cli-多账号)
- [四、创建群聊并邀请双方](#四创建群聊并邀请双方)
- [五、核心原理](#五核心原理)
- [六、自动对话脚本](#六自动对话脚本)
  - [v1 - 固定台词版](#v1---固定台词版)
  - [v2 - AI 驱动版（接入 LLM）](#v2---ai-驱动版接入-llm)
  - [v3 - 持续对话版（无限轮次）](#v3---持续对话版无限轮次)
- [七、运行与调试](#七运行与调试)
- [八、常见问题](#八常见问题)

---

## 一、整体架构

```
┌─────────────────────────────────────────────────────────┐
│                     你的电脑 / 服务器                      │
│                                                         │
│   lark-cli --profile abot                                │
│      ──→ 发消息 "Hi!"                                     │
│                                                         │
│   lark-cli --profile bbot                                │
│      ──→ 收消息 "Hi!"                                     │
│      ──→ 发回复 "Hello!"                                  │
│                                                         │
│   [循环往复]                                              │
│                                                         │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
            ┌──────────────────────┐
            │   飞书群聊 (oc_xxx)    │
            │  ┌──────┐ ┌──────┐  │
            │  │ Abot │ │ Bbot │  │
            │  └──────┘ └──────┘  │
            └──────────────────────┘
```

---

## 二、前置准备

### 2.1 创建两个飞书应用

前往 [飞书开发者后台](https://open.feishu.cn/app)：

1. 点击「创建应用」，分别创建 **Abot** 和 **Bbot**
2. 进入每个应用 → 「凭证与基础信息」，记下：

| 应用 | App ID | App Secret |
|---|---|---|
| **Abot** | `cli_xxxxxxxxxxxxx1` | `xxxxxxxxxxxxxxxx` |
| **Bbot** | `cli_xxxxxxxxxxxxx2` | `xxxxxxxxxxxxxxxx` |

3. 每个应用开启「机器人」能力：
   - 进入应用 → 「应用功能」→「机器人」→ 开启
4. 添加必要权限：
   - `im:message`（发送消息）
   - `im:chat`（群聊管理）
   - `im:message:readonly`（读取消息）
5. 创建版本并发布上线（至少发布到「测试企业」或「正式」）

### 2.2 安装 lark-cli

```powershell
# 全局安装
npm install -g @larksuite/cli

# 验证
lark-cli --version   # 应输出: lark-cli version 1.x.x
```

---

## 三、配置 CLI 多账号

### 3.1 添加 Profile

```powershell
# 添加 Abot 身份
lark-cli profile add abot

# 添加 Bbot 身份
lark-cli profile add bbot
```

### 3.2 分别登录授权

```powershell
# 切换到 Abot 并登录
lark-cli profile use abot
lark-cli auth login
# → 按提示在浏览器中完成 OAuth 授权

# 切换到 Bbot 并登录
lark-cli profile use bbot
lark-cli auth login
# → 同样完成授权
```

### 3.3 验证 Profile

```powershell
# 查看所有 profile
lark-cli profile list

# 输出示例：
#   abot (current)
#   bbot

# 测试每个身份
lark-cli --profile abot im +chat-list --as bot
lark-cli --profile bbot im +chat-list --as bot
```

> **注意**：`--profile` 参数可以在任何命令中临时指定身份，无需切换。

---

## 四、创建群聊并邀请双方

```powershell
# 以 Abot 身份创建群聊，并邀请 Bbot
lark-cli --profile abot im +chat-create `
    --name "AB自对话测试" `
    --type private `
    --bots cli_xxxxxxxxxxxxx2 `  # 替换为 Bbot 的 App ID
    --description "Abot 和 Bbot 的自动对话测试群" `
    --as bot `
    --set-bot-manager
```

成功后会返回类似：

```json
{
  "code": 0,
  "data": {
    "chat_id": "oc_xxxxxxxxxxxxxxxxxx",
    "name": "AB自对话测试"
  }
}
```

> 记下 `chat_id`，后续所有操作都依赖它。

---

## 五、核心原理

### 5.1 关键命令

| 命令 | 作用 | 身份支持 |
|---|---|---|
| `lark-cli --profile <name> im +messages-send` | 发送消息 | bot / user |
| `lark-cli --profile <name> im +chat-messages-list` | 获取消息列表 | bot / user |
| `lark-cli --profile <name> im +chat-create --bots` | 创建群聊并邀请机器人 | bot / user |

### 5.2 对话流程

```
[A 轮]
  1. lark-cli --profile abot  im +messages-send  ──→ "你好！"
  2. lark-cli --profile bbot  im +chat-messages-list  ──→ 看到 Abot 的消息
  3. lark-cli --profile bbot  im +messages-send  ──→ "你好呀！"

[B 轮]
  4. lark-cli --profile abot  im +chat-messages-list  ──→ 看到 Bbot 的回复
  5. lark-cli --profile abot  im +messages-send  ──→ "今天天气怎么样？"
  
  ... 循环 ...
```

### 5.3 关键参数

- `--profile abot` / `--profile bbot` — 切换身份
- `--as bot` — 以机器人身份操作（否则默认为用户身份）
- `--text "xxx"` — 发送纯文本消息
- `--markdown "xxx"` — 发送 Markdown 格式消息
- `--chat-id oc_xxx` — 指定目标群聊
- `--sort asc` — 按时间正序排列消息（用于读取对话）

---

## 六、自动对话脚本

### v1 - 固定台词版

编写 `bot-dialogue-v1.ps1`：

```powershell
<#
.SYNOPSIS
  Abot & Bbot 自动对话脚本 - 固定台词版
.DESCRIPTION
  使用 lark-cli 的两个 profile，让 Abot 和 Bbot 在群聊中交替发言
.PARAMETER ChatId
  群聊 ID (oc_xxx)
.PARAMETER Rounds
  对话轮数（默认 5 轮）
.PARAMETER Interval
  消息发送间隔秒数（默认 3 秒）
.PARAMETER AbotProfile
  Abot 的 profile 名称（默认 abot）
.PARAMETER BbotProfile
  Bbot 的 profile 名称（默认 bbot）
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ChatId,

    [int]$Rounds = 5,
    [int]$Interval = 3,
    [string]$AbotProfile = "abot",
    [string]$BbotProfile = "bbot"
)

# ─── 台词库 ──────────────────────────────────────────────
$script:abotLines = @(
    "大家好，我是 Abot！Bbot 你在吗？ 🙋",
    "Bbot，今天有什么新鲜事吗？",
    "原来如此！那你觉得飞书 CLI 好用吗？",
    "哈哈，我也觉得不错！下次一起研究更多功能～",
    "好的，今天就聊到这里，拜拜！👋"
)

$script:bbotLines = @(
    "在的在的！Hi Abot！👋 今天天气不错～",
    "我刚发现 lark-cli 有个好玩的命令，可以管理多维表格！",
    "非常好用！而且支持多 profile 切换，开发效率报表。",
    "好呀！下次试试 calendar 和 docs 的命令。",
    "再见～有空再聊！👋"
)

# ─── 工具函数 ─────────────────────────────────────────────

function Send-Message {
    param(
        [string]$Profile,
        [string]$Message
    )

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [$Profile] 发送: $Message" -ForegroundColor $(if ($Profile -eq $AbotProfile) { 'Cyan' } else { 'Green' })
    
    $result = lark-cli --profile $Profile im +messages-send `
        --chat-id $ChatId `
        --text $Message `
        --as bot `
        --format json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ⚠️ 发送失败: $result" -ForegroundColor Red
        return $false
    }
    return $true
}

function Get-LatestMessage {
    param([string]$Profile)

    $result = lark-cli --profile $Profile im +chat-messages-list `
        --chat-id $ChatId `
        --as bot `
        --sort desc `
        --page-size 1 `
        --format json 2>&1 | ConvertFrom-Json

    if ($result.code -ne 0 -or -not $result.data.items) {
        return $null
    }
    return $result.data.items[0]
}

# ─── 主循环 ──────────────────────────────────────────────

Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║    Abot & Bbot 自动对话开始                    ║" -ForegroundColor Yellow
Write-Host "║    群聊: $ChatId" -ForegroundColor Yellow
Write-Host "║    轮数: $Rounds" -ForegroundColor Yellow
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $Rounds; $i++) {
    $round = $i + 1
    Write-Host "─── 第 $round 轮 ───" -ForegroundColor Magenta

    # ── Abot 发言 ──
    $abotMsg = $script:abotLines[$i % $script:abotLines.Count]
    Send-Message -Profile $AbotProfile -Message $abotMsg | Out-Null
    Start-Sleep -Seconds $Interval

    # ── Bbot 发言 ──
    $bbotMsg = $script:bbotLines[$i % $script:bbotLines.Count]
    Send-Message -Profile $BbotProfile -Message $bbotMsg | Out-Null
    
    if ($i -lt $Rounds - 1) {
        Start-Sleep -Seconds $Interval
    }
}

Write-Host ""
Write-Host "✅ 对话结束！共完成 $Rounds 轮对话。" -ForegroundColor Green
```

### v2 - AI 驱动版（接入 LLM）

编写 `bot-dialogue-v2-ai.ps1`，让机器人接入大模型，实现智能对话：

```powershell
<#
.SYNOPSIS
  Abot & Bbot 自动对话脚本 - AI 驱动版
.DESCRIPTION
  两个机器人各自接入 LLM API，根据对话历史生成智能回复
  需要配置 AI API Key（支持 OpenAI / Claude / 国内大模型）
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ChatId,

    [int]$Rounds = 10,
    [int]$PollInterval = 3,
    [string]$AbotProfile = "abot",
    [string]$BbotProfile = "bbot",

    # AI 配置
    [string]$AiEndpoint = "https://api.openai.com/v1/chat/completions",
    [string]$AiModel = "gpt-4o",
    [string]$AiApiKey = ""  # 从环境变量读取: $env:AI_API_KEY
)

# ─── AI 调用函数 ─────────────────────────────────────────

function Invoke-AI {
    param(
        [string]$SystemPrompt,
        [string]$UserMessage
    )

    $apiKey = if ($AiApiKey) { $AiApiKey } else { $env:AI_API_KEY }
    if (-not $apiKey) {
        throw "请设置 AI_API_KEY 环境变量或在参数中传入 AiApiKey"
    }

    $body = @{
        model = $AiModel
        messages = @(
            @{ role = "system"; content = $SystemPrompt }
            @{ role = "user"; content = $UserMessage }
        )
        temperature = 0.9
        max_tokens = 200
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $AiEndpoint `
            -Method Post `
            -Headers @{
                "Authorization" = "Bearer $apiKey"
                "Content-Type"  = "application/json"
            } `
            -Body $body `
            -TimeoutSec 30

        return $response.choices[0].message.content
    }
    catch {
        Write-Host "  ⚠️ AI 调用失败: $_" -ForegroundColor Red
        return "（思考中...）"
    }
}

# ─── 对话系统提示词 ─────────────────────────────────────

$abotPersona = @"
你是一个名叫"Abot"的活泼话痨机器人。你的特点是：
- 热情、话多，喜欢问问题
- 对飞书和办公效率工具充满热情
- 每次回复控制在 50 字以内
- 现在你在和另一个机器人 Bbot 聊天
"@

$bbotPersona = @"
你是一个名叫"Bbot"的冷静技术宅机器人。你的特点是：
- 理性、简洁，喜欢分享技术知识
- 擅长飞书 API 和开发相关话题
- 每次回复控制在 50 字以内
- 现在你在和另一个机器人 Abot 聊天
"@

# ─── 获取最近对话历史 ──────────────────────────────────

function Get-ChatHistory {
    param(
        [string]$Profile,
        [int]$Count = 5
    )

    $result = lark-cli --profile $Profile im +chat-messages-list `
        --chat-id $ChatId `
        --as bot `
        --sort desc `
        --page-size $Count `
        --format json 2>&1 | ConvertFrom-Json

    if ($result.code -ne 0 -or -not $result.data.items) {
        return @()
    }

    $history = @()
    foreach ($item in $result.data.items) {
        $sender = if ($item.sender.id -match "cli_") { "Bot" } else { "User" }
        $history += "[$sender]: $($item.body.content)"
    }

    # 反转成时间正序
    [array]::Reverse($history)
    return $history -join "`n"
}

# ─── 主循环 ──────────────────────────────────────────────

Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║    Abot & Bbot AI 智能对话                     ║" -ForegroundColor Yellow
Write-Host "║    AI Model: $AiModel" -ForegroundColor Yellow
Write-Host "║    群聊: $ChatId" -ForegroundColor Yellow
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Abot 发起第一句
$firstMsg = "Bbot 你好！我是 Abot，今天我们来聊点什么？"
Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [Abot] $firstMsg" -ForegroundColor Cyan
lark-cli --profile $AbotProfile im +messages-send --chat-id $ChatId --text $firstMsg --as bot | Out-Null
Start-Sleep -Seconds 3

for ($i = 0; $i -lt $Rounds; $i++) {
    $round = $i + 1
    Write-Host "─── 第 $round 轮 ───" -ForegroundColor Magenta

    # ── Bbot 看到消息并回复 ──
    Write-Host "  Bbot 正在思考..." -ForegroundColor DarkGray
    $history = Get-ChatHistory -Profile $BbotProfile -Count 4
    $bbotReply = Invoke-AI -SystemPrompt $bbotPersona -UserMessage "对话历史：`n$history`n`n请以 Bbot 的身份回复 Abot。"
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [Bbot] $bbotReply" -ForegroundColor Green
    lark-cli --profile $BbotProfile im +messages-send --chat-id $ChatId --text $bbotReply --as bot | Out-Null
    Start-Sleep -Seconds $PollInterval

    # ── Abot 看到消息并回复 ──
    Write-Host "  Abot 正在思考..." -ForegroundColor DarkGray
    $history = Get-ChatHistory -Profile $AbotProfile -Count 4
    $abotReply = Invoke-AI -SystemPrompt $abotPersona -UserMessage "对话历史：`n$history`n`n请以 Abot 的身份继续聊天，回复 Bbot。"
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [Abot] $abotReply" -ForegroundColor Cyan
    lark-cli --profile $AbotProfile im +messages-send --chat-id $ChatId --text $abotReply --as bot | Out-Null

    if ($i -lt $Rounds - 1) {
        Start-Sleep -Seconds $PollInterval
    }
}

Write-Host ""
Write-Host "✅ AI 对话结束！共完成 $Rounds 轮对话。" -ForegroundColor Green
```

**使用方式：**

```powershell
# 设置 AI API Key
$env:AI_API_KEY = "sk-your-api-key-here"

# 运行（使用 OpenAI）
.\bot-dialogue-v2-ai.ps1 -ChatId oc_xxxxxxxxxx -Rounds 6

# 或指定其他 API（如 DeepSeek、通义千问等兼容 OpenAI 接口的模型）
.\bot-dialogue-v2-ai.ps1 -ChatId oc_xxxxxxxxxx -Rounds 6 `
    -AiEndpoint "https://api.deepseek.com/v1/chat/completions" `
    -AiModel "deepseek-chat"
```

### v3 - 持续对话版（无限轮次）

编写 `bot-dialogue-v3-daemon.ps1`，一直运行直到手动停止：

```powershell
<#
.SYNOPSIS
  Abot & Bbot 持续对话守护脚本
.DESCRIPTION
  持续运行，两个机器人无限轮次对话，直到按 Ctrl+C 停止
.PARAMETER ChatId
  群聊 ID (oc_xxx)
.PARAMETER MaxInterval
  轮询新消息的最大等待秒数（默认 5 秒）
.PARAMETER MinReplyDelay
  回复前的最小等待秒数，模拟人类打字（默认 2 秒）
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ChatId,

    [int]$MaxInterval = 5,
    [int]$MinReplyDelay = 2
)

# ─── 情绪状态（让对话有连贯性） ──────────────────────────

$script:abotState = @{
    mood = "happy"
    topic = "general"
    lastMessage = ""
}

$script:bbotState = @{
    mood = "neutral"
    topic = "general"
    lastMessage = ""
}

# ─── 台词生成器（带简单上下文） ──────────────────────────

$script:abotGreetings = @(
    "Bbot！有什么新消息吗？",
    "嘿嘿，我又来啦～",
    "在吗在吗？🙋",
    "今天天气不错，心情也很好！",
    "Bbot Bbot ~ 呼叫 Bbot ~"
)

$script:abotFollowUps = @(
    "原来如此，继续说！",
    "有意思～还有吗还有吗？",
    "哈哈哈哈 😂",
    "确实确实！",
    "嗯嗯，我在听～",
    "哇，这个我不太了解，能详细说说吗？",
    "赞成！👍",
    "有道理，不过我也在想..."
)

$script:bbotReplies = @(
    "收到收到！我在呢 👋",
    "哈哈，我正在处理一些数据～",
    "嗯，这个有意思！",
    "好的，收到你的消息了。",
    "让我想想...",
    "说得好！我来补充一下..."
)

# ─── 主循环 ──────────────────────────────────────────────

Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║    Abot & Bbot 持续对话守护                    ║" -ForegroundColor Yellow
Write-Host "║    按 Ctrl+C 停止                              ║" -ForegroundColor Yellow
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

$round = 0
$lastMessageId = $null

try {
    while ($true) {
        $round++

        # ─── Abot 发言（首次或回复） ─────────────────
        if ($round -eq 1) {
            $message = $script:abotGreetings | Get-Random
        }
        else {
            $message = $script:abotFollowUps | Get-Random
        }

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [第${round}轮][Abot] $message" -ForegroundColor Cyan
        $result = lark-cli --profile abot im +messages-send --chat-id $ChatId --text $message --as bot --format json 2>&1 | ConvertFrom-Json
        
        if ($result.code -eq 0 -and $result.data.message_id) {
            $lastMessageId = $result.data.message_id
        }

        # 等待 Bbot 回复
        $waitSeconds = $MinReplyDelay + (Get-Random -Minimum 1 -Maximum 4)
        Start-Sleep -Seconds $waitSeconds

        # ─── Bbot 回复 ───────────────────────────────
        $reply = $script:bbotReplies | Get-Random

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [第${round}轮][Bbot] $reply" -ForegroundColor Green
        lark-cli --profile bbot im +messages-send --chat-id $ChatId --text $reply --as bot | Out-Null

        # 随机间隔（3~8 秒），看起来更自然
        $sleepSeconds = $MinReplyDelay + (Get-Random -Minimum 1 -Maximum 6)
        Start-Sleep -Seconds $sleepSeconds
    }
}
catch {
    Write-Host "`n⚠️ 发生错误: $_" -ForegroundColor Red
}
finally {
    Write-Host "`n📊 本轮对话统计:" -ForegroundColor Yellow
    Write-Host "   总轮数: $round" -ForegroundColor White
    
    # 获取最终消息数
    $summary = lark-cli --profile abot im +chat-messages-list --chat-id $ChatId --as bot --page-size 1 --format json 2>&1 | ConvertFrom-Json
    if ($summary.code -eq 0 -and $summary.data.total) {
        Write-Host "   群聊总消息数: $($summary.data.total)" -ForegroundColor White
    }
    
    Write-Host "`n👋 对话守护已停止。" -ForegroundColor Yellow
}
```

---

## 七、运行与调试

### 7.1 运行脚本

```powershell
# 切换到项目目录
cd C:\Users\瓜皮少年\Desktop\飞书cli内bot自对话

# 运行固定台词版
.\bot-dialogue-v1.ps1 -ChatId oc_xxxxxxxxxx -Rounds 5

# 运行 AI 驱动版
$env:AI_API_KEY = "sk-xxxx"
.\bot-dialogue-v2-ai.ps1 -ChatId oc_xxxxxxxxxx -Rounds 3

# 运行持续对话版（Ctrl+C 停止）
.\bot-dialogue-v3-daemon.ps1 -ChatId oc_xxxxxxxxxx
```

### 7.2 手动查看对话

```powershell
# 以 Abot 身份看群聊历史
lark-cli --profile abot im +chat-messages-list --chat-id $ChatId --as bot --sort asc --format pretty

# 以 Bbot 身份看
lark-cli --profile bbot im +chat-messages-list --chat-id $ChatId --as bot --sort asc --format pretty
```

### 7.3 清理群聊

```powershell
# 关于如何删除群聊，可以查看帮助
lark-cli im +chat-update --help
```

---

## 八、常见问题

### Q1: `Auth` 报错，无法登录

确保应用已发布上线，并且在「权限管理」中添加了 `im:message` 权限。

```powershell
# 诊断认证问题
lark-cli doctor

# 查看当前 token 的权限
lark-cli auth scopes
```

### Q2: 机器人发消息报错 "permission denied"

检查：
1. 应用是否已发布上线
2. 权限是否已添加（`im:message` 等）
3. 机器人是否已在目标群中（使用 `--bots` 参数邀请进群）

### Q3: 消息列表为空

```powershell
# 确认 chat_id 正确，并且机器人是群成员
lark-cli --profile abot im +chat-list --as bot
```

### Q4: 两个 bot 用同一套 App ID？

不可以。每个 bot 需要**独立的应用**（不同的 App ID 和 App Secret），各自拥有独立的身份。CLI 通过 `--profile` 区分。

### Q5: AI 版调用报错

- 检查 API Key 是否正确
- 确认 API Endpoint 格式（默认兼容 OpenAI 格式）
- 国内网络可能需要配置代理

### Q6: 机器人在群聊中看不到对方的消息？

飞书机器人默认只能收到**被 @ 时**的消息通知。但在群聊中，**发送消息给群聊**后，其他机器人成员**实际上可以读取到这些消息**（通过 `+chat-messages-list` API）。脚本中使用主动轮询的方式获取消息，所以不受 @ 限制。

---

## 总结

| 脚本 | 特点 | 适用场景 |
|---|---|---|
| `bot-dialogue-v1.ps1` | 固定台词，简单可靠 | 测试群聊功能、演示 |
| `bot-dialogue-v2-ai.ps1` | AI 驱动，智能回复 | 真实对话模拟、AI Bot 测试 |
| `bot-dialogue-v3-daemon.ps1` | 持续运行，无限对话 | 长时间运行测试、稳定性验证 |

---

> **参考链接**
>
> - [飞书开放平台 CLI 文档](https://open.feishu.cn/document/tools-and-resources/cli)
> - [lark-cli GitHub 仓库](https://github.com/larksuite/cli)
> - [飞书开放平台机器人指南](https://open.feishu.cn/document/home/develop-feishu-app/how-to-add-bot)
