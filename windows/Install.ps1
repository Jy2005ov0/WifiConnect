<#
.SYNOPSIS
    Sets up WiFi Connect on this laptop: saves your student ID and password (encrypted for
    your Windows account) and signs in automatically whenever you join the campus Wi-Fi.
#>
$ErrorActionPreference = 'Stop'

$appDir = Join-Path $env:LOCALAPPDATA 'WifiConnect'
$configDir = Join-Path $env:APPDATA 'WifiConnect'
$configPath = Join-Path $configDir 'config.json'
$taskName = 'WiFi Connect'

Write-Host ''
Write-Host '  WiFi Connect for Windows' -ForegroundColor Cyan
Write-Host '  Signs this laptop in to the campus Wi-Fi automatically.'
Write-Host ''

$studentId = Read-Host '  Student ID'
$password = Read-Host '  Password' -AsSecureString
$wifiName = Read-Host '  Campus Wi-Fi name [utarwifi]'
if (-not $wifiName) { $wifiName = 'utarwifi' }

New-Item -ItemType Directory -Force -Path $appDir, $configDir | Out-Null
[pscustomobject]@{
    StudentId = $studentId
    # Encrypted with Windows DPAPI: only your Windows account on this PC can read it.
    Password = ConvertFrom-SecureString $password
    WifiName = $wifiName
} | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8

Copy-Item -Force -Path (Join-Path $PSScriptRoot 'WifiConnect.ps1') -Destination $appDir
$script = Join-Path $appDir 'WifiConnect.ps1'

# Run when Windows connects to a network (NetworkProfile event 10000), at sign-in,
# and every 15 minutes to stay signed in.
$eventClass = Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
$onConnect = New-CimInstance -CimClass $eventClass -ClientOnly
$onConnect.Enabled = $true
$onConnect.Subscription = @'
<QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"><Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[EventID=10000]]</Select></Query></QueryList>
'@
$onLogon = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$every15 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($onConnect, $onLogon, $every15) `
    -Settings $settings -Principal $principal -Description 'Signs in to the campus Wi-Fi login page.' -Force | Out-Null

Write-Host ''
Write-Host '  Done! This laptop will now sign in to' $wifiName 'by itself.' -ForegroundColor Green
Write-Host '  Trying now...'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script
Write-Host ''
Write-Host "  Log: $configDir\log.txt"
Write-Host '  To change your password, run Install again. To remove it, run Uninstall.'
Write-Host ''
Read-Host '  Press Enter to close'
