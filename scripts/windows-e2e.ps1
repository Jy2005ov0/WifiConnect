# End-to-end test: runs windows/WifiConnect.ps1 against scripts/mock_portal.py (port 8080).
$ErrorActionPreference = 'Stop'
$portal = 'http://127.0.0.1:8080'
$dir = Join-Path $env:RUNNER_TEMP 'wificonnect'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$config = Join-Path $dir 'config.json'

# Windows stops a step's background processes when the step ends, so start the portal here.
$server = Start-Process python -ArgumentList 'scripts/mock_portal.py', '8080' -PassThru `
    -RedirectStandardOutput portal.log -RedirectStandardError portal-err.log

for ($i = 0; $i -lt 30; $i++) {
    try { Invoke-WebRequest "$portal/status" -UseBasicParsing | Out-Null; break } catch { Start-Sleep -Seconds 1 }
}

function Post([string]$Path) { Invoke-WebRequest "$portal$Path" -Method Post -UseBasicParsing | Out-Null }

function Set-Config([string]$Password) {
    [pscustomobject]@{
        StudentId = '2201234'
        Password = ConvertTo-SecureString $Password -AsPlainText -Force | ConvertFrom-SecureString
        WifiName = 'utarwifi'
    } | ConvertTo-Json | Set-Content -Path $config -Encoding UTF8
}

$failures = 0
function Run-Case([string]$Name, [string]$Password, [int]$ExpectExit, [bool]$ExpectAuthorized) {
    Write-Host "::group::$Name"
    Set-Config $Password
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File windows/WifiConnect.ps1 `
        -ConfigPath $config -ProbeUrl "$portal/generate_204" -Quiet
    $code = $LASTEXITCODE
    $status = (Invoke-WebRequest "$portal/status" -UseBasicParsing).Content | ConvertFrom-Json
    Write-Host "Exit code: $code, portal authorized: $($status.authorized)"
    Write-Host ($status | ConvertTo-Json -Depth 5 -Compress)
    if ($code -eq $ExpectExit -and [bool]$status.authorized -eq $ExpectAuthorized) {
        Write-Host "PASS: $Name"
    } else {
        Write-Host "::error::FAIL: $Name (expected exit $ExpectExit and authorized=$ExpectAuthorized)"
        $script:failures++
    }
    Write-Host '::endgroup::'
}

Post '/reset'
Run-Case 'wrong-password' 'wrong-pass' 1 $false
Post '/reset'
Run-Case 'sign-in' 'utar-test' 0 $true
Run-Case 'already-online' 'utar-test' 0 $true
Post '/reset'
Post '/move?to=B'
Run-Case 'other-building' 'utar-test' 0 $true

Stop-Process -Id $server.Id -ErrorAction SilentlyContinue

# ---- A campus of buildings, each with its own login page address and style (scripts/mock_campus.py) ----
# Windows answers on every 127.x address, so each building really is at a different IP.
$env:CAMPUS_HOSTS = 'A=127.0.0.2,B=127.0.0.3,C=127.0.0.4,D=127.0.0.5,E=127.0.0.6,AUTH=127.0.0.7'
$campus = Start-Process python -ArgumentList 'scripts/mock_campus.py', '9000' -PassThru `
    -RedirectStandardOutput campus.log -RedirectStandardError campus-err.log
$portal = 'http://127.0.0.1:9000'
for ($i = 0; $i -lt 30; $i++) {
    try { Invoke-WebRequest "$portal/status" -UseBasicParsing | Out-Null; break } catch { Start-Sleep -Seconds 1 }
}
Post '/reset'
foreach ($building in 'A', 'B', 'C', 'D', 'E') {
    Post "/move?to=$building"
    Run-Case "campus-$building" 'utar-test' 0 $true
}
Stop-Process -Id $campus.Id -ErrorAction SilentlyContinue
exit $failures
