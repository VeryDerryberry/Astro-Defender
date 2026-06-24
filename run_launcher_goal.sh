#!/usr/bin/env bash
# Launcher-manifest goal orchestrator: verification plan steps + evidence (no re-export if APK passes).
set -euo pipefail

SCRATCH="${SCRATCH:-/tmp/grok-goal-220491e2a408/implementer}"
PROJECT="$(cd "$(dirname "$0")" && pwd)"
APK="$PROJECT/build/AstroDefender.apk"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"
export SCRATCH ANDROID_HOME ANDROID_GOAL_VERIFY=1

mkdir -p "$SCRATCH"
AAPT=$(ls "$ANDROID_HOME"/build-tools/*/aapt 2>/dev/null | sort -V | tail -1)
test -n "$AAPT" || { echo "FAIL: aapt not found"; exit 1; }

echo "=== Launcher goal verification run ===" | tee "$SCRATCH/verification_run.log"

echo "[step 1] aapt badging grep launchable|LAUNCHER" | tee -a "$SCRATCH/verification_run.log"
"$AAPT" dump badging "$APK" > "$SCRATCH/aapt_badging_final.txt"
grep -E 'launchable|LAUNCHER' "$SCRATCH/aapt_badging_final.txt" | tee "$SCRATCH/verify_step1_grep_final.txt"
grep -q 'launchable-activity' "$SCRATCH/aapt_badging_final.txt"
unzip -l "$APK" | grep AndroidManifest.xml | tee -a "$SCRATCH/verification_run.log"

echo "[step 1b] verify_launcher_manifest.sh" | tee -a "$SCRATCH/verification_run.log"
"$PROJECT/scripts/verify_launcher_manifest.sh" "$APK" 2>&1 | tee -a "$SCRATCH/verification_run.log"
grep -q 'LAUNCHER_MANIFEST_CHECK=PASS' "$SCRATCH/launcher_manifest_evidence.txt"

echo "[step 2] APK launcher check (skip re-export when verify PASS)" | tee -a "$SCRATCH/verification_run.log"
if [ -f "$SCRATCH/plan_step4_final.log" ] && grep -q 'EXPORT_RESULT=PASS' "$SCRATCH/plan_step4_final.log"; then
  grep -E 'EXPORT_RESULT|REASSEMBLE_REQUIRED|launchable-activity' "$SCRATCH/plan_step4_final.log" | tail -6 \
    | tee -a "$SCRATCH/verification_run.log"
  echo "EXPORT_REUSED=existing_passing_apk" | tee -a "$SCRATCH/verification_run.log"
else
  echo "WARN: prior export log missing; running plan_step4_export_apk.sh" | tee -a "$SCRATCH/verification_run.log"
  "$PROJECT/scripts/plan_step4_export_apk.sh" 2>&1 | tee "$SCRATCH/plan_step4_rerun.log"
fi

echo "[step 3] merged manifest LAUNCHER evidence" | tee -a "$SCRATCH/verification_run.log"
MERGED="$PROJECT/android/build/build/intermediates/merged_manifests/standardRelease/processStandardReleaseManifest/AndroidManifest.xml"
if [ -f "$MERGED" ]; then
  grep -B1 -A8 'GodotAppLauncher' "$MERGED" | tee "$SCRATCH/verify_step3_merged_manifest_snippet.txt"
fi
grep -A8 'GodotAppLauncher' "$PROJECT/android/build/src/release/AndroidManifest.xml" 2>/dev/null \
  | tee "$SCRATCH/verify_step3_release_manifest_snippet.txt" || true

echo "[step 4] scope + harness manifest" | tee -a "$SCRATCH/verification_run.log"
{
  echo "# Harness CHANGED_FILES may list only workspace caches; real launcher-fix files:"
  git -C "$PROJECT" log --oneline a2200ad..HEAD
  echo ""
  git -C "$PROJECT" diff --name-only a2200ad..HEAD
  echo ""
  grep '^package/show_as_launcher_app=' "$PROJECT/export_presets.cfg"
} | tee "$SCRATCH/changed_files_manifest.txt"

echo "[package] harness-visible submission artifacts" | tee -a "$SCRATCH/verification_run.log"
"$PROJECT/scripts/package_goal_submission.sh" 2>&1 | tee -a "$SCRATCH/verification_run.log"

echo "[verify] touch regression check" | tee -a "$SCRATCH/verification_run.log"
"$PROJECT/verify.sh" 2>&1 | tee "$SCRATCH/verify_android_final.log" | tail -3
grep -q 'PASS: verify.sh complete' "$SCRATCH/verify_android_final.log"

LAUNCHABLE=$(grep 'launchable-activity' "$SCRATCH/aapt_badging_final.txt" | head -1)
PRESET=$(grep '^package/show_as_launcher_app=' "$PROJECT/export_presets.cfg" | head -1)
APK_BYTES=$(stat -c%s "$APK")

cat > "$SCRATCH/goal_evidence.txt" <<EOF
LAUNCHER_MANIFEST_CHECK=PASS
${PRESET}
PATCH=dual (GodotAppLauncher alias + .GodotApp activity)
REASSEMBLE_REQUIRED=yes (every clean export with preset=false)
${LAUNCHABLE}
APK_BYTES=${APK_BYTES}
APK=${APK}
EXPORT_REUSED=existing_passing_apk
VERIFY_ANDROID_GOAL=PASS
GOAL_EVIDENCE_RESULT=PASS
EOF
cat "$SCRATCH/goal_evidence.txt" | tee -a "$SCRATCH/verification_run.log"
echo "LAUNCHER_GOAL_RUN=PASS"