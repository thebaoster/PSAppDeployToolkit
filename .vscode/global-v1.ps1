Add-Type -AssemblyName System.Windows.Forms

# Prompt user to select a folder within .\build
$initialPath = Resolve-Path "C:\Users\bAoster\Documents\VSC\PSAppDeployToolkit\build\"
$folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
$folderBrowser.Description = "Select the folder inside 'build' to copy"
$folderBrowser.SelectedPath = $initialPath.Path

if ($folderBrowser.ShowDialog() -eq 'OK') {
    [string]$Toolkit = $folderBrowser.SelectedPath

    # Define other variables
    [string]$Desktop = [Environment]::GetFolderPath('DesktopDirectory')
    [string]$WDADesktop = "C:\Users\WDAGUtilityAccount\Desktop"
    [string]$Win32App = "$env:ProgramData\win32app"
    [string]$Env:Ctemp = "C:\temp"
    [string]$Application = "$(& git branch --show-current)"
    [string]$Cache = "$env:ProgramData\win32app\$Application"
    [string]$LogonCommand = "LogonCommand.ps1"

    # Cache resources
    Remove-Item -Path "$Win32App" -Recurse -Force -ErrorAction Ignore
    Copy-Item -Path "$Toolkit" -Destination "$Cache" -Recurse -Force -Verbose -ErrorAction Ignore
    explorer "$Cache"
} else {
    Write-Host "No folder was selected. Script terminated."
}