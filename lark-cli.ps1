<#
.SYNOPSIS
  lark-cli 兼容工具 - 绕过 Windows 凭据 bug，使用 REST API 直调
#>
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$rem)

$BUILTIN=@{"abot"=@{id="cli_aaad306c77b91bc3";secret="34JhfWyRx1E7hZHjiABWrg7pao2Ri0J0"};"bbot"=@{id="cli_aaad323347a4dbc4";secret="UURsYT81a1bxNLq7uI6vfc72BdeKc0RB"};"director"=@{id="cli_aaad7bd6d33a5bcf";secret="XgwERkjh4KOfFd1pI6MydeSJOFpI0QGs"}}

function Token($n){try{$r=Invoke-RestMethod 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' -Method Post -Body (@{app_id=$BUILTIN[$n].id;app_secret=$BUILTIN[$n].secret}|ConvertTo-Json) -ContentType 'application/json' -TimeoutSec 10;$r.tenant_access_token}catch{$null}}

$p="director"
$cid="";$txt="";$ps="10";$dry=$false;$uid=""

$i=0;while($i-lt$rem.Count){$a=$rem[$i]
if($a-eq'--chat-id'-and$i+1-lt$rem.Count){$cid=$rem[$i+1];$i+=2;continue}
if($a-eq'--text'-and$i+1-lt$rem.Count){$txt=$rem[$i+1];$i+=2;continue}
if($a-eq'--user-id'-and$i+1-lt$rem.Count){$uid=$rem[$i+1];$i+=2;continue}
if($a-eq'--page-size'-and$i+1-lt$rem.Count){$ps=$rem[$i+1];$i+=2;continue}
if($a-eq'--dry-run'){$dry=$true;$i++;continue}
if($a-eq'--profile'-and$i+1-lt$rem.Count){$p=$rem[$i+1];$i+=2;continue}
if($a-eq'--as'){$i+=2;continue}
$i++}

$cmds=@();$i=0;while($i-lt$rem.Count){$a=$rem[$i]
if($a.StartsWith('--')){if($a-in@('--chat-id','--text','--user-id','--page-size','--profile','--as')){$i+=2}else{$i++};continue}
$cmds+=$a;$i++}

$c0=$cmds[0];$c1=if($cmds.Count-gt1){$cmds[1]}else{""}

switch($c0){
"profile"{$BUILTIN.Keys|ForEach-Object{[PSCustomObject]@{name=$_;appId=$BUILTIN[$_].id}}}
"auth"{[PSCustomObject]@{appId=$BUILTIN[$p].id;status=if(Token $p){'ready'}else{'error'};identity='bot'}}
"im"{$token=Token $p;if(-not$token){exit 1}
if($c1-eq'+messages-send'){$target=if($cid){$cid}else{$uid};$type=if($cid){'chat_id'}else{'user_id'}
$safe=$txt-replace'"','\"'-replace"`n",'\n'-replace"`r",'\r'
$body=@{receive_id=$target;msg_type='text';content='{"text":"'+$safe+'"}'}|ConvertTo-Json -Compress
Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=$type" -Method Post -Headers @{'Authorization'="Bearer $token"} -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 15|ConvertTo-Json}
if($c1-eq'+chat-messages-list'){Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?container_id_type=chat&container_id=$cid&page_size=$ps&sort_type=ByCreateTimeDesc" -Method Get -Headers @{'Authorization'="Bearer $token"} -TimeoutSec 15|ConvertTo-Json}}
"event"{if($c1-eq'consume'){Write-Host "轮询中 (Ctrl+C停止)" -ForegroundColor Yellow;$seen=@{}
while($true){$token=Token $p;if($token){try{$r=Invoke-RestMethod "https://open.feishu.cn/open-apis/im/v1/messages?container_id_type=chat&container_id=$cid&page_size=5&sort_type=ByCreateTimeDesc" -Method Get -Headers @{'Authorization'="Bearer $token"} -TimeoutSec 10
if($r.code-eq0-and$r.data.items){foreach($item in $r.data.items){if($item.message_id-notin$seen.Keys-and$item.sender.sender_type-ne'app'){$seen[$item.message_id]=$true
$c=$item.body.content;try{$c=($c|ConvertFrom-Json).text}catch{};Write-Host "$c" -ForegroundColor Cyan}}}}catch{}};Start-Sleep 15}}}
default{Write-Host "lark-cli.ps1 用法: profile list | auth status | im +messages-send --chat-id --text | im +chat-messages-list --chat-id"}
}