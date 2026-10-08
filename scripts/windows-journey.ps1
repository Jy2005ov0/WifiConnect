# A first-time user on a Windows laptop, step by step: double-click Install, type the student
# ID and password at the prompts, check it signs in and the internet works, check it's set to
# run by itself, then double-click Uninstall.
# The only test hook: WIFICONNECT_PROBE_URL points the login check at scripts/mock_portal.py.
$ErrorActionPreference = 'Stop'
$portal = 'http://127.0.0.1:8080'
$results = @()
$failed = $false

$server = Start-Process python -ArgumentList 'scripts/mock_portal.py', '8080' -PassThru `
    -RedirectStandardOutput portal.log -RedirectStandardError portal-err.log
for ($i = 0; $i -lt 30; $i++) {
    try { Invoke-WebRequest "$portal/status" -UseBasicParsing | Out-Null; break } catch { Start-Sleep -Seconds 1 }
}
Invoke-WebRequest "$portal/reset" -Method Post -UseBasicParsing | Out-Null

function Check([string]$Name, [bool]$Ok) {
    if ($Ok) { Write-Host "PASS: $Name"; $script:results += "PASS  $Name" }
    else { Write-Host "::error::FAIL: $Name"; $script:results += "FAIL  $Name"; $script:failed = $true }
}
function Authorized { [bool]((Invoke-WebRequest "$portal/status" -UseBasicParsing).Content | ConvertFrom-Json).authorized }
function InternetWorks {
    try { return (Invoke-WebRequest "$portal/generate_204" -UseBasicParsing -MaximumRedirection 0).StatusCode -eq 204 }
    catch { return $false }
}

$env:WIFICONNECT_PROBE_URL = "$portal/generate_204"
# The scheduled task gets the user's saved variables, so save it there too.
[Environment]::SetEnvironmentVariable('WIFICONNECT_PROBE_URL', "$portal/generate_204", 'User')

# 1. Double-click Install.cmd and answer: student ID, password, Wi-Fi name (Enter for utarwifi),
#    then Enter to close.
$answers = "2201234`r`nutar-test`r`n`r`n`r`n"
$output = $answers | cmd /c "windows\Install.cmd" 2>&1 | Out-String
Write-Host $output
Check 'Install finishes without an error' ($LASTEXITCODE -eq 0 -and $output -notmatch 'Exception')
$config = Join-Path $env:APPDATA 'WifiConnect\config.json'
$saved = if (Test-Path $config) { Get-Content $config -Raw | ConvertFrom-Json }
Check 'Install saves the student ID and Wi-Fi name' ($saved -and $saved.StudentId -eq '2201234' -and $saved.WifiName -eq 'utarwifi')
$password = try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR((ConvertTo-SecureString $saved.Password))) } catch { '' }
Check 'Install saves the password encrypted, and it reads back correctly' ($saved.Password -ne 'utar-test' -and $password -eq 'utar-test')

# 2. Install's "Trying now..." signs in straight away.
Check 'Install signs in straight away' (Authorized)
Check 'The internet works after signing in' (InternetWorks)

# 3. It's set to run by itself (joining Wi-Fi, signing in to Windows, every 15 minutes).
$task = Get-ScheduledTask -TaskName 'WiFi Connect' -ErrorAction SilentlyContinue
Check 'Install sets it to run by itself' ($null -ne $task -and $task.Triggers.Count -eq 3)

# 4. Later the campus logs the laptop out; the scheduled run signs it back in.
Invoke-WebRequest "$portal/reset" -Method Post -UseBasicParsing | Out-Null
if ($task) {
    Start-ScheduledTask -TaskName 'WiFi Connect'
    for ($i = 0; $i -lt 60 -and -not (Authorized); $i++) { Start-Sleep -Seconds 1 }
    if (Authorized) { Check 'The scheduled run signs in again by itself' $true }
    else {
        # Test machines have no signed-in desktop session, which the task needs; run what it runs.
        $info = Get-ScheduledTaskInfo -TaskName 'WiFi Connect'
        Write-Host "::warning::The scheduled task didn't run here (last result $($info.LastTaskResult)); running its command instead."
        $action = $task.Actions[0]
        Start-Process -Wait -NoNewWindow $action.Execute -ArgumentList $action.Arguments
        Check 'The installed copy signs in again by itself' (Authorized)
    }
}
Check 'The internet works again' (InternetWorks)
$log = Join-Path $env:APPDATA 'WifiConnect\log.txt'
if (Test-Path $log) { Write-Host '--- log.txt ---'; Get-Content $log | Write-Host }

# 5. Double-click Uninstall.cmd, then Enter to close.
$output = "`r`n" | cmd /c "windows\Uninstall.cmd" 2>&1 | Out-String
Write-Host $output
Check 'Uninstall removes the task and saved settings' (
    -not (Get-ScheduledTask -TaskName 'WiFi Connect' -ErrorAction SilentlyContinue) -and
    -not (Test-Path (Join-Path $env:APPDATA 'WifiConnect')) -and
    -not (Test-Path (Join-Path $env:LOCALAPPDATA 'WifiConnect')))

[Environment]::SetEnvironmentVariable('WIFICONNECT_PROBE_URL', $null, 'User')
Stop-Process -Id $server.Id -ErrorAction SilentlyContinue
Write-Host '===== User journey on Windows ====='
$results | ForEach-Object { Write-Host $_ }
Write-Host "::notice title=Windows user journey::$($results -join '%0A')"
if ($failed) { exit 1 }
