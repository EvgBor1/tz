Configuration NewConfig
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
    Import-DscResource -ModuleName cNtfsAccessControl
    Import-DscResource -ModuleName xWebAdministration
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
        Script SiteRepUpdate
        {
            SetScript = {

                $WStatus=$using:WorkLocation+'\OK.txt'

                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Moving updates for testing.'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                Get-ChildItem $using:TestSitePath -Recurse| Remove-Item -Recurse -Force
                Sleep 10
                Copy-Item -Path "$using:SiteRepPath\*" -Destination $using:TestSitePath -Recurse -Force
                Sleep 10
                if (Test-Path $WStatus) {
                    Remove-Item $WStatus -Force
                }

            }
           TestScript = {
                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                $msg=' [Info] Existing updates.'
                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                if(Test-Path $using:SiteRepPath )
                {
                    Write-Verbose "Changing location"
                    Start-Process -FilePath $using:Git -ArgumentList "pull" -WorkingDirectory $using:SiteRepPath -Wait -NoNewWindow -Verbose
                    Start-Process -FilePath $using:Git -ArgumentList "log -1 --pretty=format:'%h'" -WorkingDirectory $using:SiteRepPath -Wait -NoNewWindow -Verbose -RedirectStandardOutput "$using:WorkLocation\New.txt"
                    if(Test-Path "$using:WorkLocation\Latest.txt")
                    {
                        $l=@(Get-Content "$using:WorkLocation\Latest.txt")
                        $n=@(Get-Content "$using:WorkLocation\New.txt")
                        if($l -ne $n)
                        {
                            Remove-Item "$using:WorkLocation\Latest.txt"
                            Move-Item -Path "$using:WorkLocation\New.txt" -Destination "$using:WorkLocation\Latest.txt"

                            return $false
                        }
                        else {
                            Remove-Item "$using:WorkLocation\New.txt"

                            return $true
                        }
                    }
                    else {

                        Move-Item -Path "$using:WorkLocation\New.txt" -Destination "$using:WorkLocation\Latest.txt"

                        return $false
                    }
                }
            }
            GetScript = {

                return $true
            }
            DependsOn = @("[Script]SiteRepInit")
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
			DependsOn = @('[WindowsFeature]AspNet')
		}
		xWebAppPool WebAppPool
		{
			Ensure = "Present"
			State = "Started"
			Name = $AppName
            DependsOn = @('[WindowsFeature]AspNet')
		}
		xWebsite WebSite
		{
			Ensure = 'Present'
			State = 'Started'
			Name = $AppName
            ApplicationPool = $AppName
			PhysicalPath = "$SitesPath\$AppName"
            DependsOn = @('[xWebAppPool]WebAppPool')
		}
        xWebAppPool TestWebAppPool
		{
			Ensure = "Present"
			State = "Started"
			Name = "Test$AppName"
            DependsOn = @('[WindowsFeature]IIS','[WindowsFeature]AspNet')
		}
		xWebsite TestWebSite
		{
			Ensure = 'Present'
			State = 'Started'
			Name = "Test$AppName"
            ApplicationPool = "Test$AppName"
			PhysicalPath = $TestSitePath
            BindingInfo = @(
            MSFT_xWebBindingInformation
            {
                Protocol              = 'HTTP'
                Port                  = '7777'
                IPAddress             = '*'
                HostName              = ''

            };
            )
            DependsOn = @('[xWebAppPool]TestWebAppPool')
		}
        Script CheckTestWebSite
        {
            SetScript = {


                $WConf="$using:TestSitePath\Web.config"
                if(Test-Path $WConf)
                {

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] Trying to fix test site.'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                    #Add automatic fix method here---------------------------------------------------------------
                    (Get-Content $WConf) -replace "<system.web.>","<system.web>" | out-file $WConf -Encoding utf8
                    (Get-Content $WConf) -replace "<system.web..>","<system.web>" | out-file $WConf -Encoding utf8
                    #--------------------------------------------------------------------------------------------
                }

            }
           TestScript = {


                $WStatus=$using:WorkLocation+'\OK.txt'
                $Slack=$using:SrcLocation+'\slack.ps1'
                try
                {

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] Trying to check test site.'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                    $response = Invoke-WebRequest -Uri "http://localhost:7777/" -UseBasicParsing -ErrorAction Stop
                    $StatusCode = $Response.StatusCode

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] Trying is completed succesfuly.'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"


                }
                catch
                {
                    $StatusCode = $_.Exception.Response.StatusCode.value__

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Warn] We have a problem with test web site.'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                }
                if ($StatusCode -eq 200)
                {
                    if(!(test-path $WStatus))
                    {

                        $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                        $msg=' [Info] Creating SiteStatusOK!'
                        echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                        New-Item $WStatus

                        $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                        $msg=' [Info] Copying to release.'
                        echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                        Get-ChildItem $using:SitePath| Remove-Item -Recurse -Force
                        Copy-Item -Path "$using:TestSitePath\*" -Destination $using:SitePath -Recurse -Force
                        try
                        {

                            $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                            $msg=' [Info] Trying to do notification to Slack.'
                            echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                            $JSON = @"
{
"text":"Message from E. Borodin's script: Site is OK!"
}
"@
                            $Slack="https://hooks.slack.com/services/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"
                            $Response=Invoke-RestMethod -Uri $Slack -Method Post -Body $JSON -ContentType "application/json"
                            if($Response -eq 'ok')
                            {
                                $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                                $msg=' [Info] Notification was coplited!'
                                echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                            }
                        }
                        catch {
                            #$Log.Fatal('Error while loading supporting PowerShell Scripts.')
                            #$Log.Fatal($_.Exception.Message)
                            $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                            $msg=' [Error] Notification Error!.'
                            echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                        }
                    }

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] Test site is OK!'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Info] Trying to check main site.'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                    try {
                        $response = Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing -ErrorAction Stop
                        $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                        $msg=' [Info] Trying completed successfully.'
                        echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                    }
                    catch {
                        $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                        $msg=' [Error] Main site has problems.'
                        echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                        Get-ChildItem $using:SitePath| Remove-Item -Recurse -Force
                        Copy-Item -Path "$using:TestSitePath\*" -Destination $using:SitePath -Recurse -Force
                        $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                        $msg=' [Info] Recovering of the main site completed successfully.'
                        echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"
                    }
                    return $true
                }
                else
                {
                    if(test-path $WStatus)
                    {
                        Remove-Item $WStatus -Force
                    }

                    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
                    $msg=' [Error] Site is not working!'
                    echo $t$msg|Out-File -FilePath $using:LogFile -Append -Force -Encoding "UTF8"

                    return $false
                }
            }
            GetScript = {

                    return $true
            }
            DependsOn = @('[xWebsite]TestWebSite','[xWebsite]WebSite')
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
    }
}
if("ApplyNewConfig" -in (Get-ScheduledTask).TaskName){
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Info] Unregistering scheduler task for New Configuration."
    echo $t$msg|Out-File -FilePath "C:\DevOpsTaskJuniorScripts\Logs\Log.log" -Append -Force -Encoding "UTF8"
    Unregister-ScheduledTask -TaskName "ApplyNewConfig" -Confirm:$false
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Info] Scheduler task was unregistered."
    echo $t$msg|Out-File -FilePath "C:\DevOpsTaskJuniorScripts\Logs\Log.log" -Append -Force -Encoding "UTF8"
}
try {
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Info] Trying to apply a New Configuration."
    echo $t$msg|Out-File -FilePath "C:\DevOpsTaskJuniorScripts\Logs\Log.log" -Append -Force -Encoding "UTF8"
    NewConfig -ComputerName 'localhost' -OutputPath $env:SystemDrive\DSCconfig -Verbose
    Set-DscLocalConfigurationManager -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose
    Start-DscConfiguration  -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose -Wait -Force
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Info] New Configuration was applyed succsessfully."
    echo $t$msg|Out-File -FilePath "C:\DevOpsTaskJuniorScripts\Logs\Log.log" -Append -Force -Encoding "UTF8"
}
catch {
    $t=(Get-Date -UFormat "%d/%m/%Y %T %Z").ToString()
    $msg=" [Fatal] New Configuration was not applyed succsessfully."
    echo $t$msg|Out-File -FilePath "C:\DevOpsTaskJuniorScripts\Logs\Log.log" -Append -Force -Encoding "UTF8"
}
