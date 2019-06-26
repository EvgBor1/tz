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
    Import-DscResource -ModuleName xWebAdministration
    if (Get-Module xWebAdministration -ListAvailable)
    {          
        Write-Verbose "Module xWebAdministration was imported."
    }
    Node $ComputerName
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyAndAutoCorrect"
        }
        
        Script Install_Net_4.5.2
        {
            SetScript = {
                $SourceURI = "https://download.microsoft.com/download/B/4/1/B4119C11-0423-477B-80EE-7A474314B347/NDP452-KB2901954-Web.exe"
		 	   $SourceURIWMF = "https://go.microsoft.com/fwlink/?linkid=839516"
                $FileName = $SourceURI.Split('/')[-1]
                $BinPath = Join-Path $env:SystemRoot -ChildPath "Temp\$FileName"
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
                Sleep 5
                Start-Process -FilePath $BinPath -ArgumentList "/q /norestart" -Wait -NoNewWindow 
		 	    Sleep 5
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
                            Install-Module -Name xWebAdministration -Force -Verbose
							if(!(Test-Path "$using:ConfScriptLocation\tz\Config.ps1"))
							{
								Start-Process -FilePath "$using:ConfScriptLocation\tz\Config.ps1" -ArgumentList "-ConfAppName $AppName -ConfScriptLocation $ScriptLocation -ConfScriptsRepURL $ScriptsRepURL -OutputPath $env:SystemDrive:\DSCconfig" -Wait -NoNewWindow  
								Set-DscLocalConfigurationManager -ComputerName localhost -Path $env:SystemDrive\DSCconfig -Verbose
								Start-DscConfiguration  -ComputerName localhost -Path $env:SystemDrive:\DSCconfig -Verbose -Wait -Force
							}
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
            SetScript = {
                Set-Location $using:ConfScriptLocation
                Start-Process -FilePath "$using:ConfScriptLocation\Git\cmd\git.exe" -ArgumentList "clone $using:ConfScriptsRepURL" -Wait -NoNewWindow -Verbose
                
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
        if (Get-Module xWebAdministration -ListAvailable)
        {            
            xWebsite DefaultSite
            {
                Ensure = 'Present'
                Name = 'Default Web Site'
                State = 'Stopped'
                PhysicalPath = 'C:\inetpub\wwwroot'
                DependsOn = @('[WindowsFeature]IIS','[WindowsFeature]AspNet')
            }
            File demofolder
            {
                Ensure = 'Present'
                Type = 'Directory'
                DestinationPath = "C:\inetpub\wwwroot\$AppName"
            }
            File Indexfile
            {
                Ensure = 'Present'
                Type = 'file'
                DestinationPath = "C:\inetpub\wwwroot\$AppName\index.html"
                Contents = "<html>
                <header><title>This is Demo Website</title></header>
                <body>
                Welcome to DevopsGuru Channel
                </body>
                </html>"
            }
            xWebAppPool WebSiteAppPool
            {
                Ensure = "Present"
                State = "Started"
                Name = $AppName
            }
            xWebsite DemoWebSite
            {
                Ensure = 'Present'
                State = 'Started'
                Name = $AppName
                PhysicalPath = "C:\inetpub\wwwroot\$AppName"
            }
        }
    }
}