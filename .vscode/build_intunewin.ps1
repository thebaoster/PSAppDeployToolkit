# Vars
. ".vscode\Global.ps1"

# intunewin
[string]$Uri = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master"
[string]$Exe = "IntuneWinAppUtil.exe"

# If C:\temp does not exist, create it
if (-not(Test-Path -Path $Env:Ctemp)) {
	New-Item -Path $Env:Ctemp -ItemType Directory -Force | Out-Null
}

# Source content prep tool
if (-not(Test-Path -Path "$env:ProgramData\$Exe")) {
	Invoke-WebRequest -Uri "$Uri/$Exe" -OutFile "$Env:Ctemp\$Exe"
}

# Execute content prep tool
$processOptions = @{
	FilePath     = "$Env:Ctemp\$Exe"
	ArgumentList = "-c ""$Cache"" -s ""$Cache\Deploy-Application.exe"" -o ""$env:TEMP"" -q"
	WindowStyle  = "Maximized"
	Wait         = $true
}
Start-Process @processOptions

# Rename and prepare for upload
Move-Item -Path "$env:TEMP\Deploy-Application.intunewin" -Destination "$Desktop\$Application.intunewin" -Force -Verbose
explorer $Desktop
