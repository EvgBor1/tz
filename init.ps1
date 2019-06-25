param(
  [string]$AppName='Demo',
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

Configuration Config
{
    param
    (
        [string]$ComputerName='localhost',
        [string]$ConfAppName='WebSite',
        [string]$ConfScriptLocation="C:\WebSiteScripts\ScriptsDir",
        [string]$ConfScriptsRepURL='https://github.com/EvgBor1/tz.git',
        [string]$ConfGitURL='https://github.com/git-for-windows/git/releases/download/v2.22.0.windows.1/MinGit-2.22.0-64-bit.zip'

    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    #Import-DscResource -Module xWebAdministration
    Node $ComputerName
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
        }
 
        Script Install_Net_4.5.2
        {
            SetScript = {
                $SourceURI = "https://download.microsoft.com/download/B/4/1/B4119C11-0423-477B-80EE-7A474314B347/NDP452-KB2901954-Web.exe"
                $FileName = $SourceURI.Split('/')[-1]
                $BinPath = Join-Path $env:SystemRoot -ChildPath "Temp\$FileName"
 
                if (!(Test-Path $BinPath))
                {
                    Invoke-Webrequest -Uri $SourceURI -OutFile $BinPath
                }
 
                write-verbose "Installing .Net 4.5.2 from $BinPath"
                write-verbose "Executing $binpath /q /norestart"
                Sleep 5
                Start-Process -FilePath $BinPath -ArgumentList "/q /norestart" -Wait -NoNewWindow           
                Sleep 5
                Write-Verbose "Setting DSCMachineStatus to reboot server after DSC run is completed"
                $global:DSCMachineStatus = 1
            }
 
            TestScript = {
                [int]$NetBuildVersion = 379893
 
                if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' | %{$_ -match 'Release'})
                {
                    [int]$CurrentRelease = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
                    if ($CurrentRelease -lt $NetBuildVersion)
                    {
                        Write-Verbose "Current .Net build version is less than 4.5.2 ($CurrentRelease)"
                        return $false
                    }
                    else
                    {
                        Write-Verbose "Current .Net build version is the same as or higher than 4.5.2 ($CurrentRelease)"
                        return $true
                    }
                }
                else
                {
                    Write-Verbose ".Net build version not recognised"
                    return $false
                }
            }
 
            GetScript = {
                if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' | %{$_ -match 'Release'})
                {
                    $NetBuildVersion =  (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
                    return $NetBuildVersion
                }
                else
                {
                    Write-Verbose ".Net build version not recognised"
                    return ".Net 4.5.2 not found"
                }
            }
        }
        File DirectoryCreate
        {
            Ensure = "Present" 
            Type = "Directory"      
            DestinationPath = $ConfScriptLocation
        }

        File LogDirectoryCreate
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "$ConfScriptLocation\Logs"
        }

        Script Git
        {
            SetScript = {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest $using:ConfGitURL -OutFile "$using:ConfScriptLocation\git.zip"
            }
            TestScript = { Test-Path "$using:ConfScriptLocation\git.zip" }
            GetScript = { Test-Path "$using:ConfScriptLocation\git.zip" }
            DependsOn = @("[File]DirectoryCreate")
        }
        Archive ArchiveExtract
        {
          Ensure = "Present"
          Path = "$ConfScriptLocation\git.zip"
          Destination = "$ConfScriptLocation\Git"
          DependsOn = @("[Script]Git")
        }
        Script GitRepInit
        {
            SetScript = 
			{
				Start-Process "$using:ConfScriptLocation\Git\cmd\git.exe" -ArgumentList "clone $using:ConfScriptsRepURL" -Wait -Verbose
                Write-Verbose "Clone Rep"
            }
            TestScript = { Test-Path "$using:ConfScriptLocation\tz\script.ps1" }
            GetScript = { Test-Path "$using:ConfScriptLocation\tz\script.ps1" }
            DependsOn = @("[Archive]ArchiveExtract")
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
      # Website DefaultSite
      # {
      #     Ensure = 'Present'
      #     Name = 'Default Web Site'
      #     State = 'Stopped'
      #     PhysicalPath = 'C:\inetpub\wwwroot'
      #     DependsOn = @('[WindowsFeature]IIS','[WindowsFeature]AspNet')
      # }
      # File demofolder
      # {
      #     Ensure = 'Present'
      #     Type = 'Directory'
      #     DestinationPath = "C:\inetpub\wwwroot\$AppName"
      # }
      # File Indexfile
      # {
      #     Ensure = 'Present'
      #     Type = 'file'
      #     DestinationPath = "C:\inetpub\wwwroot\$AppName\index.html"
      #     Contents = "<html>
      #     <header><title>This is Demo Website</title></header>
      #     <body>
      #     Welcome to DevopsGuru Channel
      #     </body>
      #     </html>"
      # }
      # WebAppPool WebSiteAppPool
      # {
      #     Ensure = "Present"
      #     State = "Started"
      #     Name = $AppName
      # }
      # Website DemoWebSite
      # {
      #     Ensure = 'Present'
      #     State = 'Started'
      #     Name = $AppName
      #     PhysicalPath = "C:\inetpub\wwwroot\$AppName"
      # }


    }
}
Config -ConfAppName $AppName -ConfScriptLocation $ScriptLocation -OutputPath $env:SystemDrive:\DSCconfig
Set-DscLocalConfigurationManager -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose
Start-DscConfiguration  -ComputerName localhost -Path $env:SystemDrive:\DSCconfig -Verbose -Wait -Force


