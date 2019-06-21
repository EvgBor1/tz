# This script installs IIS and the features required to

# run DevOps junior task

#

# * Make sure you run this script from a Powershel Admin Prompt!

# * Make sure Powershell Execution Policy is bypassed to run these scripts:

# * YOU MAY HAVE TO RUN THIS COMMAND PRIOR TO RUNNING THIS SCRIPT!



#Set-ExecutionPolicy Bypass -Scope Process



$Features = $null
$AppName = 'DevOpsJuniorTask'
$SiteFolder = 'C:\wwwroot\DevOpsJuniorTask'
$URL='https://github.com/TargetProcess/DevOpsTaskJunior/archive/master.zip'
$Output=$SiteFolder+"\master.zip"

Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip
{
    param([string]$zipfile, [string]$outpath)

    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}



$Features = "IIS-WebServerRole", "IIS-WebServer", "IIS-CommonHttpFeatures", "IIS-HttpErrors", "IIS-HttpRedirect", "IIS-ApplicationDevelopment", `

"NetFx4Extended-ASPNET45", "IIS-NetFxExtensibility45", "IIS-HealthAndDiagnostics", "IIS-HttpLogging", "IIS-LoggingLibraries", "IIS-RequestMonitor", `

"IIS-HttpTracing", "IIS-Security", "IIS-RequestFiltering", "IIS-Performance", "IIS-WebServerManagementTools", "IIS-IIS6ManagementCompatibility", `

"IIS-Metabase", "IIS-ManagementConsole", "IIS-BasicAuthentication", "IIS-WindowsAuthentication", "IIS-StaticContent", "IIS-DefaultDocument", `

"IIS-WebSockets", "IIS-ApplicationInit", "IIS-ISAPIExtensions", "IIS-ISAPIFilter", "IIS-HttpCompressionStatic", "IIS-ASPNET45"



$f = Get-WindowsOptionalFeature -Online | ?{($_.FeatureName -in $Features) -and ($_.state -eq "Disabled")}|Select-Object -Property FeatureName







foreach($ft in $f) {Enable-WindowsOptionalFeature -Online -FeatureName $ft.FeatureName}

New-Item $SiteFolder -ItemType Directory
$acl = Get-Acl $SiteFolder
$rule = New-Object  System.Security.Accesscontrol.FileSystemAccessRule("IIS_IUSRS","Write","Allow")
$acl.SetAccessRule($rule)
Set-Acl $SiteFolder $acl
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $Output
Unzip $Output $SiteFolder

$scriptBlock = {
    Import-Module WebAdministration
    New-Item –Path IIS:\AppPools\$using:AppName
    Set-ItemProperty -Path IIS:\AppPools\$using:AppName -Name managedRuntimeVersion -Value 'v4.0'
    #Remove-WebAppPool -Name $using:appPoolName
    New-Item –Path IIS:\Sites\$using:AppName  -bindings @{protocol="http";bindingInformation=":80:DevOpsJuniorTask" }
    Set-ItemProperty -Path IIS:\Sites\$using:AppName -Name physicalPath -Value $using:SiteFolder
    Set-ItemProperty -Path IIS:\Sites\$using:AppName -Name applicationPool -Value $using:AppName 
   
}

Invoke-Command –ComputerName $env:computername –ScriptBlock $scriptBlock
