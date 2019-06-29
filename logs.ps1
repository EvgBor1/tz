function LogMsg
{
  param(
    [string]$LogsDll = "C:\DevOpsTaskJuniorScripts\tz\log4net.dll",
    [string]$LogsDir = "C:\DevOpsTaskJuniorScripts\Logs",
    [string]$LogFile = $LogsDir + "Log.log",
    [string]$Msg = "Hello!"
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

      #Example of Colored Console Appender initialization
      $ColConsApndr = new-object log4net.Appender.ColoredConsoleAppender(([log4net.Layout.ILayout](new-object log4net.Layout.PatternLayout('[%date{yyyy-MM-dd HH:mm:ss.fff}] %message%n'))));
      $ColConsApndrDebugCollorScheme = new-object log4net.Appender.ColoredConsoleAppender+LevelColors; $ColConsApndrDebugCollorScheme.Level = [log4net.Core.Level]::Debug; $ColConsApndrDebugCollorScheme.ForeColor= [log4net.Appender.ColoredConsoleAppender+Colors]::Green;
      $ColConsApndr.AddMapping($ColConsApndrDebugCollorScheme);
      $ColConsApndrInfoCollorScheme = new-object log4net.Appender.ColoredConsoleAppender+LevelColors; $ColConsApndrInfoCollorScheme.level = [log4net.Core.Level]::Info; $ColConsApndrInfoCollorScheme.ForeColor= [log4net.Appender.ColoredConsoleAppender+Colors]::White;
      $ColConsApndr.AddMapping($ColConsApndrInfoCollorScheme);
      $ColConsApndrWarnCollorScheme = new-object log4net.Appender.ColoredConsoleAppender+LevelColors; $ColConsApndrWarnCollorScheme.level = [log4net.Core.Level]::Warn; $ColConsApndrWarnCollorScheme.ForeColor= [log4net.Appender.ColoredConsoleAppender+Colors]::Yellow;
      $ColConsApndr.AddMapping($ColConsApndrWarnCollorScheme);
      $ColConsApndrErrorCollorScheme = new-object log4net.Appender.ColoredConsoleAppender+LevelColors; $ColConsApndrErrorCollorScheme.level = [log4net.Core.Level]::Error; $ColConsApndrErrorCollorScheme.ForeColor= [log4net.Appender.ColoredConsoleAppender+Colors]::Red;
      $ColConsApndr.AddMapping($ColConsApndrErrorCollorScheme);
      $ColConsApndrFatalCollorScheme = new-object log4net.Appender.ColoredConsoleAppender+LevelColors; $ColConsApndrFatalCollorScheme.level = [log4net.Core.Level]::Fatal; $ColConsApndrFatalCollorScheme.ForeColor=([log4net.Appender.ColoredConsoleAppender+Colors]::HighIntensity -bxor [log4net.Appender.ColoredConsoleAppender+Colors]::Red);
      $ColConsApndr.AddMapping($ColConsApndrFatalCollorScheme);
      $ColConsApndr.ActivateOptions();
      $ColConsApndr.Threshold = [log4net.Core.Level]::All;
      [log4net.Config.BasicConfigurator]::Configure($ColConsApndr);

      $Log = [log4net.LogManager]::GetLogger("root");
      switch ($MsgType) {
      "Fatal" {
        $Log.Fatal($Msg)
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