function FixRelease{
  $Log.Info("Script is trying to fix.")
  $Log.Info("Checking $WConf")
  Write-Debug "Script is trying to fix."
  Write-Debug "Checking $WConf"
  if(Test-Path $WConf){
    (Get-Content $WConf) -replace "<system.web.>","<system.web>" | out-file $WConf -Encoding utf8
  }
  else{
    $Log.Info("$WConf does not exist. Repairing release.")
    Write-Debug "$WConf does not exist. Repairing release."
    DirInit $SiteFolder
    GetRelease $URL $Release
    ReplaceRelease
    (Get-Content $WConf) -replace "<system.web.>","<system.web>" | out-file $WConf -Encoding utf8
  }
  $Log.Info("Checking resolving site.")
  Write-Debug "Checking resolving site."
  try {
    Resolve-DNSName $AppName -ErrorAction Stop |Out-Null
  }
  catch {
    $Log.Warn("Resolwing has problem. Try to fix it via hosts-file.")
    Write-Debug "Resolwing has problem. Try to fix it via hosts-file."
    $lh=Get-Content $Hosts
    if($lh -notcontains [string]"$SiteIP  $AppName"){
      $lh=$lh+[string]"$SiteIP  $AppName" 
      Set-Content $Hosts $lh -Force
      $Log.Info("Resolving site was fixed.")
      Write-Debug "Resolving site was fixed."
    }
  }

  if((Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Release -lt 379893){
    $Log.Warn("Framework v.4.5.2 does not exist.")
    if(Test-Path "$ScriptDirectory\FW452.exe"){
      $Log.Info("Installing Framework v.4.5.2 and after that rebooting. Sorry! :)")
      Write-Debug "Installing Framework v.4.5.2 and after that rebooting. Sorry! :)"
      #Invoke-Command -ScriptBlock {"$ScriptDirectory\FW452.exe /q"}'
    }
    else{
      $Log.Info("Trying to download and install.")
      Write-Debug "Trying to download and install."
      #Invoke-WebRequest -Uri "https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe" -OutFile "$ScriptDirectory\FW452.exe"
      #$Log.Info("Installing Framework v.4.5.2 and after that rebooting. Sorry! :)")
      #Invoke-Command -ScriptBlock {"$ScriptDirectory\FW452.exe /q"}'
    }
  }
  try{
    $Log.Info("Trying to check site after fixing.")
    Write-Debug "Trying to check site after fixing."
    Start-Sleep -s 10
    if((Invoke-WebRequest "http://$AppName").StatusCode -eq 200){
      $Log.Info("Site is OK!")
      Write-Debug "Site is OK!"
      $Response = Invoke-RestMethod -Uri $Slack -Method Post -Body $JSON -ContentType "application/json"
      if($Response -eq 'ok'){
        $Log.Info("Notification was coplited!")
        Write-Debug "Notification was coplited!"
      }
    }
  }
  catch{
    $Log.Fatal("Fixing was not helped. Try to do it by yourself or start the script again.")
    $Log.Fatal($_.Exception.Message)
    Get-ChildItem $Latest|Remove-Item -Recurse
    Write-Debug "Fixing was not helped. Try to do it oneself."
    
    break
  }
}