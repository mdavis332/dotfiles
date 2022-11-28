# Inspiration from 
# Silent Install 7-Zip
# http://www.7-zip.org/download.html
# https://forum.pulseway.com/topic/1939-install-7-zip-with-powershell/ 

# Check for admin rights
$wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$prp = new-object System.Security.Principal.WindowsPrincipal($wid)
$adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if (-not $prp.IsInRole($adm)) {
    throw "This script requires elevated rights to install software.. Please run from an elevated shell session."
}

# Check for 7z install
Write-Progress -Activity "Validating Dependencies" -Status "Checking for 7zip"
$7z_Application = get-command 7z.exe -ErrorAction SilentlyContinue | select-object -expandproperty Path
if ([string]::IsNullOrEmpty($7z_Application)) {   
    $7z_Application = "C:\Program Files\7-Zip\7z.exe"
}

if (-not (Test-Path $7z_Application)) {
    Write-Progress -Activity "Validating Dependencies" -Status "Installing 7zip"
    # Path for the workdir
    $workdir = "c:\installer\"

    # Check if work directory exists if not create it
    If (-not (Test-Path -Path $workdir -PathType Container)) { 
        New-Item -Path $workdir  -ItemType directory 
    }

    # Download the installer
    $source = "http://www.7-zip.org/a/7z1801-x64.msi"
    $destination = "$workdir\7-Zip.msi"

    Invoke-WebRequest $source -OutFile $destination 

    # Start the installation
    msiexec.exe /i "$workdir\7-Zip.msi" /qb
    # Wait XX Seconds for the installation to finish
    Start-Sleep -s 35

    # Remove the installer
    Remove-Item -Force $workdir\7*
    Write-Progress -Activity "Validating Dependencies" -Status "Installing 7zip" -Completed	
}
Write-Progress -Activity "Validating Dependencies" -Completed

# Download the font to use with WSL
Write-Progress -Activity "Download/install font"
$font_url = 'https://github.com/mdavis332/dotfiles/raw/wsl/Sauce%20Code%20Pro%20Nerd%20Font%20Complete%20Mono%20Windows%20Compatible.ttf'
$request = [System.Net.WebRequest]::Create($font_url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()
    if ($response.StatusCode -eq "OK") {
        $fontfile = $response.ResponseUri.LocalPath | Split-Path -Leaf
    }
    else {
        $fontfile = 'rename.ttf'
    }
$FontPath = "${env:USERPROFILE}\$fontfile"
Invoke-WebRequest $font_url -Outfile $FontPath
$FontFolder = (New-Object -ComObject Shell.Application).Namespace(0x14)
Get-ChildItem -Path $FontPath | ForEach-Object {
    if (-not(Test-Path "C:\Windows\Fonts\$($_.Name)")) {
        
        # Install font
        $FontFolder.CopyHere($FontPath,0x10)
    }
    else {
        Write-Output 'Font already installed'
    }
}
# Delete temporary copy of font
Remove-Item $FontPath

# config wsl env
$BashScript = Get-Content -Path '.\configure.sh' -Raw
#$BashParams = @('-c', '"$(curl -fsSL https://raw.githubusercontent.com/mdavis332/dotfiles/wsl/configure.sh)"')
$BashParams = @('-c', $BashScript)
& bash $BashParams
