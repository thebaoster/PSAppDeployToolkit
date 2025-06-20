$buildname = Read-Host "Enter Build Name"
New-ADTTemplate -Destination .\build -Name "$buildname"
