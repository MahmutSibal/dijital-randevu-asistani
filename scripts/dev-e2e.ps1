# Local end-to-end check of every role against a running dev API (http://localhost:5233):
# admin -> hospital -> hospital admin -> department -> doctor (profile, hours, approval)
# -> patient -> booking -> doctor approval. Reads accounts from DEV_TEST_ACCOUNTS.json.
# -ApiLog: file the API's console output is saved to, used to read e-mail verification
# codes on first staff login when Brevo isn't configured.
param([string]$ApiLog)

$ErrorActionPreference = "Stop"
$base = "http://localhost:5233"
$accounts = Get-Content (Join-Path $PSScriptRoot "..\DEV_TEST_ACCOUNTS.json") -Raw | ConvertFrom-Json

function Call($method, $path, $body = $null, $token = $null) {
    $headers = @{}
    if ($token) { $headers["Authorization"] = "Bearer $token" }
    $args = @{ Method = $method; Uri = "$base$path"; Headers = $headers; ContentType = "application/json; charset=utf-8" }
    if ($body -ne $null) { $args.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 5)) }
    try { return Invoke-RestMethod @args }
    catch {
        $msg = $_.ErrorDetails.Message; if (-not $msg) { $msg = $_.Exception.Message }
        throw "$method $path -> $msg"
    }
}
function Step($name) { Write-Output "--- $name" }

# Staff accounts confirm their e-mail on first login. Without Brevo the API logs the
# e-mail, so read the code from the API's console log.
function StaffLogin($path, $email, $password) {
    try { return Call POST $path @{ email = $email; password = $password } }
    catch { if ("$_" -notmatch "EMAIL_NOT_VERIFIED|\(403\)") { throw } }
    if (-not $ApiLog) { throw "$email must verify its e-mail first; pass -ApiLog <API console log file>." }
    $line = Select-String -Path $ApiLog -Pattern "To=$([regex]::Escape($email))" | Select-Object -Last 1
    $code = [regex]::Matches($line.Line, '\b\d{6}\b') | Select-Object -Last 1
    "  (e-mail code for $email read from API log)"  | Write-Host
    return Call POST "/api/auth/email-verification/confirm" @{ email = $email; password = $password; code = $code.Value }
}

Step "admin (dev reset + login)"
Call POST "/api/dev/reset-admin" | Out-Null
$admin = StaffLogin "/api/auth/admin/login" $accounts.admin.email $accounts.admin.password
"role: $($admin.role)"

Step "hospital"
$hospitals = @(Call GET "/api/admin/hospitals" $null $admin.accessToken)
$h = $hospitals | Where-Object { $_.name -eq $accounts.hospital } | Select-Object -First 1
if (-not $h) { $h = Call POST "/api/admin/hospitals" @{ name = $accounts.hospital; address = "Diyarbakir"; latitude = $null; longitude = $null; type = "Public" } $admin.accessToken }
"hospital id: $($h.id)"

Step "hospital admin"
$subs = @(Call GET "/api/admin/hospitals/$($h.id)/subadmins" $null $admin.accessToken)
if (-not ($subs | Where-Object { $_.email -eq $accounts.hospitalAdmin.email })) {
    Call POST "/api/admin/hospitals/$($h.id)/assign-subadmin" @{ email = $accounts.hospitalAdmin.email; password = $accounts.hospitalAdmin.password } $admin.accessToken | Out-Null
}
$ha = StaffLogin "/api/auth/hospital-admin/login" $accounts.hospitalAdmin.email $accounts.hospitalAdmin.password
"role: $($ha.role)"

Step "department"
$deps = @(Call GET "/api/hospitaladmin/departments" $null $ha.accessToken)
$dep = $deps | Where-Object { $_.name -eq "Kardiyoloji" } | Select-Object -First 1
if (-not $dep) { $dep = Call POST "/api/hospitaladmin/departments" @{ name = "Kardiyoloji" } $ha.accessToken }
"department id: $($dep.id)"

Step "doctor"
$docs = @(Call GET "/api/hospitaladmin/doctors" $null $ha.accessToken)
$doc = $docs | Where-Object { $_.name -eq $accounts.doctor.name } | Select-Object -First 1
if (-not $doc) { $doc = Call POST "/api/hospitaladmin/doctors" @{ name = $accounts.doctor.name; title = "Uzm. Dr."; departmentId = $dep.id; email = $accounts.doctor.email; password = $accounts.doctor.password; userId = $null } $ha.accessToken }
"doctor id: $($doc.id)"
$dr = StaffLogin "/api/auth/doctor/login" $accounts.doctor.email $accounts.doctor.password
"role: $($dr.role)"
Call PUT "/api/doctor/profile/me" @{ graduationUniversity = "Dicle Universitesi"; experienceSummary = "10 yil kardiyoloji deneyimi" } $dr.accessToken | Out-Null
Call PUT "/api/doctor/availability/me" @{ workStart = "09:00"; workEnd = "17:00"; lunchStart = "12:00"; lunchEnd = "13:00"; slotMinutes = 30 } $dr.accessToken | Out-Null
"profile: $((Call GET '/api/doctor/profile/me' $null $dr.accessToken).profileStatus)"

Step "approve profile"
$pending = @(Call GET "/api/hospitaladmin/doctor-profiles/pending" $null $ha.accessToken)
"pending: $($pending.Count)"
foreach ($p in $pending) { Call POST "/api/hospitaladmin/doctor-profiles/$($p.doctorId)/approve" $null $ha.accessToken | Out-Null }
"profile: $((Call GET '/api/doctor/profile/me' $null $dr.accessToken).profileStatus)"

Step "patient"
$pts = @(Call GET "/api/admin/patients" $null $admin.accessToken)
if (-not ($pts | Where-Object { $_.tcKimlikNo -eq $accounts.patient.tc })) {
    Call POST "/api/admin/patients" @{ email = "test.hasta@test.local"; password = $accounts.patient.password; tcKimlikNo = $accounts.patient.tc; firstName = "Test"; lastName = "Hasta"; phone = "5550000000"; birthDate = "1990-01-01" } $admin.accessToken | Out-Null
}
$pt = Call POST "/api/auth/patient/login" @{ tcKimlikNo = $accounts.patient.tc; password = $accounts.patient.password }
"role: $($pt.role)"

Step "booking"
$catH = @(Call GET "/api/catalog/hospitals" $null $pt.accessToken); "catalog hospitals: $($catH.Count)"
$catD = @(Call GET "/api/catalog/departments?hospitalId=$($h.id)" $null $pt.accessToken); "catalog departments: $($catD.Count)"
$catDr = @(Call GET "/api/catalog/doctors?departmentId=$($dep.id)" $null $pt.accessToken); "catalog doctors: $($catDr.Count)"
$day = (Get-Date).AddDays(1); while ($day.DayOfWeek -in 'Saturday','Sunday') { $day = $day.AddDays(1) }
$date = $day.ToString("yyyy-MM-dd")
$slots = @(Call GET "/api/catalog/doctors/$($doc.id)/daily-slots?date=$date" $null $pt.accessToken | ForEach-Object { $_ })
"lunch 12:00 available: $(($slots | Where-Object { $_.startTime -eq '12:00' }).isAvailable)"
$free = $slots | Where-Object { $_.isAvailable } | Select-Object -First 1
"slots on ${date}: $($slots.Count), first free: $($free.startTime)"
$offset = [TimeZoneInfo]::Local.GetUtcOffset($day).ToString("hh\:mm")
$appt = Call POST "/api/appointments" @{ doctorId = $doc.id; appointmentDate = "${date}T$($free.startTime):00+$offset" } $pt.accessToken
"booked: $($appt.id) status $($appt.status)"

Step "doctor approves"
Call PUT "/api/doctor/appointments/$($appt.id)/approve" $null $dr.accessToken | Out-Null
$mine = @(Call GET "/api/appointments/my" $null $pt.accessToken)
"patient sees: $(($mine | Where-Object { $_.id -eq $appt.id }).status)"
"hospital sees: $(@(Call GET '/api/hospital/appointments' $null $ha.accessToken).Count) appointment(s)"
"admin summary total: $((Call GET '/api/admin/reports/appointment-summary?days=30' $null $admin.accessToken).statusSummary.total)"
