<#
.SYNOPSIS
  Abot & Bbot 自主对话守护脚本（生产版）
.DESCRIPTION
  让 Abot（AI 产品经理）和 Bbot（AI 研发工程师）在飞书群中 7x24 自动对话。
  使用本地对话记忆，无需群消息读取权限。
.PARAMETER Mode
  对话模式: ai (AI 驱动,默认) | script (固定台词)
.PARAMETER ApiKey
  DeepSeek API Key（已内置，可覆盖）
.PARAMETER MaxRounds
  最大对话轮数（0=无限，默认）
.PARAMETER Delay
  回复间隔秒数（默认 4）
.PARAMETER ChatId
  群聊 ID
#>

param(
    [ValidateSet("script","ai")][string]$Mode="ai",
    [string]$ApiKey="sk-8dc66b7474cf4c19b3e77fb9bcedc92d",
    [int]$MaxRounds=0,
    [int]$Delay=4,
    [string]$ChatId="oc_88cdd7c54cf79fca0b959644630f9b6d"
)

$logFile = Join-Path $PSScriptRoot "bot-daemon.log"
function Write-Log { param([string]$m,[string]$c="White")
    $t=Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content $logFile "[$t] $m" -Encoding UTF8
    Write-Host "[$t] $m" -ForegroundColor $c
}

$abot=@{AppId="cli_aaad306c77b91bc3";AppSecret="34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0"}
$bbot=@{AppId="cli_aaad323347a4dbc4";AppSecret="UURsYT81a1bxNLq7uI6vfc72BdeKc0RB"}
$script:History=@()
$ai=0;$bi=0

$abotScript=@("Bbot！早上好呀～今天有什么有趣的 AI 新闻吗？","你觉得 AI 产品经理需要懂技术到什么程度？","分享一个观点：AI 产品要简单到让小白也能用～","你设计 AI 助手的话，第一原则是什么？","好啦，今天收获满满！下次继续聊！")
$bbotScript=@("在的。建议至少理解 prompt 工程和 basic RAG。","同意。但简单不等于简陋，底层逻辑要扎实。","第一原则：可预测性。用户要能预期 AI 的行为。","好的，下次可以聊聊具体的技术实现。","再见。")

$abotSys=@"
你扮演 Abot，一个资深 AI 产品经理。正在和研发工程师 Bbot 聊天。

【核心人设】性格极其外向热情，话多，充满好奇心。凡事都想从用户、场景、市场价值的角度聊一聊。
【语言风格】
- 口语化，热情洋溢，每条消息必用表情符号 😊🎯🔥 或"！""～"
- 每条25-50字
- 结构：先热情回应 → 再从产品/用户角度补充 → 最后抛个问题

【产品经理味】每句话里尽量出现以下词汇之一：
"场景""痛点""用户体验""ROI""市场""用户需求""价值""赛道""落地"

【不擅长】纯技术细节、代码实现、算法原理（你只懂概念层面）

【对话示例 - 你就该这么说】
Abot: "哈哈这个方向有搞头啊！🎯 从用户场景来看，这能解决哪些真实痛点呢？"
Abot: "哇成本降了这么多！那中小企业也能玩AI了，你觉得会催生什么新赛道呀～😆"
Abot: "用户体验才是王道！底层用什么技术用户才不关心呢，效果好才是硬道理！🔥"

【禁忌】绝对不要评价自己的身份，不要用"作为产品经理"开头。
"@

$bbotSys=@"
你扮演 Bbot，一个资深 AI 研发工程师。正在和产品经理 Abot 聊天。

【核心人设】冷静理性，极度务实，说话一针见血。对技术指标、性能、成本、架构有敏锐嗅觉。
【语言风格】
- 克制精准，绝对不用任何表情符号或语气助词（不用嗯、哦、呀、啦、嘛）
- 每条10-35字，能短则短，不废话
- 结构：直接说技术判断 → 带数据或事实 → 给结论或建议

【工程师气息】每句话尽量包含以下词汇之一：
"延迟""吞吐""推理成本""性能指标""架构设计""trade-off""瓶颈""资源开销""容错"

【不擅长】市场营销、商业模式、无数据支撑的讨论

【对话示例 - 你就该这么说】
Bbot: "可行。用 RAG 架构成本低，但检索延迟会到200ms。"
Bbot: "40% 的成本下降主要来自量化蒸馏，精度损失 1-2% 可以接受。"
Bbot: "架构上建议推理层和数据层分离，便于独立扩缩容。"

【禁忌】绝对不要使用任何表情符号，不要用"作为工程师"开头，不要评价自己的身份。
"@

function Get-Token { param($cfg)
    try { $r=Invoke-RestMethod "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" -Method Post -Body (@{app_id=$cfg.AppId;app_secret=$cfg.AppSecret}|ConvertTo-Json) -ContentType "application/json" -TimeoutSec 10; return $r.tenant_access_token } catch { return $null }
}

function Send-Msg { param($cfg,$name,$text)
    $token=Get-Token $cfg; if(-not$token){return $false}
    try {
        $safe=$text -replace '"','\"' -replace "`n","\n" -replace "`r","\r"
        $bodyStr=@{receive_id=$ChatId;msg_type="text";content='{"text":"'+$safe+'"}'}|ConvertTo-Json -Compress
        $utf8Body=[System.Text.Encoding]::UTF8.GetBytes($bodyStr)
        $r=Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id" -Method Post -Headers @{"Authorization"="Bearer $token"} -ContentType "application/json; charset=utf-8" -Body $utf8Body -TimeoutSec 15
        if($r.code -eq 0){$script:History+=@{sender=$name;text=$text};return $true}
        Write-Log "发送失败: $($r.msg)" "Red"; return $false
    } catch { Write-Log "发送异常: $_" "Red"; return $false }
}

function Get-Ctx { param([int]$n=8)
    $r=$script:History|Select-Object -Last $n
    if($r.Count -eq 0){return ""}
    return ($r|ForEach-Object{"[$($_.sender)]: $($_.text)"}) -join "`n"
}

function Call-LLM { param($sys,$ctx,$name)
    $key=if($ApiKey){$ApiKey}else{$env:AI_API_KEY}
    if(-not$key){return $null}
    try {
        if ([string]::IsNullOrEmpty($ctx)) {
            $prompt="请以 $name 的身份说第一句话，打个招呼，引出话题（一句话，20-45字）。"
        } else {
            $prompt="对话记录：`n$ctx`n`n现在请你以 $name 的身份直接回复对方（一句话，自然口语）。"
        }
        $jsonBody=@{model="deepseek-chat";messages=@{role="system";content=$sys},@{role="user";content=$prompt};temperature=0.9;max_tokens=150}|ConvertTo-Json
        $wc=New-Object System.Net.WebClient
        $wc.Encoding=[System.Text.Encoding]::UTF8
        $wc.Headers.Add("Content-Type","application/json; charset=utf-8")
        $wc.Headers.Add("Authorization","Bearer $key")
        $jsonText=$wc.UploadString("https://api.deepseek.com/v1/chat/completions","POST",$jsonBody)
        $result=$jsonText|ConvertFrom-Json
        $reply=$result.choices[0].message.content.Trim()
        $reply=$reply -replace '^[\x22\x27“”‘’＂]+|[\x22\x27“”‘’＂]+$',''
        return $reply
    } catch { Write-Log "LLM Error: $_" "Red"; return $null }
}

Write-Log "==================== Abot & Bbot ====================" "Yellow"
Write-Log "  模式: $(if($Mode-eq'ai'){'AI (DeepSeek)'}else{'固定台词'}) | 群聊: $ChatId" "Yellow"
Write-Log "  日志: $logFile" "Yellow"
Write-Log "  按 Ctrl+C 停止" "Yellow"
Write-Log "=====================================================" "Yellow"

$round=0

try {
    $round++
    $firstMsg = if($Mode -eq "ai") { "Bbot 你好～最近 AI 圈有什么新鲜事吗？" } else { $abotScript[0];$ai=1 }
    Write-Log "[第${round}轮] Abot: $firstMsg" "Cyan"
    Send-Msg $abot "Abot" $firstMsg | Out-Null
    Start-Sleep -Seconds $Delay

    while ($MaxRounds -eq 0 -or $round -lt $MaxRounds) {
        Write-Log "  Bbot 思考中..." "DarkGray"
        Start-Sleep -Seconds $Delay
        if ($Mode -eq "ai") { $reply=Call-LLM -sys $bbotSys -ctx (Get-Ctx) -name "Bbot"; if(-not$reply){$reply="嗯，有道理。"} }
        else { $reply=$bbotScript[$bi%$bbotScript.Count];$bi++ }
        Write-Log "[第${round}轮] Bbot: $reply" "Green"
        Send-Msg $bbot "Bbot" $reply | Out-Null
        Start-Sleep -Seconds ($Delay+(Get-Random -Min 1 -Max 3))

        if ($MaxRounds -gt 0 -and $round -ge $MaxRounds) { break }; $round++

        Write-Log "  Abot 思考中..." "DarkGray"
        Start-Sleep -Seconds $Delay
        if ($Mode -eq "ai") { $reply=Call-LLM -sys $abotSys -ctx (Get-Ctx) -name "Abot"; if(-not$reply){$reply="嗯嗯，继续说～"} }
        else { $reply=$abotScript[$ai%$abotScript.Count];$ai++ }
        Write-Log "[第${round}轮] Abot: $reply" "Cyan"
        Send-Msg $abot "Abot" $reply | Out-Null
        Start-Sleep -Seconds ($Delay+(Get-Random -Min 1 -Max 3))
    }
}
catch { Write-Log "异常: $_" "Red" }
finally { Write-Log "已停止 | 总轮数: $round" "Yellow" }