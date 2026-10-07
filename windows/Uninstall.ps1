<#
.SYNOPSIS
    Removes WiFi Connect from this laptop: the scheduled task, the script and your saved settings.
#>
Unregister-ScheduledTask -TaskName 'WiFi Connect' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $env:LOCALAPPDATA 'WifiConnect')
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $env:APPDATA 'WifiConnect')
Write-Host ''
Write-Host '  WiFi Connect has been removed from this laptop.' -ForegroundColor Green
Write-Host ''
Read-Host '  Press Enter to close'
