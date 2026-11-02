# Local check of the patient features (health profile, dependents, booking, reschedule,
# waitlist, notifications, forgot password) against a running dev API, as mobilePatient.
$ErrorActionPreference = "Stop"
$base = "http://localhost:5233"
$acc = Get-Content "C:\Users\Mahmu\Desktop\dijital_randevu_asistani\DEV_TEST_ACCOUNTS.json" -Raw | ConvertFrom-Json
function Call($method, $path, $body = $null, $token = $null) {
    $h = @{}; if ($token) { $h.Authorization = "Bearer $token" }
    $a = @{ Method = $method; Uri = "$base$path"; Headers = $h; ContentType = "application/json; charset=utf-8" }
    if ($body -ne $null) { $a.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 5)) }
    try { return Invoke-RestMethod @a }
    catch {
        $msg = $_.Exception.Message
        try { $msg = (New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch {}
        throw "$method $path -> $msg"
    }
}
function List($x) { @($x | ForEach-Object { $_ }) }

$p = Call POST "/api/auth/patient/login" @{ tcKimlikNo = $acc.mobilePatient.tc; password = $acc.mobilePatient.password }
$t = $p.accessToken
"login: $($p.role)"

"--- health profile"
try { $hp = Call GET "/api/patient/health-profile" $null $t; "get: ok" } catch { "get: $_" }
$hp = Call PUT "/api/patient/health-profile" @{ bloodType = "A+"; allergies = "Penisilin"; chronicDiseases = $null; medications = $null; emergencyContactName = "Ayse Hasta"; emergencyContactPhone = "5550001122" } $t
"put -> bloodType=$($hp.bloodType) allergies=$($hp.allergies)"

"--- dependents"
$deps = List (Call GET "/api/patient/dependents/me" $null $t)
$dep = $deps | Where-Object { $_.fullName -eq "Deniz Hasta" } | Select-Object -First 1
if (-not $dep) { try { $dep = Call POST "/api/patient/dependents/me" @{ fullName = "Deniz Hasta"; tcKimlikNo = "10000000078"; birthDate = "2015-03-10"; relation = "Child" } $t } catch { "add (fake identity): $_" } }
"dependents listed: $($deps.Count)"
$depId = if ($dep) { $dep.id } else { $null }

"--- book for dependent"
$doctorId = 1
$day = (Get-Date).AddDays(2); while ($day.DayOfWeek -in 'Saturday','Sunday') { $day = $day.AddDays(1) }
$date = $day.ToString("yyyy-MM-dd"); $off = [TimeZoneInfo]::Local.GetUtcOffset($day).ToString("hh\:mm")
$slots = List (Call GET "/api/catalog/doctors/$doctorId/daily-slots?date=$date" $null $t)
$free = @($slots | Where-Object { $_.isAvailable })
$appt = Call POST "/api/appointments" @{ doctorId = $doctorId; appointmentDate = "${date}T$($free[0].startTime):00+$off"; dependentId = $depId } $t
"booked $($free[0].startTime) for: $($appt.dependentFullName) status=$($appt.status)"

"--- reschedule"
$moved = Call PUT "/api/appointments/$($appt.id)/reschedule" @{ newAppointmentDate = "${date}T$($free[1].startTime):00+$off" } $t
"moved to: $($moved.appointmentDateUtc) status=$($moved.status)"

"--- waitlist on the now-full slot"
$slots = List (Call GET "/api/catalog/doctors/$doctorId/daily-slots?date=$date" $null $t)
$full = $slots | Where-Object { $_.unavailableReason -eq "Dolu" } | Select-Object -First 1
"full slot: $($full.startTime)"
try { Call POST "/api/waitlist/join" @{ doctorId = $doctorId; startAtUtc = "${date}T$($full.startTime):00+$off" } $t | Out-Null; "join: ok" } catch { "join: $_" }

"--- notifications"
$n = List (Call GET "/api/notifications?take=50" $null $t)
"notifications: $($n.Count)"

"--- forgot password (wrong details, must not reset)"
try { Call POST "/api/auth/patient/forgot-password" @{ firstName = "Yanlis"; lastName = "Isim"; tcKimlikNo = $acc.mobilePatient.tc; phone = "5550000000" } | Out-Null; "UNEXPECTED ok" } catch { "rejected: $_" }

"--- cleanup: cancel test appointment"
Call PUT "/api/appointments/$($appt.id)/cancel" @{ reason = "test" } $t | Out-Null; "cancelled"
