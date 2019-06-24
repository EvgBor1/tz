Add-Type -AssemblyName System.IO.Compression.FileSystem
function Unzip{
    param([string]$zipfile, [string]$outpath)
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}

function DirInit{
  param([string]$dir)
  try{
    $Log.Info("Checking directories.")
    Write-Debug "Checking directories."
    if(!(Test-Path $dir)){
      New-Item $dir -ItemType Directory|Out-Null
      $Log.Info("Creating $dir.")
      Write-Debug "Creating $dir."
    }
    if(!(Test-Path "$dir\Latest")){
      New-Item "$dir\Latest" -ItemType Directory|Out-Null
      $Log.Info("Creating $dir\Latest.")
      Write-Debug "Creating $dir\Latest."
    }
    if(!(Test-Path "$dir\Previous")){
      New-Item "$dir\Previous" -ItemType Directory|Out-Null
      $Log.Info("Creating $dir\Previous.")
      Write-Debug "Creating $dir\Previous."
    }
    if(!(Test-Path "$dir\Tmp")){
      New-Item "$dir\Tmp" -ItemType Directory|Out-Null
      $Log.Info("Creating $dir\Tmp.")
      Write-Debug "Creating $dir\Tmp."

    }else{
      Get-ChildItem "$dir\Tmp" -Directory| Remove-Item -Recurse -Force
      $Log.Info("Removing all directories from $dir\Tmp.")
      Write-Debug "Removing all directories from $dir\Tmp."
    }
    $Log.Info("Checking directories was completed.")
    Write-Debug "Checking directories was completed."
  }
  catch {
    #Remove-Item $dir -Force -Recurse
    $Log.Fatal("Can't create directories.")
    $Log.Fatal($_.Exception.Message)
    Write-Debug "Can't create directories."
    Write-Debug $_.Exception.Message
    break
  }

}

function GetRelease{
  param([string]$lnk, [string]$file)
  if(Test-Path $file){
    Remove-Item $file
  }
  try {
    $Log.Info("Downloading File ...")
    Write-Debug "Downloading File ..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $lnk -OutFile $file
    $Log.Info("File was downloaded.")
    Write-Debug "File was downloaded."
  }
  catch {
    $Log.Fatal("Unable to download master.zip from $lnk.")
    $Log.Fatal($_.Exception.Message)
    Write-Debug "Unable to download master.zip from $lnk."
    Write-Debug $_.Exception.Message
    break
  }
}

function ReplaceRelease{
  $Log.Info("Trying to replace release")
  Write-Debug "Trying to replace release"
  try{   
    Unzip $Release $Tmp
  }
  catch{
    $Log.Info("Problems unzipping.Script was ended.")
    Write-Debug "Problems unzipping.Script was ended."
    Write-Debug $_.Exception.Message
    Get-ChildItem $Tmp -Directory| Remove-Item -Recurse
    Remove-Item $Release    
    $Log.Fatal("Problems unzipping.Script was ended.")
    $Log.Fatal($_.Exception.Message)
    break
  }
  try{
    $Log.Info("Moving release.")
    Write-Debug "Moving release."
    Get-ChildItem $Previous|Remove-Item -Recurse -Force -ErrorAction Stop
    Start-Sleep -s 10
    Get-ChildItem $Latest | Copy-Item -Destination $Previous -Force -Recurse -ErrorAction Stop
    $acl = Get-Acl $Previous
    $rule = New-Object  System.Security.Accesscontrol.FileSystemAccessRule("IIS_IUSRS","Write","Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $Previous $acl
    Start-Sleep -s 10
    Set-ItemProperty -Path IIS:\Sites\$AppName -Name physicalPath -Value $Previous|Out-Null
    (Get-Item –Path IIS:\AppPools\$AppName).Recycle()
    Start-Sleep -s 10
    Get-ChildItem $Latest|Remove-Item -Recurse -Force -ErrorAction Stop
    Start-Sleep -s 10
    Get-ChildItem (Get-ChildItem $Tmp -Directory).FullName | Move-Item -Destination $Latest -Force -ErrorAction Stop
    $Log.Info("Giving access.")
    Write-Debug "Giving access."
    $acl = Get-Acl $Latest
    $rule = New-Object  System.Security.Accesscontrol.FileSystemAccessRule("IIS_IUSRS","Write","Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $Latest $acl
    Start-Sleep -s 10
    Set-ItemProperty -Path IIS:\Sites\$AppName -Name physicalPath -Value $Latest|Out-Null
    Get-ChildItem $Tmp -Directory| Remove-Item -Recurse -Force
    if(Test-Path $OldRelease){Remove-Item $OldRelease -Force}
    Rename-Item -Path $Release -NewName $OldRelease -Force
    $Log.Info("Release was replaced.")
    Write-Debug "Release was replaced."
  }
  catch{
    $Log.Fatal("Release was not replaced.")
    $Log.Fatal($_.Exception.Message)
    Write-Debug "Release was not replaced."
    Write-Debug $_.Exception.Message
    break
  }
}