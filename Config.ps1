Configuration NewConfig{
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
        [string]$LogsDll=$WorkLocation+"\tz\log4net.dll",
        [string]$LogsDir=$WorkLocation+"\Logs",
        [string]$LogFile=$LogsDir+"Log.log"
        

    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName cNtfsAccessControl
    Import-DscResource -ModuleName xWebAdministration
    Node $ComputerName
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyAndAutoCorrect"
        }
        File DirectoryCreate
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = $WorkLocation
        }
        File SiteFolder
		{
			Ensure = 'Present'
			Type = 'Directory'
			DestinationPath = $SitesPath+'\'+$AppName
		}
        cNtfsPermissionEntry PermissionSet1
        {
            Ensure = 'Present'
            Path = $SitesPath+'\'+$AppName
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

        File LogDirectoryCreate
        {
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "$WorkLocation\Logs"
        }

        Script Git
        {
            SetScript = {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest $using:GitURL -OutFile "$using:WorkLocation\git.zip"
            }
            TestScript = { Test-Path "$using:WorkLocation\git.zip" }
            GetScript = { Test-Path "$using:WorkLocation\git.zip" }
            DependsOn = @("[File]DirectoryCreate")
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
                Set-Location $using:WorkLocation
                Start-Process -FilePath "$using:Git" -ArgumentList "clone $using:ScrRepURL" -Wait -NoNewWindow -Verbose
            }
            TestScript = { Test-Path "$using:ScrLocation\Config.ps1" }
            GetScript = { Test-Path "$using:ScrLocation\Config.ps1" }
            DependsOn = @("[Archive]ArchiveExtract")
        }
        Script SiteInit
        {
            SetScript = {
                Start-Process -FilePath "$using:Git" -ArgumentList "clone $using:SiteRepURL" -WorkingDirectory $using:SitesPath -Wait -NoNewWindow -Verbose
            }
            TestScript = {
                if(Test-Path "$using:SitePath\Web.config")
                {
                    return $true
                }
                else
                {
                    if(Test-Path $using:SitePath)
                    {
                        Remove-Item $using:SitePath -Force -Recurse
                    }
                    return $false
                }
            }
            GetScript={
                $WConf="$using:SitePath\Web.config"
                if(Test-Path $WConf)
                {
                    @{ Result = Get-Content $WConf }
                }
                else
                {
                    return "$WConf is not exist"
                }
            }
            DependsOn = @("[Archive]ArchiveExtract","[File]SiteFolder")
        }
        Script SiteUpdate
        {
            SetScript = {
                $Slack=$using:ScrLocation+'\slack.ps1'
                try
                {
                    $response = Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing -ErrorAction Stop
                    # This will only execute if the Invoke-WebRequest is successful.
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
                        catch {
                            #$Log.Fatal('Error while loading supporting PowerShell Scripts.')
                            #$Log.Fatal($_.Exception.Message)
                            Write-Verbose "Notification Error!"
                            Write-Verbose $_.Exception.Message
                        }
                }
                else
                {
                    #$Log.Info("Notification was coplited!")
                    Write-Verbose "New release has a problem!"
                }


            }
            TestScript = {                
                Write-Verbose "Testing updates."
                if(Test-Path $using:SitePath )
                {
                    Write-Verbose "Changing location"
                    Set-Location $using:SitePath
                    Start-Process -FilePath $using:Git -ArgumentList "pull" -WorkingDirectory $using:SitePath -Wait -NoNewWindow -Verbose
                    Start-Process -FilePath $using:Git -ArgumentList "log -1 --pretty=format:'%h'" -Wait -NoNewWindow -Verbose -RedirectStandardOutput "$using:SitesPath\New.txt"
                    if(Test-Path "$using:SitesPath\Latest.txt")
                    {
                        $l=@(Get-Content "$using:SitesPath\Latest.txt")
                        $n=@(Get-Content "$using:SitesPath\New.txt")
                        if($l -ne $n)
                        {
                            Remove-Item "$using:SitesPath\Latest.txt"
                            Move-Item -Path "$using:SitesPath\New.txt" -Destination "$using:SitesPath\Latest.txt"
                            return $false
                        }
                        else {
                            Remove-Item "$using:SitesPath\New.txt"
                            return $true
                        }
                    }
                    else {

                        Move-Item -Path "$using:SitesPath\New.txt" -Destination "$using:SitesPath\Latest.txt"
                        return $false
                    }
                }
            }
            GetScript = { @{ Result = (Get-Content "$using:SitePath\Web.config") }}
            DependsOn = @("[Archive]ArchiveExtract","[File]SiteFolder","[Script]SiteInit")
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

		xWebsite DefaultSite
		{
			Ensure = 'Present'
			Name = 'Default Web Site'
			State = 'Stopped'
			PhysicalPath = 'C:\inetpub\wwwroot'
			DependsOn = @('[WindowsFeature]IIS','[WindowsFeature]AspNet')
		}
		xWebAppPool WebAppPool
		{
			Ensure = "Present"
			State = "Started"
			Name = $AppName
		}
		xWebsite WebSite
		{
			Ensure = 'Present'
			State = 'Started'
			Name = $AppName
			PhysicalPath = "$SitesPath\$AppName"
		}
        Script CheckWebSite
        {
            SetScript={
                $WConf="$using:SitePath\Web.config"
                if(Test-Path $WConf)
                {
                    #Add automatic fix method here---------------------------------------------------------------
                    (Get-Content $WConf) -replace "<system.web.>","<system.web>" | out-file $WConf -Encoding utf8
                    #--------------------------------------------------------------------------------------------
                }
            }
            TestScript={
                $WStatus=$using:SitesPath+'\OK.txt'
                $Slack=$using:SrcLocation+'\slack.ps1'
                try
                {
                    Write-Verbose "Trying to check site!"
                    $response = Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing -ErrorAction Stop
                    $StatusCode = $Response.StatusCode
                    Write-Verbose "Trying is completed succesfuly."

                                        
                }
                catch
                {
                    $StatusCode = $_.Exception.Response.StatusCode.value__
                    Write-Verbose "Problem!"
                }
                if ($StatusCode -eq 200)
                {
                    if(!(test-path $WStatus))
                    {   
                        Write-Verbose "Create SiteStatusOK!"
                        New-Item $WStatus
                        try
                        {
                            Write-Verbose "Trying to do slack notification"
                            . ($Slack)
                            Slack-Notification 'UP'
                        }
                        catch {
                            #$Log.Fatal('Error while loading supporting PowerShell Scripts.')
                            #$Log.Fatal($_.Exception.Message)
                            Write-Verbose "Notification Error!"
                            Write-Verbose $_.Exception.Message
                        }
                    }
                    Write-Verbose "Site is OK!"
                    return $true
                }
                else
                {
                    if(test-path $WStatus)
                    {
                        Remove-Item $WStatus -Force
                    }
                    Write-Verbose "Site is not working!"
                    return $false
                }
            }
            GetScript={
                $WConf=$using:SitePath+'\Web.config'
                if(Test-Path $WConf)
                {
                    @{ Result = Get-Content $WConf }
                }
                else
                {
                    return "$WConf is not exist"
                }
            }
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

                write-verbose "Installing .Net 4.5.2 from $BinPath"
                write-verbose "Executing $binpath /q /norestart"
                Start-Process -FilePath $BinPath -ArgumentList "/q /norestart" -Wait -NoNewWindow
		 	    Sleep 5
                write-verbose "Installing WMF5.1 from $BinPath1"
                write-verbose "Executing $binpath1 /quiet /norestart"
		 	    Start-Process -FilePath "wusa.exe" -ArgumentList "$BinPath1 /quiet /norestart" -Wait -NoNewWindow
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
                        if (! (Get-Module xWebAdministration -ListAvailable))
                         {
                            Install-Module -Name xWebAdministration -Force
                            Install-Module -Name cNtfsAccessControl -Force
                            Write-Verbose "Some modules were installed."
                         }
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
    }
}
if("ApplyNewConfig" -in (Get-ScheduledTask).TaskName){Unregister-ScheduledTask -TaskName "ApplyNewConfig" -Confirm:$false}
NewConfig -ComputerName 'localhost' -OutputPath $env:SystemDrive\DSCconfig -Verbose
Set-DscLocalConfigurationManager -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose
Start-DscConfiguration  -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose -Wait -Force