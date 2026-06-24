#!/usr/bin/env bash
# Orchestrator matching plan.md verification steps 1, 3, 4, 5.
set -euo pipefail

SCRATCH="${SCRATCH:-/tmp/grok-goal-220491e2a408/implementer}"
PROJECT="$(cd "$(dirname "$0")" && pwd)"
export SCRATCH
export ANDROID_GOAL_VERIFY=1

mkdir -p "$SCRATCH"
rm -f "$SCRATCH"/verify_run_pre_*.log "$SCRATCH"/verify_run_post.log
rm -f "$SCRATCH"/godot_export_*.log "$SCRATCH"/apk_evidence.txt "$SCRATCH"/goal_evidence.txt

echo "=== Step 1: SDK check ==="
"$PROJECT/scripts/plan_step1_sdk_check.sh"

echo "=== Step 3: verify.sh touch mode (run 1) ==="
"$PROJECT/verify.sh" 2>&1 | tee "$SCRATCH/verify_run_pre_1.log"
grep -q 'PASS: verify.sh complete' "$SCRATCH/verify_run_pre_1.log"

echo "=== Step 3: verify.sh touch mode (run 2) ==="
"$PROJECT/verify.sh" 2>&1 | tee "$SCRATCH/verify_run_pre_2.log"
grep -q 'PASS: verify.sh complete' "$SCRATCH/verify_run_pre_2.log"
grep -q 'touch_thrust_cleared=true' "$SCRATCH/verify_run_pre_2.log"

echo "=== Step 4: export APK twice (forced clean) ==="
"$PROJECT/scripts/plan_step4_export_apk.sh"

echo "=== Step 4: re-run verify.sh ==="
"$PROJECT/verify.sh" 2>&1 | tee "$SCRATCH/verify_run_post.log"
grep -q 'PASS: verify.sh complete' "$SCRATCH/verify_run_post.log"

echo "=== Step 5: evidence ==="
ls -la "$PROJECT/build/" | tee "$SCRATCH/build_ls.txt"
(cd "$PROJECT" && git ls-files) > "$SCRATCH/changed_files_manifest.txt"
"$PROJECT/scripts/plan_step5_summary.sh"

cat > "$SCRATCH/goal_run_summary.txt" <<EOF
GOAL_RUN_RESULT=PASS
SCRATCH=$SCRATCH
EVIDENCE=$SCRATCH/goal_evidence.txt
APK=$PROJECT/build/AstroDefender.apk
EOF
cat "$SCRATCH/goal_run_summary.txt"