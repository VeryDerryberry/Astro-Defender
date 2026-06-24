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
    local start_epoch apk_mtime age apk_bytes
    start_epoch=$(cat "$SCRATCH/export_start_epoch")
    apk_mtime=$(stat -c %Y "$apk")
    age=$((apk_mtime - start_epoch))
    apk_bytes=$(stat -c %s "$apk")

    if [ "$has_adding" = "no" ] && [ "$lines" -lt 80 ]; then
      # Gradle exports omit ADDING: lines; accept fresh large APK + export markers.
      if echo "$stripped" | grep -q 'Started Exporting for Android' \
        && echo "$stripped" | grep -q '\[ DONE \] export' \
        && [ "$apk_bytes" -gt 50000000 ] \
        && [ "$age" -ge 0 ] && [ "$age" -le 300 ]; then
        has_adding=gradle
        echo "OK: $label gradle export proof (bytes=$apk_bytes age=${age}s lines=$lines)"
      else
        echo "FAIL: $label log lacks ADDING: ($lines lines) and gradle fallback failed (bytes=$apk_bytes age=${age}s)"
        exit 1
      fi
    elif [ "$age" -lt 0 ] || [ "$age" -gt 300 ]; then
      echo "FAIL: $label APK mtime not within 300s of export start (age=${age}s)"
      exit 1
    fi
  fi

  echo "EXPORT_LOG_${label}_ADDING=$has_adding" | tee -a "$SCRATCH/apk_evidence.txt"
  echo "EXPORT_LOG_${label}_LINES=$lines" | tee -a "$SCRATCH/apk_evidence.txt"
}

"$ANDROID_HOME/platform-tools/adb" start-server >/dev/null 2>&1 || true

echo "=== Plan verification step 4: export APK (twice) ==="
cd "$PROJECT"

ANDROID_SOURCE_ZIP="${ANDROID_SOURCE_ZIP:-/home/derc/.local/share/godot/export_templates/4.6.3.stable/android_source.zip}"

_reinstall_android_template() {
  test -f "$ANDROID_SOURCE_ZIP" || { echo "FAIL: missing $ANDROID_SOURCE_ZIP"; exit 1; }
  rm -rf "$PROJECT/android/build"
  mkdir -p "$PROJECT/android/build"
  unzip -qo "$ANDROID_SOURCE_ZIP" -d "$PROJECT/android/build"
  test -f "$PROJECT/android/build/build.gradle" || { echo "FAIL: android template install"; exit 1; }
  echo "OK: android build template reinstalled"
}

echo "[clean] removing prior APK and export caches for provable full export"
date +%s > "$SCRATCH/export_start_epoch"
rm -f "$PROJECT/build/AstroDefender.apk"
rm -rf "$PROJECT/.godot/exported"
_reinstall_android_template

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

echo "[export 2] full clean reproducibility (same prep as export 1)"
date +%s > "$SCRATCH/export_start_epoch_2"
rm -f "$PROJECT/build/AstroDefender.apk"
rm -rf "$PROJECT/.godot/exported"
_reinstall_android_template

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
cp "$SCRATCH/export_start_epoch_2" "$SCRATCH/export_start_epoch"
_validate_export_log "$SCRATCH/godot_export_2.log" "EXPORT_2" "$APK" 1

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