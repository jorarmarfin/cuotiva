#!/usr/bin/env bash
# Levanta Cuotiva para revisarla.
#   ./run.sh            → Linux de escritorio (o el dispositivo Android conectado)
#   ./run.sh android    → fuerza dispositivo/emulador Android
#   ./run.sh test       → analyze + tests
#   ./run.sh clean      → limpia build y regenera código Drift
# Cualquier otro argumento se pasa a `flutter run` (p. ej. -d chrome).
set -euo pipefail
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "flutter no está en PATH"; exit 1; }

case "${1:-}" in
  test)
    flutter pub get
    flutter analyze
    exec flutter test
    ;;
  clean)
    flutter clean
    flutter pub get
    exec dart run build_runner build -d
    ;;
esac

flutter pub get
# Código generado de Drift (si falta)
[ -f lib/core/database/app_database.g.dart ] || dart run build_runner build -d

if [ "${1:-}" = "android" ]; then
  shift
  exec flutter run -d android "$@"
fi
if [ $# -gt 0 ]; then
  exec flutter run "$@"
fi
# Sin argumentos: Android si hay uno conectado; si no, Linux.
if flutter devices 2>/dev/null | grep -qi "android"; then
  exec flutter run -d android
fi
exec flutter run -d linux
