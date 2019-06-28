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
if($Msg -eq 'OK')
{
    $M=$JSON
    Write-Host "New"
}
else
{
    $M=$JSON1
    Write-Host "Update"
}
$Response=Invoke-RestMethod -Uri $Slack -Method Post -Body $M -ContentType "application/json"
if($Response -eq 'ok')
{
	#$Log.Info("Notification was coplited!")
    Write-Verbose "Notification was coplited!"
}
}
