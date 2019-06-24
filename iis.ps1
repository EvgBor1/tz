function IISInit{
  try{
    $Log.Info("Installing lost features.")
    Write-Debug "Installing lost features."
    $f = Get-WindowsOptionalFeature -Online | ?{($_.FeatureName -in $Features) -and ($_.state -eq "Disabled")}|Select-Object -Property FeatureName
    foreach($ft in $f) {Enable-WindowsOptionalFeature -Online -FeatureName $ft.FeatureName|Out-Null}
  }
  catch{
    $Log.Fatal("Installing lost features.")
    $Log.Fatal($_.Exception.Message)
    Write-Debug "IIS Init fail."
    break
  }
  
}
function SiteCreate{
  param([string]$SiteName)
  $Log.Info("Starting initialization site.")
  Write-Debug "Starting initialization site."
  if (!(Test-Path –Path IIS:\AppPools\$SiteName)){
    try{
      New-Item –Path IIS:\AppPools\$SiteName|Out-Null
      Set-ItemProperty -Path IIS:\AppPools\$SiteName -Name managedRuntimeVersion -Value 'v4.0'|Out-Null
      $Log.Info("AppPool was created.")
      Write-Debug "AppPool was created."
    }
    catch{
      $Log.Fatal("Can't create AppPool.")
      $Log.Fatal($_.Exception.Message)
      break
    }
  }
  else{
    try{
      (Get-Item –Path IIS:\AppPools\$SiteName).Start() 
      Set-ItemProperty -Path IIS:\AppPools\$SiteName -Name managedRuntimeVersion -Value 'v4.0'|Out-Null 
    }
    catch{
      $Log.Fatal("Can't start AppPool.")
      $Log.Fatal($_.Exception.Message)
      break  
    }
  }
  if (!(Test-Path –Path IIS:\Sites\$SiteName)){
    try{
      New-Item –Path IIS:\Sites\$SiteName  -bindings @{protocol="http";bindingInformation=":80:$SiteName" }|Out-Null
      Set-ItemProperty -Path IIS:\Sites\$SiteName -Name physicalPath -Value $Latest|Out-Null
      Set-ItemProperty -Path IIS:\Sites\$SiteName -Name applicationPool -Value $SiteName|Out-Null
      $Log.Info("Site was created.")
      Write-Debug "Site was created."
    }
    catch{
      $Log.Fatal("Can't create Site.")
      $Log.Fatal($_.Exception.Message)
      break
    }
  }
  else{
    try{
      (Get-Item –Path IIS:\Sites\$SiteName).Start()
      Set-ItemProperty -Path IIS:\Sites\$SiteName -Name physicalPath -Value $Latest|Out-Null
      Set-ItemProperty -Path IIS:\Sites\$SiteName -Name applicationPool -Value $SiteName|Out-Null  
    }
    catch{
      $Log.Fatal("Can't start Site.")
      $Log.Fatal($_.Exception.Message)
      break  
    }
  }
}
function SiteCheck{
  param([string]$SiteName)
  $Log.Info("Trying to check site work.")
  Write-Debug "Trying to check site work."
  Start-Sleep -s 10
  try{
    if((Invoke-WebRequest "http://$SiteName").StatusCode -eq 200){
      $Log.Info("Site is OK!")
      Write-Debug "Site is OK!"
      $Response = Invoke-RestMethod -Uri $Slack -Method Post -Body $JSON -ContentType "application/json"
      if($Response -eq 'ok'){
        $Log.Info("Notification was coplited!")
        Write-Debug "Notification was coplited!"
      }
    }
    else{
      $Log.Warn("Site status is not OK.")
      Write-Debug "Site status is not OK."      
      FixRelease      
    }

  }
  catch{
    $Log.Warn("Site does not work.")
    Write-Debug "Site does not work."

    FixRelease
  }
}