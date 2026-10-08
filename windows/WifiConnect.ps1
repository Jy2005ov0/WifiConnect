<#
.SYNOPSIS
    Signs this laptop in to the campus Wi-Fi login page (captive portal).

.DESCRIPTION
    Runs automatically (set up by Install.ps1) whenever Windows joins a network, and every
    15 minutes to stay signed in. It finds the login page the same way Windows does, fills in
    your student ID and password and checks that you're online.

.PARAMETER ConfigPath
    Settings file. Defaults to %APPDATA%\WifiConnect\config.json.

.PARAMETER ProbeUrl
    Connectivity check page. Only changed by the automated tests.

.PARAMETER Quiet
    Don't show a notification.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $env:APPDATA 'WifiConnect\config.json'),
    [string]$ProbeUrl = 'http://www.msftconnecttest.com/connecttest.txt',
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$LogPath = Join-Path (Split-Path $ConfigPath) 'log.txt'
$RegexOptions = [System.Text.RegularExpressions.RegexOptions]'IgnoreCase, Singleline'

function Write-Log([string]$Message) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $Message
    Write-Host $line
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $LogPath) | Out-Null
        Add-Content -Path $LogPath -Value $line -Encoding UTF8
        # Keep the log small.
        $lines = Get-Content $LogPath
        if ($lines.Count -gt 500) { $lines[-300..-1] | Set-Content $LogPath -Encoding UTF8 }
    } catch { }
}

function Show-Notification([string]$Title, [string]$Body) {
    if ($Quiet) { return }
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
            [Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $texts = $xml.GetElementsByTagName('text')
        [void]$texts.Item(0).AppendChild($xml.CreateTextNode($Title))
        [void]$texts.Item(1).AppendChild($xml.CreateTextNode($Body))
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        # Windows PowerShell's own ID, so the toast is allowed without registering an app.
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    } catch {
        Write-Log "Couldn't show a notification: $($_.Exception.Message)"
    }
}

function Get-PlainPassword([string]$Encrypted) {
    # Encrypted with Windows DPAPI for this user (see Install.ps1).
    $secure = ConvertTo-SecureString $Encrypted
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Get-CurrentSsid {
    # Recent Windows versions hide the name unless Location is on; then this returns $null.
    try {
        $output = netsh wlan show interfaces 2>$null
        foreach ($line in $output) {
            if ($line -match '^\s*SSID\s*:\s*(.+)$') { return $Matches[1].Trim() }
        }
    } catch { }
    return $null
}

function Decode-Html([string]$Text) {
    if ($null -eq $Text) { return '' }
    $out = [regex]::Replace($Text, '&#(x?)([0-9a-fA-F]+);', {
        param($m)
        $radix = if ($m.Groups[1].Value) { 16 } else { 10 }
        try { [char]::ConvertFromUtf32([Convert]::ToInt32($m.Groups[2].Value, $radix)) } catch { $m.Value }
    })
    foreach ($pair in @(@('&quot;', '"'), @('&apos;', "'"), @('&lt;', '<'), @('&gt;', '>'), @('&nbsp;', ' '), @('&amp;', '&'))) {
        $out = $out.Replace($pair[0], $pair[1])
    }
    return $out
}

function Get-Attributes([string]$TagBody) {
    $attrs = @{}
    $pattern = '([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*(?:"([^"]*)"|''([^'']*)''|([^\s"''>]+)))?'
    foreach ($m in [regex]::Matches($TagBody, $pattern, $RegexOptions)) {
        $key = $m.Groups[1].Value.ToLowerInvariant()
        if ($attrs.ContainsKey($key)) { continue }
        $value = if ($m.Groups[2].Success) { $m.Groups[2].Value } elseif ($m.Groups[3].Success) { $m.Groups[3].Value } elseif ($m.Groups[4].Success) { $m.Groups[4].Value } else { '' }
        $attrs[$key] = $value
    }
    return $attrs
}

function Resolve-Url([Uri]$Base, [string]$Relative) {
    try { return [Uri]::new($Base, $Relative) } catch { return $null }
}

function Find-LoginForm([string]$Html, [Uri]$BaseUrl) {
    $clean = [regex]::Replace($Html, '<!--.*?-->', '', $RegexOptions)
    foreach ($form in [regex]::Matches($clean, '<form\b([^>]*)>(.*?)</form\s*>', $RegexOptions)) {
        $attrs = Get-Attributes $form.Groups[1].Value
        $inputs = @()
        foreach ($tag in [regex]::Matches($form.Groups[2].Value, '<input\b([^>]*)>', $RegexOptions)) {
            $a = Get-Attributes $tag.Groups[1].Value
            if (-not $a['name']) { continue }
            $type = if ($a.ContainsKey('type')) { $a['type'].ToLowerInvariant() } else { 'text' }
            $inputs += [pscustomobject]@{
                Name = Decode-Html $a['name']; Type = $type
                Value = Decode-Html $a['value']; Checked = $a.ContainsKey('checked')
            }
        }
        if (-not ($inputs | Where-Object Type -eq 'password')) { continue }
        $actionText = (Decode-Html $attrs['action']).Trim()
        $action = if ($actionText) { Resolve-Url $BaseUrl $actionText } else { $BaseUrl }
        if (-not $action) { $action = $BaseUrl }
        $method = if ($attrs['method'] -and $attrs['method'].ToLowerInvariant() -eq 'post') { 'POST' } else { 'GET' }
        return [pscustomobject]@{ Action = $action; Method = $method; Inputs = $inputs }
    }
    return $null
}

function Find-ClientRedirect([string]$Html, [Uri]$BaseUrl) {
    $clean = [regex]::Replace($Html, '<!--.*?-->', '', $RegexOptions)
    foreach ($meta in [regex]::Matches($clean, '<meta\b([^>]*)>', $RegexOptions)) {
        $attrs = Get-Attributes $meta.Groups[1].Value
        if ($attrs['http-equiv'] -and $attrs['http-equiv'].ToLowerInvariant() -eq 'refresh' -and $attrs['content']) {
            $m = [regex]::Match((Decode-Html $attrs['content']), 'url\s*=\s*[''"]?([^''"]+)', $RegexOptions)
            if ($m.Success) { return Resolve-Url $BaseUrl $m.Groups[1].Value.Trim() }
        }
    }
    foreach ($pattern in @('location\.replace\(\s*[''"]([^''"]+)[''"]', 'location(?:\.href)?\s*=\s*[''"]([^''"]+)[''"]')) {
        $m = [regex]::Match($clean, $pattern, $RegexOptions)
        if ($m.Success) { return Resolve-Url $BaseUrl $m.Groups[1].Value.Trim() }
    }
    return $null
}

function Get-Username([object[]]$Inputs) {
    $candidates = $Inputs | Where-Object { @('text', 'email', 'tel', 'number', '') -contains $_.Type }
    foreach ($hint in @('user', 'login', 'account', 'student', 'matric', 'uid', 'email', 'id', 'name')) {
        $match = $candidates | Where-Object { $_.Name.ToLowerInvariant().Contains($hint) } | Select-Object -First 1
        if ($match) { return $match.Name }
    }
    return ($candidates | Select-Object -First 1).Name
}

function Invoke-Page([Uri]$Url, $Session, [string]$Method = 'GET', $Body = $null, [Uri]$Referer = $null) {
    $params = @{
        Uri = $Url; Method = $Method; WebSession = $Session; UseBasicParsing = $true
        TimeoutSec = 10; MaximumRedirection = 8
        UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) WifiConnect'
    }
    # Windows PowerShell 5.1 doesn't allow setting Referer as a plain header.
    if ($Referer -and $PSVersionTable.PSVersion.Major -ge 6) { $params.Headers = @{ Referer = $Referer.AbsoluteUri } }
    if ($null -ne $Body) { $params.Body = $Body; $params.ContentType = 'application/x-www-form-urlencoded' }
    try {
        $response = Invoke-WebRequest @params
    } catch [System.Net.WebException] {
        # Windows PowerShell throws on any error status, but login pages often answer with one
        # (511 Network Authentication Required, 403...). Read the page anyway.
        $errorResponse = $_.Exception.Response
        if (-not $errorResponse) { throw }
        $reader = New-Object System.IO.StreamReader($errorResponse.GetResponseStream())
        $html = $reader.ReadToEnd()
        $reader.Close()
        return [pscustomobject]@{ Url = [Uri]$errorResponse.ResponseUri; Html = $html; Status = [int]$errorResponse.StatusCode }
    }
    # Where the redirects ended up (Windows PowerShell vs PowerShell 7).
    $final = $null
    if ($response.BaseResponse.ResponseUri) { $final = $response.BaseResponse.ResponseUri }
    elseif ($response.BaseResponse.RequestMessage) { $final = $response.BaseResponse.RequestMessage.RequestUri }
    if (-not $final) { $final = $Url }
    return [pscustomobject]@{ Url = [Uri]$final; Html = [string]$response.Content; Status = [int]$response.StatusCode }
}

function Get-Probe($Session) {
    $probe = [Uri]$ProbeUrl
    $page = Invoke-Page $probe $Session
    $online = $page.Url.Host -eq $probe.Host -and (
        $page.Status -eq 204 -or $page.Html -match 'Microsoft Connect Test' -or $page.Html -match '<body>\s*success\s*</body>')
    if ($online) { return $null }
    for ($i = 0; $i -lt 3; $i++) {
        if (Find-LoginForm $page.Html $page.Url) { break }
        $next = Find-ClientRedirect $page.Html $page.Url
        if (-not $next) { break }
        $page = Invoke-Page $next $Session
    }
    return $page
}

# Windows PowerShell only offers old TLS versions unless asked. Campus login pages in each
# building often sit on a bare private IP with a certificate that can't match it: accept those,
# and only those (10.x, 172.16-31.x, 192.168.x). Other sites are checked as usual.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor
    [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
if (-not ('WifiConnectPortalTrust' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

public static class WifiConnectPortalTrust {
    public static bool Check(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors) {
        if (errors == SslPolicyErrors.None) return true;
        HttpWebRequest request = sender as HttpWebRequest;
        IPAddress address;
        if (request == null || !IPAddress.TryParse(request.RequestUri.Host, out address)) return false;
        byte[] b = address.GetAddressBytes();
        if (b.Length != 4) return false;
        return b[0] == 10 || (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || (b[0] == 192 && b[1] == 168);
    }

    public static void Install() {
        ServicePointManager.ServerCertificateValidationCallback = Check;
    }
}
'@
}
[WifiConnectPortalTrust]::Install()

# ---- Main ----

if (-not (Test-Path $ConfigPath)) {
    Write-Log "No settings found at $ConfigPath. Run Install.ps1 first."
    exit 2
}
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$network = if ($config.WifiName) { $config.WifiName } else { 'utarwifi' }

$ssid = Get-CurrentSsid
if ($ssid -and $ssid -ne $network) {
    Write-Log "On '$ssid', not '$network'. Nothing to do."
    exit 0
}

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
try {
    $page = Get-Probe $session
} catch {
    Write-Log "Couldn't reach the Wi-Fi: $($_.Exception.Message)"
    exit 1
}
if (-not $page) {
    Write-Log 'Already online.'
    exit 0
}

Write-Log "Login page: $($page.Url.AbsoluteUri)"
$form = Find-LoginForm $page.Html $page.Url
if (-not $form) {
    Write-Log "Couldn't find a login form on the page."
    Show-Notification "Couldn't sign in to $network" "The login page's form wasn't recognised."
    exit 1
}

$password = Get-PlainPassword $config.Password
$userField = if ($config.UsernameField) { $config.UsernameField } else { Get-Username $form.Inputs }
$passField = if ($config.PasswordField) { $config.PasswordField } else { ($form.Inputs | Where-Object Type -eq 'password' | Select-Object -First 1).Name }

# Same rules as the phone apps: keep hidden fields, tick checkboxes, send the first submit button.
$pairs = New-Object System.Collections.Generic.List[string]
$addedSubmit = $false
foreach ($field in $form.Inputs) {
    $value = $field.Value
    $type = $field.Type
    if ($type -eq 'password') {
        if ($field.Name -eq $passField) { $value = $password }
    } elseif ($type -eq 'checkbox') {
        if (-not $value) { $value = 'on' }
    } elseif ($type -eq 'radio') {
        if (-not $field.Checked) { continue }
    } elseif ($type -eq 'submit' -or $type -eq 'image') {
        if ($addedSubmit) { continue }
        $addedSubmit = $true
    } elseif ($type -eq 'button' -or $type -eq 'reset' -or $type -eq 'file') {
        continue
    } elseif ($field.Name -eq $userField) {
        $value = $config.StudentId
    }
    $pairs.Add([Uri]::EscapeDataString($field.Name) + '=' + [Uri]::EscapeDataString([string]$value))
}
$body = $pairs -join '&'

try {
    if ($form.Method -eq 'POST') {
        [void](Invoke-Page $form.Action $session 'POST' $body $page.Url)
    } else {
        $separator = if ($form.Action.Query) { '&' } else { '?' }
        [void](Invoke-Page ([Uri]($form.Action.AbsoluteUri + $separator + $body)) $session 'GET' $null $page.Url)
    }
} catch {
    Write-Log "The login page didn't respond: $($_.Exception.Message)"
}

for ($attempt = 0; $attempt -lt 4; $attempt++) {
    if ($attempt -gt 0) { Start-Sleep -Milliseconds 1500 }
    try {
        if (-not (Get-Probe (New-Object Microsoft.PowerShell.Commands.WebRequestSession))) {
            Write-Log 'Signed in.'
            Show-Notification "Connected to $network" "You're signed in and online."
            exit 0
        }
    } catch { }
}

Write-Log 'Signed in, but still no internet. Check the student ID and password.'
Show-Notification "Couldn't sign in to $network" 'Check your student ID and password: run Install.ps1 again to change them.'
exit 1
