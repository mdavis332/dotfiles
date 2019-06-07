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

Write-Progress -Activity "Ensure in `$HOME directory"
set-location $env:USERPROFILE

Write-Progress -Activity "Get bits for WSL terminal"
$file = "wsl-terminal.7z"
$latest = "https://api.github.com/repos/goreliu/wsl-terminal/releases/latest"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Borrowed from @MarkTiedemann and @f3l3gy, adapted for the Wsl-Terminal repo from goreliu
$latest_url = (Invoke-WebRequest -Uri $latest -UseBasicParsing | ConvertFrom-Json)[0].assets.browser_download_url | Where-Object { $_ -match '\.7z' -and $_ -notmatch 'tabbed' }
Invoke-WebRequest $latest_url -OutFile $env:USERPROFILE\$file

Write-Progress -Activity "Extract WSL terminal and remove after complete"
Get-Item $file | ForEach-Object {
    $7z_Arguments = @(
        'x'							## eXtract files with full paths
        '-y'						## assume Yes on all queries
        "`"-o$($env:USERPROFILE)`""		## set Output directory
        "`"$($_.FullName)`""				## <archive_name>
    )
    & $7z_Application $7z_Arguments
    If ($LASTEXITCODE -eq 0) {
        Remove-Item -Path $_.FullName -Force
    }
}

# WSL doesn't honor the chsh command. This function manually updates the wsl-terminal.conf to move from bash to zsh
Write-Progress -Activity "Update wsl-terminal.conf"
$WslConfPath = "$env:USERPROFILE\wsl-terminal\etc\wsl-terminal.conf"
(Get-Content $WslConfPath) |
    ForEach-Object { $_ -replace '^shell=/bin/bash', ';shell=/bin/bash' `
        -replace '^;shell=/bin/zsh', 'shell=/bin/zsh'
    } | Set-Content $WslConfPath

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

# Update minttyrc file with the font and theme to use
$MinttyrcPath = "$env:USERPROFILE\wsl-terminal\etc\minttyrc"   
(Get-Content $MinttyrcPath) |
    ForEach-Object { $_ -replace '^Font=.*$', 'Font=SauceCodePro NF' `
    -replace 'FontHeight=.*$', 'FontHeight=12' `
    } | Set-Content $MinttyrcPath

Add-Content -Path $MinttyrcPath -Value 'Transparency=medium'
Add-Content -Path $MinttyrcPath -Value 'OpaqueWhenFocused=yes'
Add-Content -Path $MinttyrcPath -Value 'RightClickAction=menu'
Add-Content -Path $MinttyrcPath -Value 'CopyOnSelect=yes'
Add-Content -Path $MinttyrcPath -Value 'AllowSetSelection=yes'
Add-Content -Path $MinttyrcPath -Value 'CtrlShiftShortcuts=yes'

Write-Progress -Activity "Ensure symlink exists"
$symlink = "$env:USERPROFILE\Desktop\wsl.lnk"
If (-not (Test-Path -Path $symlink)) {
    New-Item -ItemType SymbolicLink -Path "$env:USERPROFILE\Desktop\" -Name "wsl.lnk" -Value "$env:USERPROFILE\wsl-terminal\open-wsl.exe" 
}

$BashParams = @('-c', '"$(curl -fsSL https://raw.githubusercontent.com/mdavis332/dotfiles/wsl/configure.sh)"')
& bash $BashParams
