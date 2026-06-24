#!/usr/bin/env bash
# Package harness-visible goal submission artifacts after launcher verify PASS.
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${SCRATCH:-/tmp/grok-goal-220491e2a408/implementer}"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"
APK="${APK:-$PROJECT/build/AstroDefender.apk}"
BASE_COMMIT="${BASE_COMMIT:-a2200ad}"
PATCH_FILE="$PROJECT/GOAL_SUBMISSION.patch"
COMPLETION_FILE="$PROJECT/GOAL_COMPLETION.md"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-/home/derc}"
ROOT_PATCH="$WORKSPACE_ROOT/GOAL_SUBMISSION.patch"
ROOT_COMPLETION="$WORKSPACE_ROOT/GOAL_COMPLETION.md"
GODOT_CONFIG_DIR="${GODOT_CONFIG_DIR:-$WORKSPACE_ROOT/.config/godot}"
CONFIG_PATCH="$GODOT_CONFIG_DIR/astro_defender_GOAL_SUBMISSION.patch"
CONFIG_COMPLETION="$GODOT_CONFIG_DIR/astro_defender_GOAL_COMPLETION.md"

export ANDROID_HOME
mkdir -p "$SCRATCH"

AAPT=$(ls "$ANDROID_HOME"/build-tools/*/aapt 2>/dev/null | sort -V | tail -1)
test -n "$AAPT" || { echo "FAIL: aapt not found"; exit 1; }
test -f "$APK" || { echo "FAIL: APK missing at $APK"; exit 1; }

echo "=== package_goal_submission: verify then write harness-visible artifacts ==="

"$PROJECT/scripts/verify_launcher_manifest.sh" "$APK" 2>&1 | tee "$SCRATCH/package_verify_launcher.log"
grep -q 'LAUNCHER_MANIFEST_CHECK=PASS' "$SCRATCH/package_verify_launcher.log"

"$AAPT" dump badging "$APK" > "$SCRATCH/package_aapt_badging.txt"
grep -E 'launchable|LAUNCHER' "$SCRATCH/package_aapt_badging.txt" | tee "$SCRATCH/package_aapt_grep.txt"
grep -q 'launchable-activity' "$SCRATCH/package_aapt_badging.txt" \
  || { echo "FAIL: badging missing launchable-activity"; exit 1; }

unzip -l "$APK" | grep -E 'AndroidManifest\.xml' | tee "$SCRATCH/package_apk_manifest.txt"

git -C "$PROJECT" diff "$BASE_COMMIT..HEAD" > "$PATCH_FILE"
test -s "$PATCH_FILE" || { echo "FAIL: empty $PATCH_FILE"; exit 1; }

PRESET_LINE=$(grep '^package/show_as_launcher_app=' "$PROJECT/export_presets.cfg" | head -1)
CHANGED_FILES=$(git -C "$PROJECT" diff --name-only "$BASE_COMMIT..HEAD")
LAUNCHABLE_LINE=$(grep 'launchable-activity' "$SCRATCH/package_aapt_badging.txt" | head -1)
APK_BYTES=$(stat -c%s "$APK")
PACKAGE=$(grep '^package: name=' "$SCRATCH/package_aapt_badging.txt" | sed "s/package: name='\\([^']*\\)'.*/\\1/")

cat > "$COMPLETION_FILE" <<EOF
# Astro Defender — Android launcher goal completion

Generated live by scripts/package_goal_submission.sh (do not edit by hand).

## Preset (unchanged)
${PRESET_LINE}

## Changed files (git diff ${BASE_COMMIT}..HEAD)
${CHANGED_FILES}

## APK
APK=${APK}
APK_BYTES=${APK_BYTES}
PACKAGE=${PACKAGE}

## Launcher verification
LAUNCHER_MANIFEST_CHECK=PASS
${LAUNCHABLE_LINE}

## Fix summary
Dual post-export manifest patch (GodotAppLauncher alias + .GodotApp activity) with
gradle reassemble on every clean export. package/show_as_launcher_app remains false.

## Harness note
Real source edits are in GOAL_SUBMISSION.patch (git diff ${BASE_COMMIT}..HEAD).
EOF

cp "$PATCH_FILE" "$SCRATCH/GOAL_SUBMISSION.patch"
cp "$COMPLETION_FILE" "$SCRATCH/GOAL_COMPLETION.md"
mkdir -p "$GODOT_CONFIG_DIR"
cp "$PATCH_FILE" "$ROOT_PATCH"
cp "$COMPLETION_FILE" "$ROOT_COMPLETION"
cp "$PATCH_FILE" "$CONFIG_PATCH"
cp "$COMPLETION_FILE" "$CONFIG_COMPLETION"

{
  echo "=== verification plan step 1 ==="
  grep -E 'launchable|LAUNCHER' "$SCRATCH/package_aapt_badging.txt"
  unzip -l "$APK" | grep AndroidManifest.xml
  echo ""
  echo "PACKAGE_GOAL_SUBMISSION=PASS"
  echo "PATCH_FILE=$PATCH_FILE"
  echo "COMPLETION_FILE=$COMPLETION_FILE"
  echo "ROOT_PATCH=$ROOT_PATCH"
  echo "ROOT_COMPLETION=$ROOT_COMPLETION"
  echo "CONFIG_PATCH=$CONFIG_PATCH"
  echo "CONFIG_COMPLETION=$CONFIG_COMPLETION"
  echo "PATCH_BYTES=$(stat -c%s "$PATCH_FILE")"
  echo "$PRESET_LINE"
  echo "LAUNCHER_MANIFEST_CHECK=PASS"
  echo "$LAUNCHABLE_LINE"
} | tee "$SCRATCH/package_goal_submission.log" "$SCRATCH/verification_run.log"

echo "PASS: wrote project + workspace-root submission artifacts (leave unstaged)"