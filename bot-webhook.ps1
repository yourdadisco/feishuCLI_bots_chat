<#
.SYNOPSIS
  Webhook 服务 - 接收飞书 @消息事件，触发三 Agent 讨论
.DESCRIPTION
  需要配合 ngrok 使用：
  1. 运行本脚本（启动 HTTP 服务在 8888 端口）
  2. 另开终端运行: ngrok http 8888
  3. 把 ngrok URL 配置到飞书开发者后台的「事件订阅」
  4. 在群里 @张总 + 你的需求，三 Agent 自动响应
#>

# ===== Bot 凭证 =====
$dc=@{AppId="cli_aaad7bd6d33a5bcf";AppSecret="XgwERkjh4KOfFd1pI6MydeSJOFpI0QGs"}
$pc=@{AppId="cli_aaad306c77b91bc3";AppSecret="34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0"}
$ec=@{AppId="cli_aaad323347a4dbc4";AppSecret="UURsYT81a1bxNLq7uI6vfc72BdeKc0RB"}
$ChatId="oc_88cdd7c54cf79fca0b959644630f9b6d"
$Key="sk-8dc66b7474cf4c19b3e77fb9bcedc92d"
$logFile=Join-Path $PSScriptRoot "bot-webhook.log"

# 已处理的消息 ID 去重
$processed=@()

function Log { param($m,$c="White")
    Add-Content $logFile "$(Get-Date -Format 'HH:mm:ss') $m" -Encoding UTF8
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" -ForegroundColor $c }

function Send-Msg { param($c,$t)
    try{$b=@{app_id=$c.AppId;app_secret=$c.AppSecret}|ConvertTo-Json
        $token=(Invoke-RestMethod 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' -Method Post -Body $b -ContentType 'application/json' -TimeoutSec 10).tenant_access_token
        if(!$token){return}
        $s=$t-replace '"','\"'-replace "`n",'\n'
        $body=@{receive_id=$ChatId;msg_type='text';content='{"text":"'+$s+'"}'}|ConvertTo-Json -Compress
        $u=[System.Text.Encoding]::UTF8.GetBytes($body)
        Invoke-RestMethod 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id' -Method Post -Headers @{'Authorization'="Bearer $token"} -ContentType 'application/json; charset=utf-8' -Body $u -TimeoutSec 15|Out-Null}catch{Log "发消息失败: $_" 'Red'}}

# ===== 团队讨论 =====
function Start-Team {
    param([string]$Task)
    if($Task -in $processed){Log "  已处理过，跳过: $Task" 'DarkGray';return}
    $processed+=$Task
    $global:History=@()
    $DSys="你是张总，产品总监。工作：1)@阿博做产品分析 2)@阿布做技术评估 3)给用户总结。围绕用户任务。"
    $PSys="你是阿博，热情产品经理。@张总开头。分析用户需求、市场机会。用表情。"
    $ESys="你是阿布，技术负责人。@张总开头。评估可行性、成本、周期。不用表情。"

    function LLM { param($sys,$ctx,$name,$task,$role)
        try{$p="用户任务：$task`n`n$ctx`n`n$role($name)发言。直接分析。"
            $j=@{model='deepseek-chat';messages=@{role='system';content=$sys},@{role='user';content=$p};temperature=0.85;max_tokens=400}|ConvertTo-Json
            $w=New-Object System.Net.WebClient;$w.Encoding=[System.Text.Encoding]::UTF8
            $w.Headers.Add('Content-Type','application/json; charset=utf-8');$w.Headers.Add('Authorization',"Bearer $Key")
            $t=$w.UploadString('https://api.deepseek.com/v1/chat/completions','POST',$j)
            return ($t|ConvertFrom-Json).choices[0].message.content.Trim()}catch{return $null}}
    function Ctx{$r=$global:History|Select-Object -Last 20;if($r.Count-eq0){return ''};return ($r-join "`n")}

    Log "  → 任务: $Task" 'Cyan'
    foreach($step in @(
        @{role='director';cfg=$dc;sys=$DSys;name='张总';extra='@阿博做产品分析';fallback="收到任务。@阿博 你先做产品分析。"}
        @{role='pm';cfg=$pc;sys=$PSys;name='阿博';extra='张总@了你，做产品分析';fallback="@张总 用户需求分析🎯"}
        @{role='director';cfg=$dc;sys=$DSys;name='张总';extra='@阿布做技术评估';fallback="@阿布 你做技术评估。"}
        @{role='engineer';cfg=$ec;sys=$ESys;name='阿布';extra='张总@了你，做技术评估';fallback="@张总 技术上可行。"}
        @{role='director';cfg=$dc;sys=$DSys;name='张总';extra='给出完整总结给用户';fallback="【总结】产品分析：... 技术评估：... 建议：..."}
    )){
        $m=LLM -sys $step.sys -ctx (Ctx) -name $step.name -task $Task -role $step.name
        if(!$m){$m=$step.fallback}
        Send-Msg $step.cfg $m
        $global:History+="$($step.name): $m"
        Start-Sleep -Seconds 3
    }
    Log "  ✅ 完成" 'Green'
}

# ===== HTTP 服务 =====
$port=8888
$listener=New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$port/")
$listener.Start()
Log "==============================================" 'Yellow'
Log "  Webhook 服务已启动" 'Yellow'
Log "  端口: $port" 'Yellow'
Log "  说明: 在另一终端运行 ngrok http $port" 'Yellow'
Log "  然后将 ngrok 地址配置到飞书开发者后台" 'Yellow'
Log "  按 Ctrl+C 停止" 'Yellow'
Log "==============================================" 'Yellow'

try{
    while($listener.IsListening){
        $ctx=$listener.GetContext()
        $req=$ctx.Request;$resp=$ctx.Response
        $body=New-Object System.IO.StreamReader($req.InputStream) -Property @{AutoFlush=$true}
        $json=$body.ReadToEnd();$body.Close()

        Log "  ← 收到请求: $($req.HttpMethod) $($req.Url.AbsolutePath)" 'DarkGray'

        try{
            $data=$json|ConvertFrom-Json
            # 飞书 URL 验证挑战
            if($data.challenge){
                $resp.StatusCode=200
                $resp.ContentType='application/json'
                $buffer=[System.Text.Encoding]::UTF8.GetBytes("{`"challenge`":`"$($data.challenge)`"}")
                $resp.OutputStream.Write($buffer,0,$buffer.Length)
                $resp.Close()
                Log "  ✓ URL 验证通过" 'Green'
                continue
            }
            # 处理消息事件
            if($data.header -and $data.header.event_type -eq 'im.message.receive_v1'){
                $event=$data.event
                $msgId=$event.message_id
                if($msgId -in $processed){$resp.Close();continue}
                $senderType=$event.sender.sender_type
                $chatType=$event.chat_type
                $content=$event.content
                try{$c=$content|ConvertFrom-Json;$content=$c.text}catch{}
                $senderId=$event.sender.sender_id.user_id
                # 只处理群聊中@机器人的消息
                if($chatType -eq 'group' -and $senderType -ne 'app'){
                    Log "  📩 @消息: $content" 'Magenta'
                    $processed+=$msgId
                    Start-Team -Task $content
                }
            }
        }catch{Log "  解析事件失败: $_" 'Red'}
        try{$resp.StatusCode=200;$resp.Close()}catch{}
    }
}finally{$listener.Stop()}
