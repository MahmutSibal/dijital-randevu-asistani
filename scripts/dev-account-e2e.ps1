# Local check of the account features: active sessions, two-step sign-in, data export,
# KVKK deletion request (creates a real ticket in the support sheet), doctor reviews,
# hospital info for directions, and the admin security overview. API on localhost:5233.
$ErrorActionPreference = "Stop"
$base = "http://localhost:5233"
$acc = Get-Content (Join-Path $PSScriptRoot "..\DEV_TEST_ACCOUNTS.json") -Raw | ConvertFrom-Json

function Call($method, $path, $body = $null, $token = $null, $device = "e2e-script") {
    $h = @{ "X-Client-Device" = $device }; if ($token) { $h.Authorization = "Bearer $token" }
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
function Show($label, $r) { "{0,-44} {1}  {2}" -f $label, $r.status, ($r.body.Substring(0, [Math]::Min(150, $r.body.Length))) }
function Json($r) { $r.body | ConvertFrom-Json }
$patientLogin = @{ tcKimlikNo = $acc.mobilePatient.tc; password = $acc.mobilePatient.password }

"--- sessions"
$a = Json (Call POST "/api/auth/patient/login" $patientLogin $null "e2e-phone")
$b = Json (Call POST "/api/auth/patient/login" $patientLogin $null "e2e-tablet")
$s = Call GET "/api/account/sessions" $null $a.accessToken
Show "list sessions" $s
"  sessions listed: $(([regex]::Matches($s.body, '"isCurrent"')).Count), current: $(([regex]::Matches($s.body, '"isCurrent":true')).Count)"
Show "other device works before (200)" (Call GET "/api/patient/me" $null $b.accessToken)
Show "end other sessions" (Call POST "/api/account/sessions/end-others" $null $a.accessToken)
Show "other device rejected at once (401)" (Call GET "/api/patient/me" $null $b.accessToken)
Show "this device still works (200)" (Call GET "/api/patient/me" $null $a.accessToken)
Show "other device cannot refresh (401)" (Call POST "/api/auth/refresh" @{ refreshToken = $b.refreshToken })

"--- two-step sign-in"
Show "status" (Call GET "/api/account/two-factor" $null $a.accessToken)
Show "enable (200)" (Call PUT "/api/account/two-factor" @{ enabled = $true } $a.accessToken)
$c = Call POST "/api/auth/patient/login" $patientLogin
Show "login now asks for a code (202)" $c
$ch = Json $c
Show "wrong code (401, 4 left)" (Call POST "/api/auth/patient/login/verify-code" @{ challengeId = $ch.challengeId; code = "000000" })
$ok = Call POST "/api/auth/patient/login/verify-code" @{ challengeId = $ch.challengeId; code = $ch.devCode }
Show "right code (200)" $ok
Show "code cannot be reused (401)" (Call POST "/api/auth/patient/login/verify-code" @{ challengeId = $ch.challengeId; code = $ch.devCode })
$t = (Json $ok).accessToken
Show "disable again (200)" (Call PUT "/api/account/two-factor" @{ enabled = $false } $t)

"--- data rights"
$e = Call GET "/api/account/export" $null $t
"{0,-44} {1}  appointments: {2}, logins: {3}" -f "export (200)", $e.status, @((Json $e).appointments).Count, @((Json $e).loginHistory).Count
if ($args -contains "-WithDeletionTicket") {
    Show "deletion request -> support ticket" (Call POST "/api/account/deletion-request" $null $t)
}

"--- appointments, directions, reviews"
$appts = Json (Call GET "/api/appointments/my" $null $t)
"  first appointment hospital: $($appts[0].hospitalName) ($($appts[0].hospitalLatitude), $($appts[0].hospitalLongitude))"
$pending = $appts | Where-Object { $_.status -eq "Pending" -or $_.status -eq "Approved" } | Select-Object -First 1
if ($pending) {
    Show "review before completion (409)" (Call POST "/api/appointments/$($pending.id)/review" @{ stars = 5 } $t)
    # Test appointments are in the past, which the real flow cannot approve; the dev endpoint forces it.
    Show "dev: mark completed (204)" (Call POST "/api/dev/appointments/$($pending.id)/complete")
    Show "bad stars (400)" (Call POST "/api/appointments/$($pending.id)/review" @{ stars = 9 } $t)
    Show "review (200)" (Call POST "/api/appointments/$($pending.id)/review" @{ stars = 5; comment = "Çok ilgiliydi, teşekkürler." } $t)
    Show "second review (409)" (Call POST "/api/appointments/$($pending.id)/review" @{ stars = 1 } $t)
}
Show "my reviews" (Call GET "/api/reviews/mine" $null $t)
Show "doctor averages (anonymous)" (Call GET "/api/reviews/doctors/averages")

"--- admin"
$admin = Json (Call POST "/api/auth/admin/login" @{ email = $acc.admin.email; password = $acc.admin.password })
Show "security overview (200)" (Call GET "/api/admin/security" $null $admin.accessToken)
Show "patient cannot see it (403)" (Call GET "/api/admin/security" $null $t)
Show "audit log (200)" (Call GET "/api/admin/audit-logs?take=5" $null $admin.accessToken)
