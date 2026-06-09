param([string]$Task = "")
if (!$Task) { $Task = Read-Host "你的任务是什么" }

$logFile = Join-Path $PSScriptRoot "bot-team.log"
function Log { param($m,$c="White")
    Add-Content $logFile "$(Get-Date -Format 'HH:mm:ss') $m" -Encoding UTF8
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $m" -ForegroundColor $c }

$dc=@{AppId="cli_aaad7bd6d33a5bcf";AppSecret="XgwERkjh4KOfFd1pI6MydeSJOFpI0QGs"}
$pc=@{AppId="cli_aaad306c77b91bc3";AppSecret="34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0"}
$ec=@{AppId="cli_aaad323347a4dbc4";AppSecret="UURsYT81a1bxNLq7uI6vfc72BdeKc0RB"}
$ChatId="oc_88cdd7c54cf79fca0b959644630f9b6d";$Key="sk-8dc66b7474cf4c19b3e77fb9bcedc92d"

function Token { param($c)
    try{$r=Invoke-RestMethod 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' -Method Post -Body (@{app_id=$c.AppId;app_secret=$c.AppSecret}|ConvertTo-Json) -ContentType 'application/json' -TimeoutSec 10;$r.tenant_access_token}catch{$null}}

function Send { param($c,$t)
    $token=Token $c;if(-not$token){return}
    try{$s=$t-replace '"','\"'-replace "`n",'\n'
        $b=@{receive_id=$ChatId;msg_type='text';content='{"text":"'+$s+'"}'}|ConvertTo-Json -Compress
        $u=[System.Text.Encoding]::UTF8.GetBytes($b)
        Invoke-RestMethod 'https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id' -Method Post -Headers @{'Authorization'="Bearer $token"} -ContentType 'application/json; charset=utf-8' -Body $u -TimeoutSec 15|Out-Null}catch{}}

function Ctx { param($n=20)
    $r=$global:History|Select-Object -Last $n;if($r.Count-eq0){return ''};return ($r-join "`n")}

function LLM { param($sys,$ctx,$name,$task,$role)
    try{$p="用户的任务是：$task`n`n$ctx`n`n现在$role($name)发言。请针对用户的任务直接发言，不要说'需要更多信息'，直接基于已知信息给出专业分析。"
        $j=@{model='deepseek-chat';messages=@{role='system';content=$sys},@{role='user';content=$p};temperature=0.85;max_tokens=400}|ConvertTo-Json
        $w=New-Object System.Net.WebClient;$w.Encoding=[System.Text.Encoding]::UTF8
        $w.Headers.Add('Content-Type','application/json; charset=utf-8');$w.Headers.Add('Authorization',"Bearer $Key")
        $t=$w.UploadString('https://api.deepseek.com/v1/chat/completions','POST',$j)
        $r=$t|ConvertFrom-Json;$reply=$r.choices[0].message.content.Trim()
        return $reply}catch{Log "LLM Error: $_" 'Red';return $null}}

$global:History=@()

# ===== 极简人设 - 直接告诉 AI 该做什么 =====
$DSys="你是张总，产品总监。你的团队：阿博（产品经理）、阿布（研发）。
工作流程：用户给了一个具体任务。
第1步：回复'收到任务。@阿博 你先做产品分析。'
第2步：等阿博回复后，回复'@阿布 你做技术评估。'
第3步：等阿布回复后，给用户一份完整总结。
全程围绕用户的任务，不要说'需要更多信息'。每条消息开头的@人。"

$PSys="你是阿博，产品经理。以'@张总'开头说话。用户有一个具体任务，张总@了你。你的工作：针对用户任务做产品分析（用户需求、目标用户、市场机会、产品建议）。用表情符号。直接分析，不要问问题。"

$ESys="你是阿布，技术负责人。以'@张总'开头说话。用户有一个具体任务，张总@了你。你的工作：针对用户任务做技术评估（可行性、开发周期、技术方案建议）。不用表情符号。直接评估，不要问问题。"

# ===== 执行 =====
Log "======= 任务: $Task =======" 'Yellow'

# 1. 张总
Log "张总思考..." 'DarkGray'
$m=LLM -sys $DSys -ctx '' -name '张总' -task $Task -role '张总'
if(!$m){$m="收到任务。@阿博 你先做产品分析，分析用户需求、目标用户和市场机会。"}
Log "张总: $m" 'Yellow';Send $dc $m;$global:History+="张总: $m";Start-Sleep 4

# 2. 阿博
Log "阿博思考..." 'DarkGray'
$m=LLM -sys $PSys -ctx (Ctx) -name '阿博' -task $Task -role '阿博'
if(!$m){$m="@张总 用户需求是$Task，核心用户是中小电商，市场机会很大🎯"}
Log "阿博: $m" 'Cyan';Send $pc $m;$global:History+="阿博: $m";Start-Sleep 4

# 3. 张总@阿布
Log "张总思考..." 'DarkGray'
$m=LLM -sys $DSys -ctx (Ctx) -name '张总' -task $Task -role '张总'
if(!$m){$m="@阿布 你做技术评估，评估可行性、开发周期和成本。"}
Log "张总: $m" 'Yellow';Send $dc $m;$global:History+="张总: $m";Start-Sleep 4

# 4. 阿布
Log "阿布思考..." 'DarkGray'
$m=LLM -sys $ESys -ctx (Ctx) -name '阿布' -task $Task -role '阿布'
if(!$m){$m="@张总 技术上可行，预估周期3个月，建议用微服务架构。"}
Log "阿布: $m" 'Green';Send $ec $m;$global:History+="阿布: $m";Start-Sleep 4

# 5. 张总总结
Log "张总总结..." 'DarkGray'
$m=LLM -sys $DSys -ctx (Ctx) -name '张总' -task $Task -role '张总'
if(!$m){$m="【总结】产品分析：... 技术评估：... 建议：..."}
Log "张总: $m" 'Yellow';Send $dc $m;$global:History+="张总: $m"

Log "✅ 任务完成！" 'Green'