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
    elseif ($folder -eq 'android' -and -not (Test-Path 'android/app/src/main/AndroidManifest.xml')) {
      Write-Host 'Host Android incompleto: aggiungo i file mancanti senza sovrascrivere quelli esistenti.'
      $source = Join-Path $tempProject 'android'
      Get-ChildItem $source -File -Recurse -Force | ForEach-Object {
        $relative = $_.FullName.Substring($source.Length).TrimStart('\', '/')
        $destination = Join-Path 'android' $relative
        if (-not (Test-Path $destination)) {
          New-Item -ItemType Directory -Force -Path (Split-Path $destination) | Out-Null
          Copy-Item $_.FullName $destination
        }
      }
    }
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
