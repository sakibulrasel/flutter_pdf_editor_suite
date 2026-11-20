#!/usr/bin/env bash
# Formats every package with `dart format`. CI fails on unformatted code,
# so run this before pushing.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for package in pdf_engine_core pdf_renderer_bridge flutter_pdf_viewer flutter_pdf_editor; do
  (cd "$ROOT/$package" && dart format .)
done
