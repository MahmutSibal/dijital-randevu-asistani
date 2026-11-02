# Local check of support requests: Flutter-facing .NET API -> n8n -> Google Sheets.
# Needs the API running (localhost:5233) and the n8n workflow "Hastane Destek Talepleri"
# published with its two credentials. Uses accounts from DEV_TEST_ACCOUNTS.json.
$ErrorActionPreference = "Stop"
$base = "http://localhost:5233"
$acc = Get-Content (Join-Path $PSScriptRoot "..\DEV_TEST_ACCOUNTS.json") -Raw | ConvertFrom-Json

function Call($method, $path, $body = $null, $token = $null) {
    $h = @{}; if ($token) { $h.Authorization = "Bearer $token" }
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
function Show($label, $r) { "{0,-40} {1}  {2}" -f $label, $r.status, ($r.body.Substring(0, [Math]::Min(160, $r.body.Length))) }

Show "create: missing fields (400)" (Call POST "/api/support/tickets" @{ adSoyad = ""; konu = ""; aciklama = "" })
Show "get: malformed number (400)" (Call GET "/api/support/tickets/abc")
Show "list without sign-in (401)" (Call GET "/api/support/tickets")

$pt = (Call POST "/api/auth/patient/login" @{ tcKimlikNo = $acc.mobilePatient.tc; password = $acc.mobilePatient.password }).body | ConvertFrom-Json
$created = Call POST "/api/support/tickets" @{ adSoyad = "Mobil Hasta"; iletisim = "5551112233"; kategori = "Randevu"; oncelik = "Normal"; konu = "Randevu saatim gözükmüyor"; aciklama = "Dün aldığım randevu Randevularım ekranında görünmüyor." } $pt.accessToken
Show "create as patient (201)" $created
if ($created.status -ne 201) { return }
$no = ($created.body | ConvertFrom-Json).talepNo

Show "get by number (200)" (Call GET "/api/support/tickets/$no")
Show "get unknown number (404)" (Call GET "/api/support/tickets/DT-20000101-ZZZZZ")
Show "mine (patient)" (Call GET "/api/support/tickets/mine" $null $pt.accessToken)
Show "patient cannot change status (403)" (Call PATCH "/api/support/tickets/$no/status" @{ durum = "Çözüldü" } $pt.accessToken)

$admin = (Call POST "/api/auth/admin/login" @{ email = $acc.admin.email; password = $acc.admin.password }).body | ConvertFrom-Json
Show "admin: bad status (400)" (Call PATCH "/api/support/tickets/$no/status" @{ durum = "Bitti" } $admin.accessToken)
Show "admin: set İşlemde (200)" (Call PATCH "/api/support/tickets/$no/status" @{ durum = "İşlemde"; not = "Kayıtlarınızı inceliyoruz." } $admin.accessToken)
Show "admin: list İşlemde" (Call GET "/api/support/tickets?durum=$([uri]::EscapeDataString('İşlemde'))" $null $admin.accessToken)
Show "get after update" (Call GET "/api/support/tickets/$no")
