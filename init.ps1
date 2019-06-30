if ((Get-WindowsFeature -Name DSC-Service).InstallState -like 'Available'){Install-WindowsFeature DSC-Service}

Configuration Config
{
    param
    (
        [string]$ComputerName='localhost',
        [string]$AppName='DevOpsTaskJunior',
        [string]$WorkLocation=$env:SystemDrive+'\'+$AppName+'Scripts',
        [string]$ScrLocation=$WorkLocation+'\tz',
        [string]$ScrRepURL='https://github.com/EvgBor1/tz.git',
        [string]$SiteRepURL='https://github.com/EvgBor1/DevOpsTaskJunior.git',
        [string]$Git=$WorkLocation+"\Git\cmd\git.exe",
        [string]$GitURL='https://github.com/git-for-windows/git/releases/download/v2.22.0.windows.1/MinGit-2.22.0-64-bit.zip',
        [string]$SitesPath=$env:SystemDrive+'\WebSites',
        [string]$SitePath=$SitesPath+'\'+$AppName,
        [string]$TestSitePath=$SitesPath+'\Test',
        [string]$SiteRepPath=$WorkLocation+'\'+$AppName,
        [string]$LogsDll=$SrcLocation+'\log4net.dll',
        [string]$LogsDir=$WorkLocation+'\Logs',
        [string]$LogFile=$LogsDir+'\Log.log',
        [string]$Logs=$ScrLocation+'\logs.ps1'


    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration    
    Node $ComputerName
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyAndAutoCorrect"
        }
        File WorkLocationCreate
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = $WorkLocation
        }
        File SiteFolder
        {
			Ensure = 'Present'
			Type = 'Directory'
			DestinationPath = $SitePath
		}
        File TestSiteFolder
        {
			Ensure = 'Present'
			Type = 'Directory'
			DestinationPath = $TestSitePath
		}
        cNtfsPermissionEntry PermSetSite
        {
            Ensure = 'Present'
            Path = $SitePath
            Principal = 'BUILTIN\IIS_IUSRS'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = 'Modify'
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]SiteFolder'
        }
        cNtfsPermissionEntry PermSetTestSite
        {
            Ensure = 'Present'
            Path = $TestSitePath
            Principal = 'BUILTIN\IIS_IUSRS'
            AccessControlInformation = @(
                cNtfsAccessControlInformation
                {
                    AccessControlType = 'Allow'
                    FileSystemRights = 'Modify'
                    Inheritance = 'ThisFolderSubfoldersAndFiles'
                    NoPropagateInherit = $false
                }
            )
            DependsOn = '[File]TestSiteFolder'
        }

        File LogsDirCreate
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = $LogsDir
        }

        Script Git
        {
            SetScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }
                LogMsg -Msg "Downloading mini-git"
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest $using:GitURL -OutFile "$using:WorkLocation\git.zip"

            }
            TestScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }
                LogMsg -Msg "Checking mini-git..."
                if(Test-Path "$using:WorkLocation\git.zip")
                {
                    LogMsg -Msg "Mini-git is presen"
                    return $true
                }
                return $false
            }
            GetScript = {
                return $true
            }
            DependsOn = @("[File]WorkLocationCreate")
        }
        Archive ArchiveExtract
        {
          Ensure = "Present"
          Path = "$WorkLocation\git.zip"
          Destination = "$WorkLocation\Git"
          DependsOn = @("[Script]Git")
        }
        Script ScriptsInit
        {
            SetScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }
                LogMsg -Msg "Downloading scripts from github"
                Start-Process -FilePath "$using:Git" -ArgumentList "clone $using:ScrRepURL" -WorkingDirectory $using:WorkLocation -Wait -NoNewWindow -Verbose

            }
           TestScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }
                LogMsg -Msg "Checking scripts directory"
                if (Test-Path "$using:ScrLocation\Config.ps1")
                {
                    LogMsg -Msg "Scripts directory doesn't contain the main script"
                    return $true
                }
                return $false
            }
           GetScript = {

                return $true
           }
            DependsOn = @("[Archive]ArchiveExtract", "[File]WorkLocationCreate")
        }
        Script SiteRepInit
        {
            SetScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }
                LogMsg -Msg "Downloading WebApp from github"
                Start-Process -FilePath "$using:Git" -ArgumentList "clone $using:SiteRepURL" -WorkingDirectory $using:WorkLocation -Wait -NoNewWindow -Verbose

            }
           TestScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }
                LogMsg -Msg "Check WebApp from github"
                if(Test-Path "$using:SiteRepPath\Web.config")
                {
                    LogMsg -Msg "RepWebApp is OK"
                    return $true
                }
                else
                {
                    LogMsg -Msg "RepWebApp is not OK. Removing RepWebApp."
                    if(Test-Path $using:SiteRepPath)
                    {
                        Remove-Item $using:SiteRepPath -Force -Recurse
                    }
                    return $false
                }
            }
            GetScript={
                return $true
            }
            DependsOn = @("[Archive]ArchiveExtract", "[File]WorkLocationCreate")
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

        Script Install_FW_WMF
        {
            SetScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }

                $SourceURI = "https://download.microsoft.com/download/B/4/1/B4119C11-0423-477B-80EE-7A474314B347/NDP452-KB2901954-Web.exe"
		 	    $SourceURIWMF = "https://go.microsoft.com/fwlink/?linkid=839516"
                $BinPath = Join-Path $env:SystemRoot -ChildPath "Temp\fw452.exe"
		 	    $BinPath1 = Join-Path $env:SystemRoot -ChildPath "Temp\wmf.msu"

                if (!(Test-Path $BinPath))
                {
                    Invoke-Webrequest -Uri $SourceURI -OutFile $BinPath
                }
                if (!(Test-Path $BinPath1))
                {
                    Invoke-Webrequest -Uri $SourceURIWMF -OutFile $BinPath1
                }

                LogMsg -Msg "Installing .Net 4.5.2 from $BinPath"
                LogMsg -Msg "Executing $binpath /q /norestart"
                Start-Process -FilePath $BinPath -ArgumentList "/q /norestart" -Wait -NoNewWindow
		 	    Sleep 5
                LogMsg -Msg "Installing WMF5.1 from $BinPath1"
                LogMsg -Msg "Executing $binpath1 /quiet /norestart"
		 	    Start-Process -FilePath "wusa.exe" -ArgumentList "$BinPath1 /quiet /norestart" -Wait -NoNewWindow
                Sleep 5
                LogMsg -Msg "Setting DSCMachineStatus to reboot server after DSC run is completed" -MsgType "Warn"
                $global:DSCMachineStatus = 1

            }

           TestScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }

                [int]$NetBuildVersion = 379893

                if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' | %{$_ -match 'Release'})
                {
                    [int]$CurrentRelease = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
                    if ($CurrentRelease -lt $NetBuildVersion)
                    {
                        LogMsg -Msg "Current .Net build version is less than 4.5.2 ($CurrentRelease)" -MsgType "Warn"

                        return $false
                    }
                    else
                    {
                        if (! (Get-Module xWebAdministration -ListAvailable))
                        {
                            Install-Module -Name xWebAdministration -Force
                            Install-Module -Name cNtfsAccessControl -Force
                            LogMsg -Msg  "Some modules were installed."
                        }
                        LogMsg -Msg "Current .Net build version is the same as or higher than 4.5.2 ($CurrentRelease)"

                        return $true
                    }
                }
                else
                {
                    LogMsg -Msg ".Net build version not recognised" -MsgType "Warn"

                    return $false
                }
            }

        GetScript = {
                try
                {
                    . ($using:Logs)
                }
                catch
                {

                    Write-Host "[FATAL] Logs module Error!"
                    Write-Verbose $_.Exception.Message

                }
                if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' | %{$_ -match 'Release'})
                {
                    $NetBuildVersion =  (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
                    return $NetBuildVersion
                }
                else
                {
                    LogMsg -Msg ".Net build version not recognised" -MsgType "Warn"
                    return ".Net 4.5.2 not found"
                }
            }

        }
        Script CreateJob
        {
            SetScript = {
                $NewCfg=$using:ScrLocation+'\Config.ps1'
                if((Test-Path $NewCfg) -and (Get-Module xWebAdministration -ListAvailable))
                {
                    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $NewCfg
                    $trigger =  New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(5)).ToString()
                    $Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "ApplyNewConfig" -Description "Apply New DSC Configuration at Startup" -Principal $Principal
                    Write-Verbose "Setting DSCMachineStatus to reboot server after DSC run is completed"
                }

            }
            TestScript = { return ("ApplyNewConfig" -in (Get-ScheduledTask).TaskName) }
            GetScript = { $Result = Get-ScheduledTask|?{$_.TaskName -like "ApplyNewConfig"} }
            DependsOn = @("[Script]ScriptsInit","[Script]Install_FW_WMF")
        }

    }
}
Config -OutputPath $env:SystemDrive\DSCconfig
Set-DscLocalConfigurationManager -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose
Start-DscConfiguration  -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose -Wait -Force