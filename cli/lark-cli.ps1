<#
.SYNOPSIS
  lark-cli 兼容工具 - 绕过 Windows 凭据 bug，支持 AI 团队讨论
  用法: .\lark-cli.ps1 ai chat --chat-id oc_xxx --text "任务"
#>
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$rem)
$BUILTIN=@{"abot"=@{id="cli_aaad306c77b91bc3";secret="34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0"};"bbot"=@{id="cli_aaad323347a4dbc4";secret="UURsYT81a1bxNLq7uI6vfc72BdeKc0RB"};"director"=@{id="cli_aaad7bd6d33a5bcf";secret="XgwERkjh4KOfFd1pI6MydeSJOFpI0QGs"}}
function Token($n){try{$r=Invoke-RestMethod 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' -Method Post -Body (@{app_id=$BUILTIN[$n].id;app_secret=$BUILTIN[$n].secret}|ConvertTo-Json) -ContentType 'application/json' -TimeoutSec 10;$r.tenant_access_token}catch{$null}}
$p="director";$cid="";$txt="";$ps="10";$i=0
while($i-lt$rem.Count){$a=$rem[$i]
if($a-eq'--chat-id'-and$i+1-lt$rem.Count){$cid=$rem[$i+1];$i+=2;continue}
if($a-eq'--text'-and$i+1-lt$rem.Count){$txt=$rem[$i+1];$i+=2;continue}
if($a-eq'--page-size'-and$i+1-lt$rem.Count){$ps=$rem[$i+1];$i+=2;continue}
if($a-eq'--dry-run'){$i++;continue}
if($a-eq'--profile'-and$i+1-lt$rem.Count){$p=$rem[$i+1];$i+=2;continue}
if($a-eq'--as'){$i+=2;continue}
$i++}
$cmds=@();$i=0;while($i-lt$rem.Count){$a=$rem[$i]
if($a.StartsWith('--')){if($a-in@('--chat-id','--text','--page-size','--profile','--as')){$i+=2}else{$i++};continue}
$cmds+=$a;$i++}
$c0=$cmds[0];$c1=if($cmds.Count-gt1){$cmds[1]}else{""}
switch($c0){
"profile"{$BUILTIN.Keys|ForEach-Object{[PSCustomObject]@{name=$_;appId=$BUILTIN[$_].id}}}
"auth"{[PSCustomObject]@{appId=$BUILTIN[$p].id;status=if(Token $p){'ready'}else{'error'};identity='bot'}}
"im"{$token=Token $p;if(-not$token){exit 1}
if($c1-eq'+messages-send'){$target=$cid;$safe=$txt-replace'"','\"'-replace"`n",'\n'-replace"`r",'\r'
$body=@{receive_id=$target;msg_type='text';content='{"text":"'+$safe+'"}'}|ConvertTo-Json -Compress
Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id" -Method Post -Headers @{'Authorization'="Bearer $token"} -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 15|ConvertTo-Json}
if($c1-eq'+chat-messages-list'){Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?container_id_type=chat&container_id=$cid&page_size=$ps&sort_type=ByCreateTimeDesc" -Method Get -Headers @{'Authorization'="Bearer $token"} -TimeoutSec 15|ConvertTo-Json}}
"event"{if($c1-eq'consume'){Write-Host "轮询中 (Ctrl+C停止)" -ForegroundColor Yellow;$seen=@{};while($true){$token=Token $p
if($token){try{$r=Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?container_id_type=chat&container_id=$cid&page_size=5&sort_type=ByCreateTimeDesc" -Method Get -Headers @{'Authorization'="Bearer $token"} -TimeoutSec 10
if($r.code-eq0-and$r.data.items){foreach($item in $r.data.items){if($item.message_id-notin$seen.Keys-and$item.sender.sender_type-ne'app'){$seen[$item.message_id]=$true
$c=$item.body.content;try{$c=($c|ConvertFrom-Json).text}catch{};Write-Host "$c" -ForegroundColor Cyan}}}}catch{}};Start-Sleep 15}}}
"ai"{if($c1-eq'chat'){
if(-not$cid-or-not$txt){Write-Host "需要 --chat-id 和 --text";exit 1}
$key="sk-8dc66b7474cf4c19b3e77fb9bcedc92d"
$DSys="你是产品总监，团队决策者。流程：@产品经理做产品分析→@研发做技术评估→给总结。"
$PSys="你是产品经理，以@产品总监开头，分析需求、市场。用表情。"
$ESys="你是研发，以@产品总监开头，评估可行性、成本。不用表情。"
$H=@()
function CX{$r=$H|Select-Object -Last 20;if($r.Count-eq0){return ''};return ($r-join "`n")}
function AI($s,$n){try{$j=@{model='deepseek-chat';messages=@{role='system';content=$s},@{role='user';content="任务：$txt`n`n$(CX)`n`n$n发言。"};temperature=0.85;max_tokens=2000}|ConvertTo-Json
$w=New-Object System.Net.WebClient;$w.Encoding=[System.Text.Encoding]::UTF8;$w.Headers.Add('Content-Type','application/json; charset=utf-8');$w.Headers.Add('Authorization',"Bearer $key")
return ($w.UploadString('https://api.deepseek.com/v1/chat/completions','POST',$j)|ConvertFrom-Json).choices[0].message.content.Trim()}catch{return $null}}
Write-Host ">>> 团队讨论..." -ForegroundColor Yellow
$steps=@(@{pr='director';s=$DSys;n='产品总监';fb="收到。@产品经理 分析。"},@{pr='abot';s=$PSys;n='产品经理';fb="@产品总监 我来分析🎯"},@{pr='director';s=$DSys;n='产品总监';fb="@研发 评估。"},@{pr='bbot';s=$ESys;n='研发';fb="@产品总监 可行。"},@{pr='director';s=$DSys;n='产品总监';fb="总结。"})
foreach($s in $steps){$m=AI $s.s $s.n;if(-not$m){$m=$s.fb}
Write-Host "  $($s.n): $m"
$token=Token $s.pr;$safe=$m-replace'"','\"'-replace"`n",'\n'-replace"`r",'\r'
$body=@{receive_id=$cid;msg_type='text';content='{"text":"'+$safe+'"}'}|ConvertTo-Json -Compress
Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=chat_id" -Method Post -Headers @{'Authorization'="Bearer $token"} -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 15|Out-Null
$H+="$($s.n): $m";Start-Sleep 3}
Write-Host ">>> 完成！" -ForegroundColor Green}}
default{Write-Host "lark-cli.ps1 用法: profile list | auth status | im +messages-send --chat-id --text | im +chat-messages-list --chat-id | ai chat --chat-id --text '任务'"}
}