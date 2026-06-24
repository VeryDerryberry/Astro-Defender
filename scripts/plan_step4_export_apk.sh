#!/usr/bin/env bash
set -euo pipefail

PROJECT="/home/derc/Godot/VectorGame"
GODOT="/home/derc/bin/godot"
SCRATCH="${SCRATCH:-/tmp/grok-goal-98594fc3f297/implementer}"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"
JAVA_HOME="${JAVA_HOME:-/home/derc/.local/jdk-17.0.14+7}"
APK_REL="build/AstroDefender.apk"

export ANDROID_HOME JAVA_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
mkdir -p "$SCRATCH"

rm -f "$SCRATCH"/godot_export*.log

"$ANDROID_HOME/platform-tools/adb" start-server >/dev/null 2>&1 || true

echo "=== Plan step 4: Android APK export (twice) ==="

cd "$PROJECT"

echo "[export 1]"
set +e
"$GODOT" --headless --path /home/derc/Godot/VectorGame --export-release "Android" "$APK_REL" \
  2>&1 | tee "$SCRATCH/godot_export_1.log"
EXPORT_1_EXIT_CODE=${PIPESTATUS[0]}
set -e
echo "EXPORT_1_EXIT_CODE=$EXPORT_1_EXIT_CODE"

if [ "$EXPORT_1_EXIT_CODE" -ne 0 ]; then
  echo "FAIL: export 1 exit $EXPORT_1_EXIT_CODE"
  exit 1
fi
if grep -qiE 'ERROR: (Cannot export|Project export for preset)' "$SCRATCH/godot_export_1.log"; then
  echo "FAIL: export 1 configuration error"
  exit 1
fi
sed 's/\x1b\[[0-9;]*m//g' "$SCRATCH/godot_export_1.log" | grep -q '\[ DONE \] export' \
  || { echo "FAIL: export 1 missing DONE"; exit 1; }

echo "[export 2]"
set +e
"$GODOT" --headless --path /home/derc/Godot/VectorGame --export-release "Android" "$APK_REL" \
  2>&1 | tee "$SCRATCH/godot_export_2.log"
EXPORT_2_EXIT_CODE=${PIPESTATUS[0]}
set -e
echo "EXPORT_2_EXIT_CODE=$EXPORT_2_EXIT_CODE"

if [ "$EXPORT_2_EXIT_CODE" -ne 0 ]; then
  echo "FAIL: export 2 exit $EXPORT_2_EXIT_CODE"
  exit 1
fi
if grep -qiE 'ERROR: (Cannot export|Project export for preset)' "$SCRATCH/godot_export_2.log"; then
  echo "FAIL: export 2 configuration error"
  exit 1
fi
sed 's/\x1b\[[0-9;]*m//g' "$SCRATCH/godot_export_2.log" | grep -q '\[ DONE \] export' \
  || { echo "FAIL: export 2 missing DONE"; exit 1; }

APK="$PROJECT/$APK_REL"
ls -l "$APK" | tee "$SCRATCH/apk_ls.txt"
APK_BYTES=$(stat -c%s "$APK")
echo "EXPORT_APK_BYTES=$APK_BYTES"
awk -v s="$APK_BYTES" 'BEGIN { if (s < 5000000) exit 1 }' \
  || { echo "FAIL: APK too small ($APK_BYTES)"; exit 1; }

unzip -l "$APK" > "$SCRATCH/apk_listing.txt"
grep -E 'AndroidManifest|libgodot|assets/' "$SCRATCH/apk_listing.txt" | head -20 | tee "$SCRATCH/apk_grep.txt"
grep -q 'AndroidManifest.xml' "$SCRATCH/apk_listing.txt" || { echo "FAIL: no AndroidManifest"; exit 1; }
grep -q 'libgodot' "$SCRATCH/apk_listing.txt" || { echo "FAIL: no libgodot"; exit 1; }
grep -q 'assets/' "$SCRATCH/apk_listing.txt" || { echo "FAIL: no assets"; exit 1; }

cat > "$SCRATCH/apk_evidence.txt" <<EOF
EXPORT_1_EXIT_CODE=$EXPORT_1_EXIT_CODE
EXPORT_2_EXIT_CODE=$EXPORT_2_EXIT_CODE
EXPORT_APK_BYTES=$APK_BYTES
EXPORT_APK_PATH=$APK
EXPORT_RESULT=PASS
EOF
cat "$SCRATCH/apk_evidence.txt"