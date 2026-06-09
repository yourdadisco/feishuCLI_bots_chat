<#
.SYNOPSIS
  三 Agent 守护模式 - 你在群里@张总，机器人自动响应
.DESCRIPTION
  *** 使用前需要在飞书开发者后台加权限 ***
  群聊中 @张总 + 你的需求 → 三人团队自动讨论 → 给出结论
  按 Ctrl+C 停止
#>

# ===== 配置 =====
$dc=@{AppId="cli_aaad7bd6d33a5bcf";AppSecret="XgwERkjh4KOfFd1pI6MydeSJOFpI0QGs"}
$pc=@{AppId="cli_aaad306c77b91bc3";AppSecret="34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0"}
$ec=@{AppId="cli_aaad323347a4dbc4";AppSecret="UURsYT81a1bxNLq7uI6vfc72BdeKc0RB"}
$ChatId="oc_88cdd7c54cf79fca0b959644630f9b6d"
$Key="sk-8dc66b7474cf4c19b3e77fb9bcedc92d"
$logFile=Join-Path $PSScriptRoot "bot-daemon-v2.log"

function Log { param($m,$c="White")
    Add-Content $logFile "$(Get-Date -Format 'HH:mm:ss') $m" -Encoding UTF8
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" -ForegroundColor $c }

function Token { param($c)
    try{$r=Invoke-RestMethod 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' -Method Post -Body (@{app_id=$c.AppId;app_secret=$c.AppSecret}|ConvertTo-Json) -ContentType 'application/json' -TimeoutSec 10;$r.tenant_access_token}catch{$null}}

function Send-Msg { param($c,$t)
    $token=Token $c;if(-not$token){return}
    try{$s=$t-replace '"','\"'-replace "`n",'\n'
        $b=@{receive_id=$ChatId;msg_type='text';content='{"text":"'+$s+'"}'}|ConvertTo-Json -Compress
        $u=[System.Text.Encoding]::UTF8.GetBytes($b)
        Invoke-RestMethod 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id' -Method Post -Headers @{'Authorization'="Bearer $token"} -ContentType 'application/json; charset=utf-8' -Body $u -TimeoutSec 15|Out-Null}catch{Log "发消息失败: $_" 'Red'}}

function Get-Messages {
    $token=Token $dc;if(-not$token){return @()}
    try{
        $r=Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?container_id_type=chat&container_id=$ChatId&page_size=10&sort_type=ByCreateTimeDesc" -Method Get -Headers @{'Authorization'="Bearer $token"} -TimeoutSec 10
        if($r.code-ne0-or!$r.data.items){return @()}
        $msgs=@();$abotId="cli_aaad306c77b91bc3";$bbotId="cli_aaad323347a4dbc4";$dirId="cli_aaad7bd6d33a5bcf"
        foreach($item in $r.data.items){
            $isBot=$item.sender.sender_type -eq 'app'
            $senderId=$item.sender.id
            $isOurBot=$isBot -and ($senderId -eq $abotId -or $senderId -eq $bbotId -or $senderId -eq $dirId)
            $content=$item.body.content
            try{$c=$content|ConvertFrom-Json;$content=$c.text}catch{}
            $msgs+=@{
                id=$item.message_id
                time=[long]$item.create_time
                text=$content
                isBot=$isOurBot
                senderType=$item.sender.sender_type
            }
        }
        return $msgs
    }catch{return @()}
}

# ===== 团队讨论函数 =====
function Start-TeamTask {
    param([string]$Task)
    $global:History=@()
    $DSys="你是张总，产品总监。你的团队：阿博（产品经理）、阿布（研发）。用户给了一个任务，你要：1)@阿博做产品分析 2)@阿布做技术评估 3)给用户总结。围绕用户任务。"
    $PSys="你是阿博，热情的产品经理。以'@张总'开头。针对用户任务做产品分析（用户需求、目标用户、市场机会、产品建议）。用表情符号。"
    $ESys="你是阿布，技术负责人。以'@张总'开头。针对用户任务做技术评估（可行性、成本、周期、技术方案）。不用表情。"

    function LLM { param($sys,$ctx,$name,$task,$role)
        try{$p="用户任务：$task`n`n$ctx`n`n$role($name)发言。针对任务直接分析，不要说需要更多信息。"
            $j=@{model='deepseek-chat';messages=@{role='system';content=$sys},@{role='user';content=$p};temperature=0.85;max_tokens=400}|ConvertTo-Json
            $w=New-Object System.Net.WebClient;$w.Encoding=[System.Text.Encoding]::UTF8
            $w.Headers.Add('Content-Type','application/json; charset=utf-8');$w.Headers.Add('Authorization',"Bearer $Key")
            $t=$w.UploadString('https://api.deepseek.com/v1/chat/completions','POST',$j)
            $r=$t|ConvertFrom-Json;$reply=$r.choices[0].message.content.Trim()
            return $reply}catch{return $null}}

    function Ctx { $r=$global:History|Select-Object -Last 20;if($r.Count-eq0){return ''};return ($r-join "`n")}

    Log "  → 收到任务: $Task" 'Cyan'

    # 张总
    $m=LLM -sys $DSys -ctx '' -name '张总' -task $Task -role '张总'
    if(!$m){$m="收到任务。@阿博 你先做产品分析。"}
    Send-Msg $dc $m;$global:History+="张总: $m";Start-Sleep 3

    # 阿博
    $m=LLM -sys $PSys -ctx (Ctx) -name '阿博' -task $Task -role '阿博'
    if(!$m){$m="@张总 用户需求分析如下🎯"}
    Send-Msg $pc $m;$global:History+="阿博: $m";Start-Sleep 3

    # 张总@阿布
    $m=LLM -sys $DSys -ctx (Ctx) -name '张总' -task $Task -role '张总'
    if(!$m){$m="@阿布 你做技术评估。"}
    Send-Msg $dc $m;$global:History+="张总: $m";Start-Sleep 3

    # 阿布
    $m=LLM -sys $ESys -ctx (Ctx) -name '阿布' -task $Task -role '阿布'
    if(!$m){$m="@张总 技术上可行。"}
    Send-Msg $ec $m;$global:History+="阿布: $m";Start-Sleep 3

    # 张总总结
    $m=LLM -sys $DSys -ctx (Ctx) -name '张总' -task $Task -role '张总'
    if(!$m){$m="【总结】产品分析：... 技术评估：... 建议：..."}
    Send-Msg $dc $m;$global:History+="张总: $m"
    Log "  ✅ 任务完成！" 'Green'
}

# ===== 主循环 =====
Log "==============================================" 'Yellow'
Log "  三 Agent 守护模式" 'Yellow'
Log "  张总 + 阿博(产品) + 阿布(技术)" 'Yellow'
Log "  群聊: $ChatId" 'Yellow'
Log "  按 Ctrl+C 停止" 'Yellow'
Log "==============================================" 'Yellow'
Log "⚠ 注意: 如果读消息失败，需要加 im:message.group_msg 权限" 'Red'
Log ""

$seen=@()
$pollCount=0

while($true){
    try{
        $msgs=Get-Messages
        if($msgs.Count -gt 0){
            # 找最新的非bot消息
            $userMsg=$msgs|Where-Object{-not$_.isBot -and $_.id -notin $seen}|Select-Object -First 1
            if($userMsg){
                $seen+=$userMsg.id
                $task=$userMsg.text
                Log "[新消息] 用户说: $task" 'Magenta'
                Start-TeamTask -Task $task
            }
        }
        $pollCount++
        if($pollCount % 20 -eq 0){Log "  轮询中... (已检查 $pollCount 次)" 'DarkGray'}
    }catch{Log "轮询异常: $_" 'Red'}
    Start-Sleep -Seconds 15
}
