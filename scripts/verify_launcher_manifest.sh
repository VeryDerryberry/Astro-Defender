#!/usr/bin/env bash
# Verify APK: package, launchable badging OR xmltree LAUNCHER on GodotAppLauncher alias.
set -euo pipefail

APK="${1:-/home/derc/Godot/VectorGame/build/AstroDefender.apk}"
PROJECT="${PROJECT:-/home/derc/Godot/VectorGame}"
SCRATCH="${SCRATCH:-/tmp/grok-goal-220491e2a408/implementer}"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"

export ANDROID_HOME
mkdir -p "$SCRATCH"

AAPT=$(ls "$ANDROID_HOME"/build-tools/*/aapt 2>/dev/null | sort -V | tail -1)
test -n "$AAPT" || { echo "FAIL: aapt not found"; exit 1; }
test -f "$APK" || { echo "FAIL: APK missing at $APK"; exit 1; }

EXPECTED_PKG=$(grep '^package/unique_name=' "$PROJECT/export_presets.cfg" | head -1 | sed 's/.*="\(.*\)"/\1/')
test -n "$EXPECTED_PKG" || { echo "FAIL: could not read expected package from export_presets.cfg"; exit 1; }

OUT="$SCRATCH/aapt_launcher_check.txt"
XMLTREE="$SCRATCH/aapt_xmltree_manifest.txt"
ALIAS_BLOCK="$SCRATCH/aapt_alias_block.txt"
"$AAPT" dump badging "$APK" > "$OUT" 2>&1
"$AAPT" dump xmltree "$APK" AndroidManifest.xml > "$XMLTREE" 2>&1
grep -A20 'GodotAppLauncher' "$XMLTREE" > "$ALIAS_BLOCK" || true

{
  echo "=== aapt badging ==="
  cat "$OUT"
  echo ""
  echo "=== aapt badging grep launchable|LAUNCHER ==="
  grep -E 'launchable|LAUNCHER' "$OUT" || true
  echo ""
  echo "=== aapt xmltree GodotAppLauncher block ==="
  cat "$ALIAS_BLOCK"
} > "$SCRATCH/aapt_launcher_combined.txt"

ACTUAL_PKG=$(grep '^package: name=' "$OUT" | sed "s/package: name='\\([^']*\\)'.*/\\1/")
if [ "$ACTUAL_PKG" != "$EXPECTED_PKG" ]; then
  echo "FAIL: package mismatch expected=${EXPECTED_PKG} actual=${ACTUAL_PKG}"
  exit 1
fi

BADGING_OK=no
if grep -qE 'launchable|LAUNCHER' "$OUT"; then
  BADGING_OK=yes
fi

if ! grep -q 'GodotAppLauncher' "$ALIAS_BLOCK"; then
  echo "FAIL: GodotAppLauncher missing in manifest"
  exit 1
fi
if ! grep -A20 'GodotAppLauncher' "$XMLTREE" | grep -q 'android.intent.category.LAUNCHER'; then
  echo "FAIL: LAUNCHER not inside GodotAppLauncher alias intent-filter"
  exit 1
fi
if ! grep -A20 'GodotAppLauncher' "$XMLTREE" | grep -q 'android.intent.action.MAIN'; then
  echo "FAIL: MAIN not inside GodotAppLauncher alias intent-filter"
  exit 1
fi
if ! grep -A20 'GodotAppLauncher' "$XMLTREE" | grep -q 'android:exported(0x01010010)=(type 0x12)0xffffffff'; then
  echo "FAIL: GodotAppLauncher alias not exported=true"
  exit 1
fi

if [ "$BADGING_OK" = "no" ]; then
  echo "OK: badging has no launchable|LAUNCHER line; xmltree alias filter satisfies plan OR clause"
fi

LAUNCHABLE_LINE=$(grep -E 'launchable|LAUNCHER' "$OUT" | head -1 || true)
ALIAS_LAUNCHER_LINE=$(grep 'android.intent.category.LAUNCHER' "$ALIAS_BLOCK" | head -1)

echo "LAUNCHER_MANIFEST_CHECK=PASS" | tee "$SCRATCH/launcher_manifest_evidence.txt"
echo "APK=$APK" | tee -a "$SCRATCH/launcher_manifest_evidence.txt"
echo "PACKAGE=$ACTUAL_PKG" | tee -a "$SCRATCH/launcher_manifest_evidence.txt"
echo "BADGING_LAUNCHABLE_OR_LAUNCHER=$BADGING_OK" | tee -a "$SCRATCH/launcher_manifest_evidence.txt"
if [ -n "$LAUNCHABLE_LINE" ]; then
  echo "$LAUNCHABLE_LINE" | tee -a "$SCRATCH/launcher_manifest_evidence.txt"
fi
echo "$ALIAS_LAUNCHER_LINE" | tee -a "$SCRATCH/launcher_manifest_evidence.txt"
echo "PASS: launcher manifest verified"