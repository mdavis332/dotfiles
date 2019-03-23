# Function to extract our 7z download
function Expand-Archive([string]$Path, [string]$Destination, [switch]$RemoveSource) {
	$7z_Application = "C:\Program Files\7-Zip\7z.exe"
	$7z_Arguments = @(
		'x'							## eXtract files with full paths
		'-y'						## assume Yes on all queries
		"`"-o$($Destination)`""		## set Output directory
		"`"$($Path)`""				## <archive_name>
	)
	& $7z_Application $7z_Arguments
	If ($RemoveSource -and ($LASTEXITCODE -eq 0)) {
		Remove-Item -Path $Path -Force
	}
}

# Function to download latest release of Wsl-Terminal
# Borrowed from @MarkTiedemann and @f3l3gy, adapted for the Wsl-Terminal repo from goreliu
function Get-WslTerminalLatest {
	# Download latest dotnet/codeformatter release from github
	
	$latest = "https://api.github.com/repos/goreliu/wsl-terminal/releases/latest"

	Write-Host Determining latest release
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$latest_url = (Invoke-WebRequest -Uri $latest -UseBasicParsing | ConvertFrom-Json)[0].assets.browser_download_url | Where-Object { $_ -match '\.7z' -and $_ -notmatch 'tabbed' }

	$file = "wsl-terminal.7z"
	
	# Ensure in $HOME directory
	cd $env:USERPROFILE

	Write-Host Dowloading latest release

	# Do the actual downloading
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	Invoke-WebRequest $latest_url -OutFile $env:USERPROFILE\$file

	# Extract WSL terminal and remove after complete
	Get-ChildItem $file -Filter *.7z | ForEach-Object {
		Expand-Archive -Path $_.FullName -Destination $env:USERPROFILE -RemoveSource
	}
}

Get-WslTerminalLatest

# Add shortcut to desktop
$TargetFile = "$env:USERPROFILE\wsl-terminal\open-wsl.exe"
$ShortcutFile = "$env:USERPROFILE\Desktop\bash.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.TargetPath = $TargetFile
$Shortcut.Save()
