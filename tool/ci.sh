#!/usr/bin/env bash
# Checks formatting, analyzes and tests every package in dependency order.
#
# The repo is a pub workspace (see the root pubspec.yaml), so one
# `flutter pub get` at the root links all packages and examples together.
#
# Usage, from anywhere:  tool/ci.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT"
flutter pub get

# Pure Dart package.
echo "::group::pdf_engine_core"
cd "$ROOT/pdf_engine_core"
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
echo "::endgroup::"

# Flutter packages, lowest layer first.
for package in pdf_renderer_bridge flutter_pdf_viewer flutter_pdf_editor; do
  echo "::group::$package"
  cd "$ROOT/$package"
  dart format --output=none --set-exit-if-changed .
  flutter analyze --no-fatal-infos
  flutter test
  echo "::endgroup::"
done

echo "All packages formatted, analyzed and tested."
