#!/usr/bin/env bash
# Gets dependencies, analyzes and tests every package in dependency order.
#
# Local path links between the packages come from the committed
# pubspec_overrides.yaml files, so this works without melos or a pub workspace.
#
# Usage, from anywhere:  tool/ci.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Pure Dart package.
echo "::group::pdf_engine_core"
cd "$ROOT/pdf_engine_core"
dart pub get
dart analyze
dart test
echo "::endgroup::"

# Flutter packages, lowest layer first.
for package in pdf_renderer_bridge flutter_pdf_viewer flutter_pdf_editor; do
  echo "::group::$package"
  cd "$ROOT/$package"
  flutter pub get
  if [ -f example/pubspec.yaml ]; then
    (cd example && flutter pub get)
  fi
  flutter analyze --no-fatal-infos
  flutter test
  echo "::endgroup::"
done

echo "All packages analyzed and tested."
