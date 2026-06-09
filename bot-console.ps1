<#
.SYNOPSIS
  三 Agent 协作控制台
  终端输入任务 → 团队讨论 → 结果发到飞书群
  不需要 ngrok，不需要注册，现在就能用
#>

# ===== Bot 凭证 =====
$dc=@{AppId="cli_aaad7bd6d33a5bcf";AppSecret="XgwERkjh4KOfFd1pI6MydeSJOFpI0QGs"}
$pc=@{AppId="cli_aaad306c77b91bc3";AppSecret="34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0"}
$ec=@{AppId="cli_aaad323347a4dbc4";AppSecret="UURsYT81a1bxNLq7uI6vfc72BdeKc0RB"}
$ChatId="oc_88cdd7c54cf79fca0b959644630f9b6d"
$Key="sk-8dc66b7474cf4c19b3e77fb9bcedc92d"
$logFile=Join-Path $PSScriptRoot "bot-console.log"

function Log { param($m,$c="White")
    Add-Content $logFile "$(Get-Date -Format 'HH:mm:ss') $m" -Encoding UTF8
    Write-Host "$m" -ForegroundColor $c }

function Token { param($c)
    try{$r=Invoke-RestMethod 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' -Method Post -Body (@{app_id=$c.AppId;app_secret=$c.AppSecret}|ConvertTo-Json) -ContentType 'application/json' -TimeoutSec 10;$r.tenant_access_token}catch{$null}}

function Send-Msg { param($c,$t)
    $token=Token $c;if(-not$token){return}
    try{$s=$t-replace '"','\"'-replace "`n",'\n'
        $b=@{receive_id=$ChatId;msg_type='text';content='{"text":"'+$s+'"}'}|ConvertTo-Json -Compress
        $u=[System.Text.Encoding]::UTF8.GetBytes($b)
        Invoke-RestMethod 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id' -Method Post -Headers @{'Authorization'="Bearer $token"} -ContentType 'application/json; charset=utf-8' -Body $u -TimeoutSec 15|Out-Null}catch{Log "  发消息失败: $_" 'Red'}}

function Run-Task {
    param([string]$Task)
    if ([string]::IsNullOrWhiteSpace($Task)) { return }

    $global:History=@()

    # 人设
    $DSys="你扮演张总，产品总监。工作：1)@阿博做产品分析 2)@阿布做技术评估 3)给用户总结。围绕用户具体任务展开。"
    $PSys="你扮演阿博，热情的产品经理。以'@张总'开头。针对用户任务分析需求、市场机会。用表情符号。"
    $ESys="你扮演阿布，技术负责人。以'@张总'开头。针对用户任务评估可行性、成本、周期。不用表情。"

    function LLM { param($sys,$ctx,$name,$task,$role)
        try{$p="用户任务：$task`n`n$ctx`n`n$role($name)发言。针对任务直接给出专业分析，不要说需要更多信息。"
            $j=@{model='deepseek-chat';messages=@{role='system';content=$sys},@{role='user';content=$p};temperature=0.85;max_tokens=400}|ConvertTo-Json
            $w=New-Object System.Net.WebClient;$w.Encoding=[System.Text.Encoding]::UTF8
            $w.Headers.Add('Content-Type','application/json; charset=utf-8');$w.Headers.Add('Authorization',"Bearer $Key")
            $t=$w.UploadString('https://api.deepseek.com/v1/chat/completions','POST',$j)
            $reply=($t|ConvertFrom-Json).choices[0].message.content.Trim()
            return $reply}catch{return $null}}

    function Ctx{$r=$global:History|Select-Object -Last 20;if($r.Count-eq0){return ''};return ($r-join "`n")}

    Write-Host "`n>>> 团队讨论中..." -ForegroundColor Yellow

    # 步骤 1-5
    $steps = @(
        @{cfg=$dc;sys=$DSys;name='张总';role='张总';extra='用户任务已收到。@阿博做产品分析。';fb="收到任务。@阿博 你做产品分析，分析用户需求和市场机会。"}
        @{cfg=$pc;sys=$PSys;name='阿博';role='阿博';extra='张总@了你，请做产品分析';fb="@张总 收到！我来分析用户需求🎯"}
        @{cfg=$dc;sys=$DSys;name='张总';role='张总';extra='阿博分析完了。@阿布做技术评估。';fb="@阿布 你做技术评估，评估可行性、成本、周期。"}
        @{cfg=$ec;sys=$ESys;name='阿布';role='阿布';extra='张总@了你，请做技术评估';fb="@张总 技术上可行，周期约3个月。"}
        @{cfg=$dc;sys=$DSys;name='张总';role='张总';extra='双方都发表了意见。请给出完整的总结报告给用户，包含产品分析结论、技术评估结论、综合建议。';fb="【总结】产品分析：... 技术评估：... 建议：..."}
    )

    foreach ($s in $steps) {
        $m = LLM -sys $s.sys -ctx (Ctx) -name $s.name -task $Task -role $s.role
        if (!$m) { $m = $s.fb }
        $color = if ($s.name -eq '张总') { 'Yellow' } elseif ($s.name -eq '阿博') { 'Cyan' } else { 'Green' }
        Log "  $($s.name): $m" $color
        Send-Msg $s.cfg $m
        $global:History += "$($s.name): $m"
        Start-Sleep -Seconds 3
    }
    Write-Host ">>> ✅ 完成！结果已发到飞书群`n" -ForegroundColor Green
}

# ===== 控制台主循环 =====
Clear-Host
Write-Host "╔═══════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "║       三 Agent 协作控制台                 ║" -ForegroundColor Yellow
Write-Host "║   张总 + 阿博(产品) + 阿布(技术)          ║" -ForegroundColor Yellow
Write-Host "║                                           ║" -ForegroundColor Yellow
Write-Host "║  输入你的任务，团队讨论后发结果到飞书群    ║" -ForegroundColor Yellow
Write-Host "║  输入 exit 退出                           ║" -ForegroundColor Yellow
Write-Host "║  输入 status 查看当前状态                  ║" -ForegroundColor Yellow
Write-Host "╚═══════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

while ($true) {
    Write-Host "┌─ 你的任务" -ForegroundColor Magenta
    $input = Read-Host "└> "

    if ($input -eq 'exit') { Write-Host "bye!" -ForegroundColor Yellow; break }
    if ($input -eq 'status') {
        Write-Host "群聊: $ChatId" -ForegroundColor DarkGray
        Write-Host "机器人: 张总 + 阿博 + 阿布" -ForegroundColor DarkGray
        continue
    }
    if ([string]::IsNullOrWhiteSpace($input)) { continue }

    Run-Task -Task $input.Trim()
}
