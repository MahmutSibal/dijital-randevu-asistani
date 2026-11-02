# One command for local development: starts the API (if needed), then `flutter run`.
# Any arguments are passed to flutter run, e.g.  .\scripts\dev.ps1 -d emulator-5554
$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "start-api.ps1")
Set-Location (Join-Path $PSScriptRoot "..")
flutter run @args
