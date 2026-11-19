#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter non trovato. Installa Flutter 3.50+ e verifica flutter doctor.' >&2
  exit 1
fi

echo '=== Versione Flutter ==='
flutter --version

echo '=== Genero solo gli host nativi senza sovrascrivere lib/ o pubspec.yaml ==='
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT
flutter create --platforms=android,ios,macos --project-name preventivo --org com.mauropot --no-pub "$TEMP_DIR/preventivo"
for platform in android ios macos; do
  if [[ ! -d "$platform" ]]; then
    cp -R "$TEMP_DIR/preventivo/$platform" "./$platform"
  elif [[ "$platform" == android && ! -f android/app/src/main/AndroidManifest.xml ]]; then
    echo 'Host Android incompleto: aggiungo i file mancanti senza sovrascrivere quelli esistenti.'
    cp -Rn "$TEMP_DIR/preventivo/android/." ./android/
  else
    echo "Host $platform già presente: non lo sovrascrivo."
  fi
done
if [[ ! -f .metadata ]]; then
  cp "$TEMP_DIR/preventivo/.metadata" .metadata
fi

echo '=== Dipendenze ==='
flutter pub get

echo '=== Analisi statica ==='
flutter analyze --no-fatal-infos

echo '=== Test ==='
flutter test

echo '=== Pronto: flutter run -d macos (oppure il tuo dispositivo Android/iOS) ==='
