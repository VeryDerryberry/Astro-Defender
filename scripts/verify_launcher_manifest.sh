#!/usr/bin/env bash
# Verify APK has a launcher-visible activity alias (MAIN + LAUNCHER + exported).
set -euo pipefail

APK="${1:-/home/derc/Godot/VectorGame/build/AstroDefender.apk}"
SCRATCH="${SCRATCH:-/tmp/grok-goal-220491e2a408/implementer}"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"

export ANDROID_HOME
mkdir -p "$SCRATCH"

AAPT=$(ls "$ANDROID_HOME"/build-tools/*/aapt 2>/dev/null | sort -V | tail -1)
test -n "$AAPT" || { echo "FAIL: aapt not found"; exit 1; }
test -f "$APK" || { echo "FAIL: APK missing at $APK"; exit 1; }

OUT="$SCRATCH/aapt_launcher_check.txt"
XMLTREE="$SCRATCH/aapt_xmltree_manifest.txt"
"$AAPT" dump badging "$APK" > "$OUT" 2>&1
"$AAPT" dump xmltree "$APK" AndroidManifest.xml > "$XMLTREE" 2>&1

{
  echo "=== aapt badging ==="
  cat "$OUT"
  echo ""
  echo "=== aapt xmltree (GodotAppLauncher block) ==="
  grep -A15 'GodotAppLauncher' "$XMLTREE" || true
} > "$SCRATCH/aapt_launcher_combined.txt"

if ! grep -q 'GodotAppLauncher' "$XMLTREE"; then
  echo "FAIL: GodotAppLauncher missing in manifest"
  exit 1
fi
if ! grep -q 'android.intent.category.LAUNCHER' "$XMLTREE"; then
  echo "FAIL: LAUNCHER category missing in manifest"
  exit 1
fi
if ! grep -q 'android.intent.action.MAIN' "$XMLTREE"; then
  echo "FAIL: MAIN action missing in manifest"
  exit 1
fi
if ! grep -A15 'GodotAppLauncher' "$XMLTREE" | grep -q 'android:exported(0x01010010)=(type 0x12)0xffffffff'; then
  echo "FAIL: GodotAppLauncher not exported=true"
  exit 1
fi

echo "LAUNCHER_MANIFEST_CHECK=PASS" | tee "$SCRATCH/launcher_manifest_evidence.txt"
echo "APK=$APK" | tee -a "$SCRATCH/launcher_manifest_evidence.txt"
grep 'GodotAppLauncher' "$XMLTREE" | head -1 | tee -a "$SCRATCH/launcher_manifest_evidence.txt"
grep 'android.intent.category.LAUNCHER' "$XMLTREE" | head -1 | tee -a "$SCRATCH/launcher_manifest_evidence.txt"
echo "PASS: launcher manifest verified"