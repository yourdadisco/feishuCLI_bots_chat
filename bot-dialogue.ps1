<#
.SYNOPSIS
  Abot & Bbot 一次性对话脚本 v3
  首句固定，后续 AI 基于上下文自动回复。
#>

param(
    [int]$Rounds = 6,
    [switch]$AI = $true,
    [string]$ApiKey = "sk-8dc66b7474cf4c19b3e77fb9bcedc92d",
    [int]$Interval = 3,
    [string]$ChatId = "oc_88cdd7c54cf79fca0b959644630f9b6d"
)

$abotCfg = @{AppId="cli_aaad306c77b91bc3"; AppSecret="34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0"}
$bbotCfg = @{AppId="cli_aaad323347a4dbc4"; AppSecret="UURsYT81a1bxNLq7uI6vfc72BdeKc0RB"}
$script:History = @()
$script:AbotIdx = 0; $script:BbotIdx = 0

$abotScript = @("Bbot！在吗在吗？今天聊点啥？","你觉得 AI PM 需要懂技术到什么程度？","AI 产品要简单到让小白也能用～","设计 AI 助手的第一原则是什么？","好啦，今天聊得很开心！下次继续！")
$bbotScript = @("在的。建议理解 prompt 和 RAG。","同意，但简单不等于简陋。","第一原则：可预测性。","好的，下次聊聊具体实现。","再见。")

# ===== AI 人设（精简版） =====
$abotSys=@"
你扮演 Abot，资深 AI 产品经理。正在和研发工程师 Bbot 聊天。
性格极其热情外向，话多。凡事从用户场景、市场价值角度聊。
每条必用表情符号😊🎯🔥或"！""～"，25-50字。
结构：热情回应 → 产品/用户视角 → 抛问题。
多聊：场景、痛点、用户体验、ROI、市场、用户需求、价值。
绝对不要评价"作为产品经理"。
"@

$bbotSys=@"
你扮演 Bbot，资深 AI 研发工程师。正在和产品经理 Abot 聊天。
冷静理性，说话一针见血。绝对不用任何表情符号和语气词。
每条10-35字，能短则短。直接说技术判断 → 带数据 → 给结论。
多聊：延迟、吞吐、推理成本、架构、trade-off、瓶颈、资源开销。
绝对不要评价"作为工程师"。
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
        return $false
    } catch { return $false }
}

function Get-Ctx { param([int]$n=6)
    $r=$script:History|Select-Object -Last $n
    if($r.Count -eq 0){return ""}
    return ($r|ForEach-Object{"[$($_.sender)]: $($_.text)"}) -join "`n"
}

function Call-LLM { param($sys,$ctx,$name)
    $key=if($ApiKey){$ApiKey}else{$env:AI_API_KEY}
    if(-not$key){return $null}
    try {
        if ([string]::IsNullOrEmpty($ctx)) {
            $prompt = "请以 $name 的身份说第一句话，打个招呼，引出话题。"
        } else {
            $prompt = "对话记录：`n$ctx`n`n现在请你以 $name 的身份直接回复对方（一句话，自然口语）。"
        }
        $jsonBody=@{model="deepseek-chat";messages=@{role="system";content=$sys},@{role="user";content=$prompt};temperature=0.9;max_tokens=150}|ConvertTo-Json
        # 用 WebClient 确保请求/响应的完整 UTF-8 编解码
        $wc=New-Object System.Net.WebClient
        $wc.Encoding=[System.Text.Encoding]::UTF8
        $wc.Headers.Add("Content-Type","application/json; charset=utf-8")
        $wc.Headers.Add("Authorization","Bearer $key")
        $jsonText=$wc.UploadString("https://api.deepseek.com/v1/chat/completions","POST",$jsonBody)
        $result=$jsonText|ConvertFrom-Json
        $reply=$result.choices[0].message.content.Trim()
        $reply=$reply -replace '^[\x22\x27“”‘’＂]+|[\x22\x27“”‘’＂]+$',''
        return $reply
    } catch { return $null }
}

# ===== 执行 =====
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  Abot & Bbot AI 自动对话" -ForegroundColor Yellow
Write-Host "  模式: $(if($AI){'AI (DeepSeek)'}else{'固定台词'}) | 轮数: $Rounds" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow

for ($i = 0; $i -lt $Rounds; $i++) {
    $round = $i + 1
    Write-Host "--- 第 $round 轮 ---" -ForegroundColor Magenta

    # Abot 发言：第一句固定，后续 AI
    if ($AI -and $i -gt 0) {
        $ctx = Get-Ctx
        $msg = Call-LLM -sys $abotSys -ctx $ctx -name "Abot"
        if (-not $msg) { $msg = "嗯嗯，继续说～" }
    } elseif ($AI) {
        $msg = "Bbot 你好～今天想聊点什么 AI 话题？"
    } else {
        $msg = $abotScript[$script:AbotIdx % $abotScript.Count]; $script:AbotIdx++
    }
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [Abot] $msg" -ForegroundColor Cyan
    Send-Msg $abotCfg "Abot" $msg | Out-Null
    Start-Sleep -Seconds $Interval

    # Bbot 发言：AI 模式始终基于上下文
    if ($AI) {
        $ctx = Get-Ctx
        $msg = Call-LLM -sys $bbotSys -ctx $ctx -name "Bbot"
        if (-not $msg) { $msg = "有道理。" }
    } else {
        $msg = $bbotScript[$script:BbotIdx % $bbotScript.Count]; $script:BbotIdx++
    }
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] [Bbot] $msg" -ForegroundColor Green
    Send-Msg $bbotCfg "Bbot" $msg | Out-Null

    if ($i -lt $Rounds - 1) { Start-Sleep -Seconds $Interval }
}

Write-Host "`n结束！共 $Rounds 轮。" -ForegroundColor Green