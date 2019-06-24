# E_Borodin
# ver 1.0
# * Make sure you run this script from a Powershel Admin Prompt!
# * Make sure Powershell Execution Policy is bypassed to run these scripts:
# * YOU MAY HAVE TO RUN THIS COMMAND PRIOR TO RUNNING THIS SCRIPT!
#Set-ExecutionPolicy Bypass -Scope Process

#Classical Debuggin mode
#$DebugPreference = "Continue"

# Variables

$Features = "IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures", "IIS-HttpErrors", "IIS-HttpRedirect", "IIS-ApplicationDevelopment", `
  "NetFx4Extended-ASPNET45", "IIS-NetFxExtensibility45", "IIS-HealthAndDiagnostics", "IIS-HttpLogging", "IIS-LoggingLibraries", "IIS-RequestMonitor", `
  "IIS-HttpTracing", "IIS-Security", "IIS-RequestFiltering", "IIS-Performance", "IIS-WebServerManagementTools", "IIS-IIS6ManagementCompatibility", `
  "IIS-Metabase", "IIS-ManagementConsole", "IIS-BasicAuthentication", "IIS-WindowsAuthentication", "IIS-StaticContent", "IIS-DefaultDocument", `
  "IIS-WebSockets", "IIS-ApplicationInit", "IIS-ISAPIExtensions", "IIS-ISAPIFilter", "IIS-HttpCompressionStatic", "IIS-ASPNET45"
$AppName = 'DevOpsJuniorTask'
$SiteIP='127.0.0.1'
$DiskDrive = 'C'
$SiteFolder = $DiskDrive + ':\' + $AppName
$URL='https://github.com/TargetProcess/DevOpsTaskJunior/archive/master.zip'
$Tmp=$SiteFolder+"\Tmp"
$Latest=$SiteFolder+"\Latest"
$Previous=$SiteFolder+"\Previous"
$Release=$Tmp+"\master.zip"
$OldRelease=$Tmp+"\master.old"
$WConf= "$Latest\Web.config"
$Hosts="C:\Windows\System32\drivers\etc\hosts"

$JSON = @'
{"text":"Message from E. Borodin's script: Site is OK!"
}
'@
$Slack="https://hooks.slack.com/services/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"

$ScriptDirectory = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
if(!(Test-Path "$ScriptDirectory\Logs")){
  New-Item "$ScriptDirectory\Logs" -ItemType Directory|Out-Null
  Write-Debug "Creating $ScriptDirectory\Logs."
}
$LogFile="$ScriptDirectory\Logs\LogOutput.log"

try {
  . ("$ScriptDirectory\logs.ps1")
  . ("$ScriptDirectory\files.ps1")
  . ("$ScriptDirectory\iis.ps1")
  . ("$ScriptDirectory\fix.ps1")    
}
catch {
  $Log.Fatal('Error while loading supporting PowerShell Scripts.')
  $Log.Fatal($_.Exception.Message)
  Write-Debug "Error while loading supporting PowerShell Scripts."
  Write-Debug $_.Exception.Message
  break
   
}
$StartScriptDate= (Get-Date -Format {yyyy-MM-dd HH:mm:ss.fff}) + "----- Starting script -----"
Write-Debug $StartScriptDate
$Log.Info("Starting script")
if((Get-PSDrive $DiskDrive).Free -lt 55000000){
  $Log.Fatal("Not enough disk space. Script was terminated.")
  Write-Debug "Not enough disk space. Script was terminated."
  Write-Debug (Get-Date) "----- Ending script -----"
  break
}
DirInit $SiteFolder
IISInit
Import-Module WebAdministration
SiteCreate $AppName
GetRelease $URL $Release

if(Test-Path $OldRelease){
  if ((Get-FileHash $OldRelease).Hash -ne (Get-FileHash $Release).Hash){
    Write-Debug "Releases aren't the same."
    $Log.Info("Releases aren't the same.")
    Remove-Item $OldRelease
    ReplaceRelease
    Rename-Item -Path $Release -NewName $OldRelease    
    
  }else{
    Write-Debug "No update required."
    $Log.Info("No update required.")
    Remove-Item $Release
  }
}else {
  ReplaceRelease
}

Start-Sleep -s 10
SiteCheck $AppName
$StartScriptDate = (Get-Date -Format {yyyy-MM-dd HH:mm:ss.fff}) + " ----- Ending script -----"
Write-Debug $StartScriptDate
$Log.Info("Ending script")
[log4net.LogManager]::ResetConfiguration();
