# Local check of the e-Devlet-style account features: TC login lockout counter, login history,
# KVKK consent, appointment certificate + public verification. Needs the API on localhost:5233.
# Only two wrong passwords are tried, so the test account is never actually locked.
$ErrorActionPreference = "Stop"
$base = "http://localhost:5233"
$acc = Get-Content (Join-Path $PSScriptRoot "..\DEV_TEST_ACCOUNTS.json") -Raw | ConvertFrom-Json

function Call($method, $path, $body = $null, $token = $null) {
    $h = @{ "X-Client-Device" = "e2e-script" }; if ($token) { $h.Authorization = "Bearer $token" }
    $a = @{ Method = $method; Uri = "$base$path"; Headers = $h; ContentType = "application/json; charset=utf-8" }
    if ($body -ne $null) { $a.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 5)) }
    try { $r = Invoke-WebRequest @a -UseBasicParsing; return @{ status = [int]$r.StatusCode; body = ([Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())) } }
    catch {
        $resp = $_.Exception.Response
        if (-not $resp) { throw }
        $text = (New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)).ReadToEnd()
        return @{ status = [int]$resp.StatusCode; body = $text }
    }
}
function Show($label, $r) { "{0,-40} {1}  {2}" -f $label, $r.status, ($r.body.Substring(0, [Math]::Min(170, $r.body.Length))) }

$tc = $acc.mobilePatient.tc
Show "wrong password #1 (401, 4 left)" (Call POST "/api/auth/patient/login" @{ tcKimlikNo = $tc; password = "yanlis-sifre-1" })
Show "wrong password #2 (401, 3 left)" (Call POST "/api/auth/patient/login" @{ tcKimlikNo = $tc; password = "yanlis-sifre-2" })
$login = Call POST "/api/auth/patient/login" @{ tcKimlikNo = $tc; password = $acc.mobilePatient.password }
Show "correct password (200, resets counter)" $login
$t = ($login.body | ConvertFrom-Json).accessToken

Show "security without sign-in (401)" (Call GET "/api/account/security")
$sec = Call GET "/api/account/security" $null $t
Show "security (lastFailed, history)" $sec
$s = $sec.body | ConvertFrom-Json
"  previousLogin: $($s.previousLogin.atUtc)  lastFailed: $($s.lastFailedLogin.atUtc)  history: $($s.history.Count)  kvkk ok: $($s.kvkk.isUpToDate)"

Show "kvkk: stale version (409)" (Call POST "/api/account/kvkk" @{ version = "1999.1" } $t)
Show "kvkk: accept current (200)" (Call POST "/api/account/kvkk" @{ version = $s.kvkk.currentVersion } $t)

$appts = (Call GET "/api/appointments/my" $null $t).body | ConvertFrom-Json
if (-not $appts -or $appts.Count -eq 0) { "no appointments for the test patient; skipping documents"; return }
$doc = Call POST "/api/documents/appointments/$($appts[0].id)" $null $t
Show "issue certificate (200)" $doc
$code = ($doc.body | ConvertFrom-Json).code
Show "verify code, no sign-in (200)" (Call GET "/api/documents/verify/$($code.ToLower())")
Show "verify unknown code (404)" (Call GET "/api/documents/verify/RB-AAAA-AAAA-AAAA")
Show "issue for unknown appointment (404)" (Call POST "/api/documents/appointments/$([guid]::NewGuid())" $null $t)
