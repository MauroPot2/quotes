$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter 3.50+ non trovato nel PATH.'
}
flutter --version
$tempProject = Join-Path $env:TEMP ("preventivo_flutter_" + [guid]::NewGuid().ToString('N'))
try {
  flutter create --platforms=android,windows --project-name preventivo --org com.mauropot --no-pub $tempProject
  if ($LASTEXITCODE -ne 0) { throw 'flutter create non riuscito' }
  foreach ($folder in @('android', 'windows')) {
    if (-not (Test-Path $folder)) { Copy-Item (Join-Path $tempProject $folder) $folder -Recurse }
  }
  if (-not (Test-Path '.metadata')) { Copy-Item (Join-Path $tempProject '.metadata') '.metadata' }
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get non riuscito' }
  flutter analyze --no-fatal-infos
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze segnala problemi' }
  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'flutter test non riuscito' }
} finally {
  if (Test-Path $tempProject) { Remove-Item $tempProject -Force -Recurse }
}
Write-Host 'Pronto: flutter run -d windows (oppure Android).'
