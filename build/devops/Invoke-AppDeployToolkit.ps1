<#

.SYNOPSIS
PSAppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION
- The script is provided as a template to perform an install, uninstall, or repair of an application(s).
- The script either performs an "Install", "Uninstall", or "Repair" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script imports the PSAppDeployToolkit module which contains the logic and functions required to install or uninstall an application.

PSAppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2024 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham, Muhammad Mashwani, Mitch Richters, Dan Gough).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType
The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru
Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script. Default is: $false.

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeployMode Silent

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -AllowRebootPassThru

.EXAMPLE
powershell.exe -File Invoke-AppDeployToolkit.ps1 -DeploymentType Uninstall

.EXAMPLE
Invoke-AppDeployToolkit.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS
None. You cannot pipe objects to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Invoke-AppDeployToolkit.ps1, and Invoke-AppDeployToolkit.exe
- 69000 - 69999: Recommended for user customized exit codes in Invoke-AppDeployToolkit.ps1
- 70000 - 79999: Recommended for user customized exit codes in PSAppDeployToolkit.Extensions module.

.LINK
https://psappdeploytoolkit.com

#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType = 'Install',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [System.String]$DeployMode = 'Interactive',

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$AllowRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # TODO:<App-Var> App variables.
    AppVendor = 'Palo Alto'
    AppName = 'Global Protect - Repair'
    AppVersion = '6.2.7'
    AppArch = 'x64'
    AppLang = 'EN'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppScriptVersion = '1.0.0'
    AppScriptDate = '06/25/2025'
    AppScriptAuthor = 'bao nguyen'
    CompanyName = 'Plains'

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptVersion = '4.0.5'
    DeployAppScriptParameters = $PSBoundParameters
    }

    $envCompany = "$($envAllUsersProfile)\$($adtSession.CompanyName)"
    $envUTemp = "$($adtSession.LogTempFolder)\$($adtSession.LogName)"
    $envSTemp = "$($envWinDir)\Logs\Software\$($adtSession.LogName)"

function Install-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## TODO:<Install-Pre> Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
    #Show-ADTInstallationWelcome -CloseProcesses PANGPA.EXE, PANGPS.EXE -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt
    Show-ADTInstallationPrompt -Message 'To complete this fix, your VPN connection will be temporarily disconnected. Please save your work and close any sensitive applications before continuing. The VPN will reconnect automatically once the process is complete.' -ButtonRightText 'OK' -Icon Information


    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Installation tasks here>
    #Remove Palo Alto Networks from all user registry
    Invoke-ADTAllUsersRegistryAction {
        Remove-ADTRegistryKey -Key 'HKCU\SOFTWARE\Palo Alto Networks' -Recurse
    }
    #Remove Palo Alto Networks from all system registry
    Remove-ADTRegistryKey -Key 'HKLM\SOFTWARE\Palo Alto Networks' -Recurse

    #Uninstall all Global Protect
    Uninstall-ADTApplication -ApplicationType 'MSI' -FilterScript { $_.DisplayName -match 'GlobalProtect' } -Verbose

    #Copy Pala Alto Global Protect installer to Plains company folder.

    if (-not (Test-Path -Path "$($envCompany)\$($adtSession.AppVendor) $($adtSession.AppName)\$($adtSession.AppVersion)")){
    Copy-ADTFile -Path "$($adtSession.ScriptDirectory)\*" -Destination "$($envCompany)\$($adtSession.AppVendor) $($adtSession.AppName)\$($adtSession.AppVersion)\"
    }

    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI installations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
        if ($adtSession.DefaultMspFiles)
        {
            $adtSession.DefaultMspFiles | Start-ADTMsiProcess -Action Patch
        }
    }

    ## TODO:<Install-Start> <Perform Installation tasks here>
    #Install Global Protect
    Start-ADTMsiProcess -Action 'Install' -FilePath 'GlobalProtect64-6.2.7.msi' -ArgumentList '/QN /norestart portal=vpnportal.plains.com'

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## TODO :<Install-Post><Perform Post-Installation tasks here>

    #Create detection log
    if (!(Test-Path -Path "$($envAllUsersProfile)\$($adtSession.CompanyName)"))
    {
        New-Item -Path "$envCompany" -ItemType Directory -Force | Out-Null
        New-Item -Path "$($envCompany)\$($adtSession.AppVendor) $($adtSession.AppName)\$($adtSession.AppVersion)" -ItemType Directory -Force | Out-Null
        New-Item -Path "$($envCompany)\$($adtSession.AppVendor) $($adtSession.AppName)\$($adtSession.AppVersion)\detection.log" -ItemType File -Force | Out-Null
    }else {
        New-Item -Path "$($envCompany)\$($adtSession.AppVendor) $($adtSession.AppName)\$($adtSession.AppVersion)" -ItemType Directory -Force | Out-Null
        New-Item -Path "$($envCompany)\$($adtSession.AppVendor) $($adtSession.AppName)\$($adtSession.AppVersion)\detection.log" -ItemType File -Force | Out-Null
    }

    ## Copylog from the toolkit from the default log location to ProgramData\PSAppDeployToolkit\Logs.
    # Ensure the log directory exists
    if (!(Test-Path -Path "$envCompany\PSAppDeployToolkit\Logs"))
    {
        New-Item -Path "$($envCompany)\PSAppDeployToolkit\Logs" -ItemType Directory -Force | Out-Null
    }

    # Determine source path and copy the log file
    if (Test-Path -Path $envUTemp)
    {
        Copy-ADTFile -Path "$envUTemp" -Destination "$($envCompany)\PSAppDeployToolkit\Logs"
    }
    else
    {
        Copy-ADTFile -Path "$envSTemp" -Destination "$($envCompany)\PSAppDeployToolkit\Logs"
    }

    ## Display a message at the end of the install.
    if (!$adtSession.UseDefaultMsi)
    {
        #Show-ADTInstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
    }
}

function Uninstall-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## TODO <Uninstall-Pre> Uninstall Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    Show-ADTInstallationWelcome -CloseProcesses iexplore -CloseProcessesCountdown 60

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Uninstallation tasks here>


    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI uninstallations.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## TODO:<Uninstall-Start> <Perform Uninstallation tasks here>


    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## TODO:<Uninstall-Post> <Perform Post-Uninstallation tasks here>
}

function Repair-ADTDeployment
{
    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## TODO:<Repair-Pre> Repair Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing.
    #Show-ADTInstallationWelcome -CustomText
    Show-ADTInstallationPrompt -Message 'To complete this fix, your VPN connection will be temporarily disconnected. Please save your work and close any sensitive applications before continuing. The VPN will reconnect automatically once the process is complete.' -ButtonRightText 'OK' -Icon Information -NoWait

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ## <Perform Pre-Repair tasks here>

    Invoke-ADTAllUsersRegistryAction {
        Remove-ADTRegistryKey -Key 'HKCU\SOFTWARE\Palo Alto Networks' -Recurse
    }
    #Remove Palo Alto Networks from all system registry
    Remove-ADTRegistryKey -Key 'HKLM\SOFTWARE\Palo Alto Networks' -Recurse

    #Uninstall all Global Protect
    Uninstall-ADTApplication -ApplicationType 'MSI' -FilterScript { $_.DisplayName -match 'GlobalProtect' } -Verbose

    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## Handle Zero-Config MSI repairs.
    if ($adtSession.UseDefaultMsi)
    {
        $ExecuteDefaultMSISplat = @{ Action = $adtSession.DeploymentType; FilePath = $adtSession.DefaultMsiFile }
        if ($adtSession.DefaultMstFile)
        {
            $ExecuteDefaultMSISplat.Add('Transform', $adtSession.DefaultMstFile)
        }
        Start-ADTMsiProcess @ExecuteDefaultMSISplat
    }

    ## TODO:<Repair-Start> <Perform Repair tasks here>

    Start-ADTMsiProcess -Action 'Install' -FilePath 'GlobalProtect64-6.2.7.msi' -ArgumentList '/QN /norestart portal=vpnportal.plains.com'


    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## TODO:<Repair-Post> <Perform Post-Repair tasks here>
    ## Copylog from the toolkit from the default log location to ProgramData\PSAppDeployToolkit\Logs.
    #Set

    # Ensure the log directory exists
    if (!(Test-Path -Path "$envPlains"))
    {
        New-Item -Path "$($envAllUsersProfile)\$($adtSession.CompanyName)\PSAppDeployToolkit\Logs" -ItemType Directory -Force | Out-Null
    }

    # Determine source path and copy the log file
    if (Test-Path -Path $envUTemp)
    {
        Copy-ADTFile -Path "$envUTemp" -Destination "$($envCompany)\PSAppDeployToolkit\Logs"
    }
    else
    {
        Copy-ADTFile -Path "$envSTemp" -Destination "$($envCompany)\PSAppDeployToolkit\Logs"
    }
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    $moduleName = if ([System.IO.File]::Exists("$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"))
    {
        Get-ChildItem -LiteralPath $PSScriptRoot\PSAppDeployToolkit -Recurse -File | Unblock-File -ErrorAction Ignore
        "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"
    }
    else
    {
        'PSAppDeployToolkit'
    }
    Import-Module -FullyQualifiedName @{ ModuleName = $moduleName; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.0.5' } -Force
    try
    {
        $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
        $adtSession = Open-ADTSession -SessionState $ExecutionContext.SessionState @adtSession @iadtParams -PassThru
    }
    catch
    {
        Remove-Module -Name PSAppDeployToolkit* -Force
        throw
    }
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

try
{
    Get-Item -Path $PSScriptRoot\PSAppDeployToolkit.* | & {
        process
        {
            Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
            Import-Module -Name $_.FullName -Force
        }
    }
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    Write-ADTLogEntry -Message ($mainErrorMessage = Resolve-ADTErrorRecord -ErrorRecord $_) -Severity 3
    Show-ADTDialogBox -Text $mainErrorMessage -Icon Stop | Out-Null
    Close-ADTSession -ExitCode 60001
}
finally
{
    Remove-Module -Name PSAppDeployToolkit* -Force
}
