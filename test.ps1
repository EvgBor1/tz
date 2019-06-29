try
{
    Write-Verbose "Trying to do slack notification"
    . ( )
    Slack-Notification 'UP'
}
catch
{
    #$Log.Fatal('Error while loading supporting PowerShell Scripts.')
    #$Log.Fatal($_.Exception.Message)
    Write-Verbose "Notification Error!"
    Write-Verbose $_.Exception.Message
}