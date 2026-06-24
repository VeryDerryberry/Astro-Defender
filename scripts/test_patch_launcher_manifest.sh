#!/usr/bin/env bash
# Unit test: dual patch adds LAUNCHER to alias and GodotApp activity blocks.
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${SCRATCH:-/tmp/grok-goal-220491e2a408/implementer}"
FIXTURE="$PROJECT/scripts/fixtures/release_manifest_godot_stub.xml"
PATCHED="$SCRATCH/test_manifest_patched.xml"

mkdir -p "$SCRATCH"
test -f "$FIXTURE" || { echo "FAIL: missing fixture $FIXTURE"; exit 1; }

cp "$FIXTURE" "$PATCHED"
python3 "$PROJECT/scripts/patch_launcher_manifest.py" "$PATCHED"

grep -A12 'GodotAppLauncher' "$PATCHED" | grep -q 'android.intent.category.LAUNCHER' \
  || { echo "FAIL: LAUNCHER not in alias intent-filter"; exit 1; }
grep -A12 'GodotAppLauncher' "$PATCHED" | grep -q 'android.intent.action.MAIN' \
  || { echo "FAIL: MAIN not in alias intent-filter"; exit 1; }
grep -A2 'GodotAppLauncher' "$PATCHED" | grep -q 'android:exported="true"' \
  || { echo "FAIL: alias not exported=true"; exit 1; }

grep -A12 'android:name=".GodotApp"' "$PATCHED" | grep -q 'android:exported="true"' \
  || { echo "FAIL: GodotApp not exported=true"; exit 1; }
grep -A12 'android:name=".GodotApp"' "$PATCHED" | grep -q 'android.intent.category.LAUNCHER' \
  || { echo "FAIL: LAUNCHER not in GodotApp intent-filter"; exit 1; }
grep -A12 'android:name=".GodotApp"' "$PATCHED" | grep -q 'android.intent.action.MAIN' \
  || { echo "FAIL: MAIN not in GodotApp intent-filter"; exit 1; }

echo "TEST_PATCH_LAUNCHER_MANIFEST=PASS" | tee "$SCRATCH/test_patch_launcher_manifest.log"
echo "PASS: test_patch_launcher_manifest.sh"