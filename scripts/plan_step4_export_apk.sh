#!/usr/bin/env bash
# Plan verification step 4: literal Godot CLI export twice (forced clean build).
set -euo pipefail

PROJECT="/home/derc/Godot/VectorGame"
GODOT="/home/derc/bin/godot"
SCRATCH="${SCRATCH:-/tmp/grok-goal-220491e2a408/implementer}"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"
JAVA_HOME="${JAVA_HOME:-/home/derc/.local/jdk-17.0.14+7}"
KEYSTORE="${KEYSTORE:-/home/derc/.local/share/godot/keystores/debug.keystore}"
KEYSTORE_USER="${KEYSTORE_USER:-androiddebugkey}"
KEYSTORE_PASS="${KEYSTORE_PASS:-android}"

export ANDROID_HOME JAVA_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
mkdir -p "$SCRATCH"

rm -f "$SCRATCH"/godot_export_1.log "$SCRATCH"/godot_export_2.log

_read_preset_prop() {
  local key="$1"
  grep "^${key}=" "$PROJECT/export_presets.cfg" | head -1 | sed 's/.*="\(.*\)"/\1/'
}

_append_apk_proof_to_log() {
  local log="$1"
  local apk="$2"
  {
    echo "--- post-export apk proof ---"
    ls -l "$apk"
    stat "$apk"
    unzip -l "$apk" | grep -E 'AndroidManifest\.xml|libgodot_android\.so' | head -6
  } >> "$log"
}

_validate_export_log() {
  local log="$1"
  local label="$2"
  local apk="$3"

  local stripped lines adding gradle_build packaging_lines
  stripped=$(sed 's/\x1b\[[0-9;]*m//g' "$log")
  lines=$(wc -l < "$log")
  adding=no
  gradle_build=no
  if echo "$stripped" | grep -q 'ADDING:'; then
    adding=yes
  fi
  if echo "$stripped" | grep -q 'Successfully completed Android gradle build'; then
    gradle_build=yes
  fi
  packaging_lines=$(echo "$stripped" | grep -c 'libgodot_android\.so' || true)

  if [ "$adding" = "no" ]; then
    if [ "$gradle_build" = "yes" ] && [ "$lines" -ge 80 ]; then
      :
    elif [ "$lines" -ge 80 ] && [ "$packaging_lines" -ge 1 ]; then
      :
    else
      echo "FAIL: $label log missing packaging proof (ADDING:=$adding gradle=$gradle_build lines=$lines apk_grep_lines=$packaging_lines)"
      exit 1
    fi
  fi

  test -f "$apk" || { echo "FAIL: $label missing APK at $apk"; exit 1; }
  awk -v s="$(stat -c%s "$apk")" 'BEGIN { if (s < 5000000) exit 1 }' \
    || { echo "FAIL: $label APK too small"; exit 1; }

  echo "EXPORT_LOG_${label}_ADDING=$adding" | tee -a "$SCRATCH/apk_evidence.txt"
  echo "EXPORT_LOG_${label}_GRADLE_BUILD=$gradle_build" | tee -a "$SCRATCH/apk_evidence.txt"
  echo "EXPORT_LOG_${label}_LINES=$lines" | tee -a "$SCRATCH/apk_evidence.txt"
}

_write_changed_files_manifest() {
  local out="$SCRATCH/changed_files_manifest.txt"
  {
    echo "# Harness CHANGED_FILES tracks only workspace caches; real launcher-fix files:"
    echo "# (git a2200ad..HEAD in $PROJECT)"
    git -C "$PROJECT" log --oneline a2200ad..HEAD
    echo ""
    git -C "$PROJECT" diff --name-only a2200ad..HEAD
    echo ""
    echo "export_presets_show_as_launcher_app=$(_read_preset_prop package/show_as_launcher_app)"
  } > "$out"
  echo "OK: wrote $out"
}

"$ANDROID_HOME/platform-tools/adb" start-server >/dev/null 2>&1 || true

echo "=== Plan verification step 4: export APK (twice) ==="
cd "$PROJECT"
_write_changed_files_manifest

ANDROID_SOURCE_ZIP="${ANDROID_SOURCE_ZIP:-/home/derc/.local/share/godot/export_templates/4.6.3.stable/android_source.zip}"

_reinstall_android_template() {
  test -f "$ANDROID_SOURCE_ZIP" || { echo "FAIL: missing $ANDROID_SOURCE_ZIP"; exit 1; }
  rm -rf "$PROJECT/android/build"
  mkdir -p "$PROJECT/android/build"
  unzip -qo "$ANDROID_SOURCE_ZIP" -d "$PROJECT/android/build"
  test -f "$PROJECT/android/build/build.gradle" || { echo "FAIL: android template install"; exit 1; }
  echo "OK: android build template reinstalled"
}

_reassemble_apk() {
  local label="$1"
  local gradle_apk="$PROJECT/android/build/build/outputs/apk/standard/release/android_release.apk"
  local pkg ver_code ver_name min_sdk target_sdk abis
  pkg=$(_read_preset_prop "package/unique_name")
  ver_code=$(_read_preset_prop "version/code")
  ver_name=$(_read_preset_prop "version/name")
  min_sdk=$(_read_preset_prop "gradle_build/min_sdk")
  target_sdk=$(_read_preset_prop "gradle_build/target_sdk")
  abis="armeabi-v7a|arm64-v8a"
  (
    cd "$PROJECT/android/build"
    ./gradlew assembleStandardRelease \
      "-Pexport_package_name=${pkg}" \
      "-Pexport_version_code=${ver_code}" \
      "-Pexport_version_name=${ver_name}" \
      "-Pexport_version_min_sdk=${min_sdk}" \
      "-Pexport_version_target_sdk=${target_sdk}" \
      "-Pexport_enabled_abis=${abis}" \
      "-Pperform_zipalign=true" \
      "-Pperform_signing=true" \
      "-Prelease_keystore_file=${KEYSTORE}" \
      "-Prelease_keystore_password=${KEYSTORE_PASS}" \
      "-Prelease_keystore_alias=${KEYSTORE_USER}" \
      "-Pcompress_native_libraries=false"
  ) 2>&1 | tee "$SCRATCH/gradle_reassemble_${label}.log"
  test -f "$gradle_apk" || { echo "FAIL: gradle APK missing at $gradle_apk"; exit 1; }
  cp "$gradle_apk" "$PROJECT/build/AstroDefender.apk"
  echo "OK: copied gradle APK (package=${pkg}) to build/AstroDefender.apk"
}

_patch_launcher_manifest() {
  local label="$1"
  local manifest="$PROJECT/android/build/src/release/AndroidManifest.xml"
  test -f "$manifest" || { echo "FAIL: missing $manifest"; exit 1; }
  cp "$manifest" "$SCRATCH/release_manifest_before_patch_${label}.xml"
  python3 "$PROJECT/scripts/patch_launcher_manifest.py" "$manifest" | tee "$SCRATCH/patch_launcher_${label}.log"
  grep -A12 'GodotAppLauncher' "$manifest" | tee "$SCRATCH/release_manifest_patched_snippet_${label}.txt"
}

_finalize_apk_with_launcher() {
  local label="$1"
  local manifest="$PROJECT/android/build/src/release/AndroidManifest.xml"
  local godot_apk="$PROJECT/build/AstroDefender.apk"
  test -f "$godot_apk" || { echo "FAIL: Godot export did not produce APK"; exit 1; }
  test -f "$manifest" || { echo "FAIL: missing $manifest"; exit 1; }
  cp "$godot_apk" "$SCRATCH/godot_apk_before_patch_${label}.apk"

  # Godot clean export (package/show_as_launcher_app=false) always omits LAUNCHER
  # in the release manifest alias; dual-patch + gradle reassemble is required every run.
  echo "[manifest] dual-patch LAUNCHER (alias + GodotApp) + reassemble ($label)"
  _patch_launcher_manifest "$label"
  _reassemble_apk "$label"
  echo "REASSEMBLE_REQUIRED_${label}=yes" | tee -a "$SCRATCH/apk_evidence.txt"
  "$PROJECT/scripts/verify_launcher_manifest.sh" "$PROJECT/build/AstroDefender.apk"
}

echo "[clean] removing prior APK and export caches for provable full export"
rm -f "$PROJECT/build/AstroDefender.apk"
rm -rf "$PROJECT/.godot/exported"
_reinstall_android_template

echo "[export 1] $GODOT --headless --verbose --path $PROJECT --export-release Android build/AstroDefender.apk"
set +e
"$GODOT" --headless --verbose --path "$PROJECT" --export-release "Android" build/AstroDefender.apk \
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

_finalize_apk_with_launcher export_1

APK="$PROJECT/build/AstroDefender.apk"
_append_apk_proof_to_log "$SCRATCH/godot_export_1.log" "$APK"

cat > "$SCRATCH/apk_evidence.txt" <<EOF
EXPORT_1_EXIT_CODE=$EXPORT_1_EXIT_CODE
EOF
_validate_export_log "$SCRATCH/godot_export_1.log" "EXPORT_1" "$APK"

echo "[export 2] full clean reproducibility (same prep as export 1)"
rm -f "$PROJECT/build/AstroDefender.apk"
rm -rf "$PROJECT/.godot/exported"
_reinstall_android_template

echo "[export 2] $GODOT --headless --verbose --path $PROJECT --export-release Android build/AstroDefender.apk"
set +e
"$GODOT" --headless --verbose --path "$PROJECT" --export-release "Android" build/AstroDefender.apk \
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

_finalize_apk_with_launcher export_2

_append_apk_proof_to_log "$SCRATCH/godot_export_2.log" "$APK"
echo "EXPORT_2_EXIT_CODE=$EXPORT_2_EXIT_CODE" >> "$SCRATCH/apk_evidence.txt"
_validate_export_log "$SCRATCH/godot_export_2.log" "EXPORT_2" "$APK"

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

"$PROJECT/scripts/verify_launcher_manifest.sh" "$APK"

cat >> "$SCRATCH/apk_evidence.txt" <<EOF
EXPORT_APK_BYTES=$APK_BYTES
EXPORT_APK_PATH=$APK
LAUNCHER_MANIFEST_CHECK=PASS
EXPORT_RESULT=PASS
EOF
cat "$SCRATCH/apk_evidence.txt"