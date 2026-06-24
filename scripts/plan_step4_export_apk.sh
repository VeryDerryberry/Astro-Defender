#!/usr/bin/env bash
# Plan verification step 4: literal Godot CLI export twice (forced clean build).
set -euo pipefail

PROJECT="/home/derc/Godot/VectorGame"
GODOT="/home/derc/bin/godot"
SCRATCH="${SCRATCH:-/tmp/grok-goal-98594fc3f297/implementer}"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"
JAVA_HOME="${JAVA_HOME:-/home/derc/.local/jdk-17.0.14+7}"

export ANDROID_HOME JAVA_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
mkdir -p "$SCRATCH"

rm -f "$SCRATCH"/godot_export_1.log "$SCRATCH"/godot_export_2.log

_validate_export_log() {
  local log="$1"
  local label="$2"
  local apk="$3"
  local require_work="${4:-1}"

  local stripped lines has_adding
  stripped=$(sed 's/\x1b\[[0-9;]*m//g' "$log")
  lines=$(wc -l < "$log")
  has_adding=no
  if echo "$stripped" | grep -q 'ADDING:'; then
    has_adding=yes
  fi

  if [ "$require_work" = "1" ]; then
    if [ "$has_adding" = "no" ] && [ "$lines" -lt 80 ]; then
      echo "FAIL: $label log lacks ADDING: and has only $lines lines (need proof of packaging)"
      exit 1
    fi
    local start_epoch apk_mtime age
    start_epoch=$(cat "$SCRATCH/export_start_epoch")
    apk_mtime=$(stat -c %Y "$apk")
    age=$((apk_mtime - start_epoch))
    if [ "$age" -lt 0 ] || [ "$age" -gt 120 ]; then
      echo "FAIL: $label APK mtime not within 120s of export start (age=${age}s)"
      exit 1
    fi
  fi

  echo "EXPORT_LOG_${label}_ADDING=$has_adding" | tee -a "$SCRATCH/apk_evidence.txt"
  echo "EXPORT_LOG_${label}_LINES=$lines" | tee -a "$SCRATCH/apk_evidence.txt"
}

"$ANDROID_HOME/platform-tools/adb" start-server >/dev/null 2>&1 || true

echo "=== Plan verification step 4: export APK (twice) ==="
cd "$PROJECT"

echo "[clean] removing prior APK and export caches for provable full export"
date +%s > "$SCRATCH/export_start_epoch"
rm -f "$PROJECT/build/AstroDefender.apk"
rm -rf "$PROJECT/android/build" "$PROJECT/.godot/exported"

echo "[export 1] $GODOT --headless --path $PROJECT --export-release Android build/AstroDefender.apk"
set +e
"$GODOT" --headless --path "$PROJECT" --export-release "Android" build/AstroDefender.apk \
  2>&1 | tee "$SCRATCH/godot_export_1.log"
EXPORT_1_EXIT_CODE=${PIPESTATUS[0]}
set -e
echo "EXPORT_1_EXIT_CODE=$EXPORT_1_EXIT_CODE"
[ "$EXPORT_1_EXIT_CODE" -eq 0 ] || { echo "FAIL: export 1"; exit 1; }
if grep -qiE 'ERROR: (Cannot export|Project export for preset)' "$SCRATCH/godot_export_1.log"; then
  echo "FAIL: export 1 configuration error"
  exit 1
fi
sed 's/\x1b\[[0-9;]*m//g' "$SCRATCH/godot_export_1.log" | grep -q '\[ DONE \] export' \
  || { echo "FAIL: export 1 missing DONE"; exit 1; }

APK="$PROJECT/build/AstroDefender.apk"
test -f "$APK" || { echo "FAIL: export 1 did not produce APK"; exit 1; }

cat > "$SCRATCH/apk_evidence.txt" <<EOF
EXPORT_1_EXIT_CODE=$EXPORT_1_EXIT_CODE
EOF
_validate_export_log "$SCRATCH/godot_export_1.log" "EXPORT_1" "$APK" 1

echo "[export 2] $GODOT --headless --path $PROJECT --export-release Android build/AstroDefender.apk"
set +e
"$GODOT" --headless --path "$PROJECT" --export-release "Android" build/AstroDefender.apk \
  2>&1 | tee "$SCRATCH/godot_export_2.log"
EXPORT_2_EXIT_CODE=${PIPESTATUS[0]}
set -e
echo "EXPORT_2_EXIT_CODE=$EXPORT_2_EXIT_CODE"
[ "$EXPORT_2_EXIT_CODE" -eq 0 ] || { echo "FAIL: export 2"; exit 1; }
if grep -qiE 'ERROR: (Cannot export|Project export for preset)' "$SCRATCH/godot_export_2.log"; then
  echo "FAIL: export 2 configuration error"
  exit 1
fi
sed 's/\x1b\[[0-9;]*m//g' "$SCRATCH/godot_export_2.log" | grep -q '\[ DONE \] export' \
  || { echo "FAIL: export 2 missing DONE"; exit 1; }

echo "EXPORT_2_EXIT_CODE=$EXPORT_2_EXIT_CODE" >> "$SCRATCH/apk_evidence.txt"
_validate_export_log "$SCRATCH/godot_export_2.log" "EXPORT_2" "$APK" 0

ls -l "$APK" | tee "$SCRATCH/apk_ls.txt"
APK_BYTES=$(stat -c%s "$APK")
echo "EXPORT_APK_BYTES=$APK_BYTES"
awk -v s="$APK_BYTES" 'BEGIN { if (s < 5000000) exit 1 }' \
  || { echo "FAIL: APK too small"; exit 1; }

unzip -l "$APK" | grep -E 'AndroidManifest|libgodot|assets/' | tee "$SCRATCH/apk_grep.txt"
unzip -l "$APK" > "$SCRATCH/apk_listing.txt"
grep -q 'AndroidManifest.xml' "$SCRATCH/apk_listing.txt"
grep -q 'libgodot' "$SCRATCH/apk_listing.txt"
grep -q 'assets/' "$SCRATCH/apk_listing.txt"

cat >> "$SCRATCH/apk_evidence.txt" <<EOF
EXPORT_APK_BYTES=$APK_BYTES
EXPORT_APK_PATH=$APK
EXPORT_RESULT=PASS
EOF
cat "$SCRATCH/apk_evidence.txt"