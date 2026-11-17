#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v flutter >/dev/null || { echo "flutter no está en PATH"; exit 1; }
flutter pub get
flutter run "$@"
