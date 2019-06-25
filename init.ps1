param(
  [string]$AppNAme='WebSite',
  [string]$ScriptLocation=$env:SystemDrive+'\'+$AppName+'Scripts',
  [string]$ScriptsRepURL='https://github.com/EvgBor1/tz.git',
  [string]$GitURL='https://github.com/git-for-windows/git/releases/download/v2.22.0.windows.1/MinGit-2.22.0-64-bit.zip'
)

if ((Get-WindowsFeature -Name DSC-Service).InstallState -like 'Available'){Install-WindowsFeature DSC-Service}
if(!(Test-Path $ScriptLocation)){
  try{
    New-Item $ScriptLocation -ItemType Directory|Out-Null
    Sleep 1
    Set-Location $ScriptLocation
  }
  catch{
    Write-Host "Cuoldn't create $ScriptLocation"
    break
  }
}

Configuration ScriptsDir
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module WebAdministration
    Node "localhost"
    {
        File DirectoryCreate
        {
            Ensure = "Present" 
            Type = "Directory"      
            DestinationPath = $ScriptLocation
        }

        File LogDirectoryCreate
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "$ScriptLocation\Logs"
        }

        Script Git
        {
            SetScript = {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest $using:GitURL -OutFile "$using:ScriptLocation\git.zip"
            }
            TestScript = { Test-Path "$using:ScriptLocation\git.zip" }
            GetScript = { Test-Path "$using:ScriptLocation\git.zip" }
            DependsOn = @("[File]DirectoryCreate")
        }
        Archive ArchiveExample
        {
          Ensure = "Present"
          Path = "$ScriptLocation\git.zip"
          Destination = "$ScriptLocation\Git"
          DependsOn = @("[Script]Git")
        }
        WindowsFeature IIS
        {
            Ensure = "Present"
            Name   = "Web-Server"
        }
        WindowsFeature AspNet
        {
            Ensure = 'Present'
            Name = 'Web-Asp-Net45'
            DependsOn = @('[WindowsFeature]IIS')
        }
        Service WebServer
        {
            Name        = "W3SVC"
            StartupType = "Automatic"
            State       = "Running"
            DependsOn = @('[WindowsFeature]IIS')
        }

    }
}
ScriptsDir
Start-DscConfiguration -Path "$ScriptLocation\ScriptsDir" -Wait -Verbose
if(!(Test-Path "$ScriptLocation\tz\script.ps1")){
  Start-Process '.\Git\cmd\git.exe' -ArgumentList "clone $ScriptsRepURL" -Wait -NoNewWindow -Verbose
}



