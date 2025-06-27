
# New-ADTTemplate -Destination .\build -Name "devops"


Container Manager Service
Add-LocalGroupMember -group Administrator -Member L020NGYENB1\WDAGUtilityAccount
Get-service CmService | Stop-Service
Get-Service vmcompute | Restart-Service
Get-service CmService | Stop-Service


string sPSCode = "Invoke-WmiMethod -ComputerName " + sHost + " -Namespace root\\cimv2 -Class Win32_Process -Name Create -ArgumentList '\"C:\\Windows\\system32\\WindowsPowerShell\\v1.0\\powershell.exe\" \"Enable-PSRemoting -Force
