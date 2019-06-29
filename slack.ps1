function Slack-Notification
{
param([string]$Msg='OK')
$JSON = @"
{
"text":"Message from E. Borodin's script: Site is OK!"
}
"@
$JSON1 = @"
{
"text":"Message from E. Borodin's script: Site was updated!"
}
"@
$Slack="https://hooks.slack.com/services/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"
switch($Msg)
{
    'OK' {$M=$JSON}
    Default {$M=$JSON1}
}
$Response=Invoke-RestMethod -Uri $Slack -Method Post -Body $M -ContentType "application/json"
if($Response -eq 'ok')
{
    LogMsg -Msg "Notification was coplited!"
}
}
