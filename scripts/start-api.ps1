# Starts the .NET API in its own window unless something already answers on :5233,
# then waits until it does. Used by dev.ps1 and the VS Code pre-launch task.
$ErrorActionPreference = "Stop"
$port = 5233
$project = Join-Path $PSScriptRoot "..\WebAppointment.Api\WebAppointmentApi.WebApi"

function Test-Api {
    try {
        $c = New-Object Net.Sockets.TcpClient
        $c.Connect("127.0.0.1", $port); $c.Close(); return $true
    } catch { return $false }
}

if (Test-Api) { Write-Host "API zaten çalışıyor (http://localhost:$port)."; exit 0 }

Write-Host "API başlatılıyor (ayrı pencerede)..."
$cmd = "`$env:DOTNET_ROLL_FORWARD='Major'; `$env:ASPNETCORE_ENVIRONMENT='Development'; " +
       "`$host.UI.RawUI.WindowTitle='WebAppointment API :$port'; dotnet run --project '$project'"
Start-Process powershell -ArgumentList "-NoExit", "-Command", $cmd | Out-Null

$deadline = (Get-Date).AddMinutes(3)
while (-not (Test-Api)) {
    if ((Get-Date) -gt $deadline) { Write-Error "API 3 dakikada ayağa kalkmadı; API penceresindeki hataya bak." }
    Start-Sleep -Seconds 2
}
Write-Host "API hazır: http://localhost:$port"
