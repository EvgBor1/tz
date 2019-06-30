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

        File LogsDirCreate
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = $LogsDir
        }

        Script Git
        {
            SetScript = {
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Downloading mini-git'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest $using:GitURL -OutFile "$using:WorkLocation\git.zip"

            }
            TestScript = {
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Checking mini-git...'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                if(Test-Path "$using:WorkLocation\git.zip")
                {
                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] Mini-git is presen'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
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
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Downloading scripts from github'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                Start-Process -FilePath "$using:Git" -ArgumentList "clone $using:ScrRepURL" -WorkingDirectory $using:WorkLocation -Wait -NoNewWindow -Verbose

            }
           TestScript = {
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Checking scripts directory'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                if (!(Test-Path "$using:ScrLocation\Config.ps1"))
                {
                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] Scripts directory does not contain the main script'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                    return $false
                }
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Scripts directory is OK!'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                return $true
            }
           GetScript = {

                return $true
           }
            DependsOn = @("[Archive]ArchiveExtract")
        }
        Script SiteRepInit
        {
            SetScript = {
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Downloading WebApp from github'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                Start-Process -FilePath "$using:Git" -ArgumentList "clone $using:SiteRepURL" -WorkingDirectory $using:WorkLocation -Wait -NoNewWindow -Verbose

            }
           TestScript = {
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Check WebApp from github'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                if(Test-Path "$using:SiteRepPath\Web.config")
                {

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] RepWebApp is OK'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                    return $true
                }
                else
                {

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] RepWebApp is not OK. Removing RepWebApp.'
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

        Script Install_FW_WMF
        {
            SetScript = {


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
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=" [Info] Installing .Net 4.5.2 from $BinPath. Executing $binpath /q /norestart."
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                Start-Process -FilePath $BinPath -ArgumentList "/q /norestart" -Wait -NoNewWindow
		 	    Sleep 5
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=" [Info] Installing WMF5.1 from $BinPath1. Executing $binpath1 /quiet /norestart."
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
		 	    Start-Process -FilePath "wusa.exe" -ArgumentList "$BinPath1 /quiet /norestart" -Wait -NoNewWindow
                Sleep 5
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=" [Warn] Setting DSCMachineStatus to reboot server after DSC run is completed."
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                $global:DSCMachineStatus = 1

            }

            TestScript = {


                [int]$NetBuildVersion = 379893

                if (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' | %{$_ -match 'Release'})
                {
                    [int]$CurrentRelease = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full').Release
                    if ($CurrentRelease -lt $NetBuildVersion)
                    {

                        $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                        $msg=" [Warn] Current .Net build version is less than 4.5.2 ($CurrentRelease)"
                        echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                        return $false
                    }
                    else
                    {
                        if (! (Get-Module xWebAdministration -ListAvailable))
                        {
                            Install-Module -Name xWebAdministration -Force
                            Install-Module -Name cNtfsAccessControl -Force

                            $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                            $msg=" [Info] Some modules were installed."
                            echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                        }
                        $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                        $msg=" [Info] Current .Net build version is the same as or higher than 4.5.2 ($CurrentRelease)"
                        echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                        return $true
                    }
                }
                else
                {

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=" [Warn] .Net build version not recognised."
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
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

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=" [Warn] .Net build version not recognised."
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                    return ".Net 4.5.2 not found"
                }
            }
        }
        Script CreateJob
        {
            SetScript = {
                try {
                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=" [Info] Creating scheduler task for New Configuration."
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                    $NewCfg=$using:ScrLocation+'\Config.ps1'
                    $NewCfgTime=((Get-Date).AddMinutes(5)).ToString()
                    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $NewCfg
                    $trigger =  New-ScheduledTaskTrigger -Once -At $NewCfgTime
                    $Principal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                    Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "ApplyNewConfig" -Description "Apply New DSC Configuration at Startup" -Principal $Principal
                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=" [Info] The new configuration is going to apply at "
                    echo $t$msg$NewCfgTime|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                }
                catch {
                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=" [Fatal] The task was not be creating"
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                }



            }

            TestScript = {
                $NewCfg=$using:ScrLocation+'\Config.ps1'
                if((Test-Path $NewCfg) -and (Get-Module xWebAdministration -ListAvailable) -and ("ApplyNewConfig" -notin (Get-ScheduledTask).TaskName)){
                    return $false
                }
                return $true
            }
            GetScript = {return $true}
            DependsOn = @("[Script]ScriptsInit","[Script]Install_FW_WMF")
        }

    }
}

try {
    $CurDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Info] Trying to apply a Init-Configuration."
    echo $t$msg|Out-File -FilePath "$CurDir\Log.log" -Append -Force -Encoding "UTF8"
    Config -OutputPath $env:SystemDrive\DSCconfig
    Set-DscLocalConfigurationManager -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose
    Start-DscConfiguration  -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose -Wait -Force
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Info] Init-Configuration was applyed succsessfully."
    echo $t$msg|Out-File -FilePath "$CurDir\Log.log" -Append -Force -Encoding "UTF8"
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Info] You can find  addition logs in C:\DevOpsTaskJuniorScripts\Logs\Log.log"
    echo $t$msg|Out-File -FilePath "$CurDir\Log.log" -Append -Force -Encoding "UTF8"
}
catch {
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Fatal] Init-Configuration was not applyed succsessfully."
    echo $t$msg|Out-File -FilePath "$CurDir\Log.log" -Append -Force -Encoding "UTF8"
}