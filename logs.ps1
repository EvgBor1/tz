function LogMsg
{
  param(
    [string]$LogsDll = "C:\DevOpsTaskJuniorScripts\tz\log4net.dll",
    [string]$LogsDir = "C:\DevOpsTaskJuniorScripts\Logs",
    [string]$LogFile = $LogsDir + "\Log.log",
    [string]$Msg = "Hello!",
    [string]$MsgType = "Info"
  )

  try
  {
    if (Test-Path $LogsDll)
    {
      [void][Reflection.Assembly]::LoadFile($LogsDll);
      #[System.Reflection.Assembly]::UnsafeLoadFrom([System.IO.Directory]::$LogsDll);
      [log4net.LogManager]::ResetConfiguration();

      #Example of File Appender initialization
      $FileApndr = new-object log4net.Appender.FileAppender(([log4net.Layout.ILayout](new-object log4net.Layout.PatternLayout('[%date{yyyy-MM-dd HH:mm:ss.fff} (%utcdate{yyyy-MM-dd HH:mm:ss.fff})] [%level] [%message]%n')), $LogFile, $True));
      $FileApndr.Threshold = [log4net.Core.Level]::All;
      [log4net.Config.BasicConfigurator]::Configure($FileApndr);

      $Log = [log4net.LogManager]::GetLogger("root");
      switch ($MsgType)
      {
      "Fatal" {
        $Log.Fatal($Msg)
      }
      "Error" {
        $Log.Error($Msg)
      }
      "Warn"{
        $Log.Warn($Msg)
      }
      Default {
        $Log.Info($Msg)
      }
  }


    }
    else
    {
      Start-Transcript -Path $LogFile -Append
      Write-Host $Msg
      Write-Host "[FATAL] $LogsDll doesn't exist!!!"
      Stop-Transcript
    }
  }
  catch
  {
    Start-Transcript -Path $LogFile -Append
    Write-Host $Msg
    Write-Verbose "[FATAL] $LogsDll wasn't loaded!!!"
    Stop-Transcript
  }
}