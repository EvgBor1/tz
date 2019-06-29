try
{
    . ($using:Logs)
}
catch
{
    Start-Transcript -Path $LogFile -Append
    Write-Host "[FATAL] Logs module Error!"
    Write-Verbose $_.Exception.Message
    Stop-Transcript
}

                $Slack=$using:ScrLocation+'\slack.ps1'
                try
                {
                    $response = Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing -ErrorAction Stop

                    $StatusCode = $Response.StatusCode
                }
                catch
                {
                    $StatusCode = $_.Exception.Response.StatusCode.value__
                }
                if ($StatusCode -eq 200)
                {
                    try
                    {
                        . ($Slack)
                        Slack-Notification
                    }
                    catch
                    {
                        Write-Verbose "Notification Error!"
                        Write-Verbose $_.Exception.Message
                    }
                }
                else
                {
                    #$Log.Info("Notification was coplited!")
                    Write-Verbose "New release has a problem!"
                }



Remove-Item $WStatus -Force