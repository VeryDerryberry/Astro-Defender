#!/usr/bin/env bash
set -euo pipefail

SCRATCH="${SCRATCH:-/tmp/grok-goal-98594fc3f297/implementer}"
PROJECT="/home/derc/Godot/VectorGame"
OUT="$SCRATCH/goal_evidence.txt"

mkdir -p "$SCRATCH"

sdk_pass=$(grep -o 'SDK_CHECK_RESULT=PASS' "$SCRATCH/sdk_check.log" | tail -1 || true)
verify1_pass=$(grep -o 'PASS: verify.sh complete' "$SCRATCH/verify_run_pre_1.log" | tail -1 || true)
verify2_pass=$(grep -o 'PASS: verify.sh complete' "$SCRATCH/verify_run_pre_2.log" | tail -1 || true)
touch_cleared=$(grep -o 'RUNTIME touch_thrust_cleared=true' "$SCRATCH/verify_run_pre_2.log" | tail -1 || true)
export1_rc=$(grep -o 'EXPORT_1_EXIT_CODE=[0-9]*' "$SCRATCH/apk_evidence.txt" | tail -1 | cut -d= -f2)
export2_rc=$(grep -o 'EXPORT_2_EXIT_CODE=[0-9]*' "$SCRATCH/apk_evidence.txt" | tail -1 | cut -d= -f2)
export1_adding=$(grep -o 'EXPORT_LOG_EXPORT_1_ADDING=[a-z]*' "$SCRATCH/apk_evidence.txt" | tail -1 | cut -d= -f2)
export1_gradle=$(grep -o 'EXPORT_LOG_EXPORT_1_GRADLE_BUILD=[a-z]*' "$SCRATCH/apk_evidence.txt" | tail -1 | cut -d= -f2)
export1_lines=$(grep -o 'EXPORT_LOG_EXPORT_1_LINES=[0-9]*' "$SCRATCH/apk_evidence.txt" | tail -1 | cut -d= -f2)
gradle_log_line=$(grep -o 'Successfully completed Android gradle build\.' "$SCRATCH/godot_export_1.log" | tail -1 || true)
apk_bytes=$(grep -o 'EXPORT_APK_BYTES=[0-9]*' "$SCRATCH/apk_evidence.txt" | tail -1 | cut -d= -f2)
apk_path=$(grep -o 'EXPORT_APK_PATH=.*' "$SCRATCH/apk_evidence.txt" | tail -1 | cut -d= -f2-)
git_head=$(git -C "$PROJECT" rev-parse --short HEAD 2>/dev/null || echo unknown)

cat > "$OUT" <<EOF
SDK_CHECK=$sdk_pass
VERIFY_RUN_1=$verify1_pass
VERIFY_RUN_2=$verify2_pass
TOUCH_THRUST_CLEARED=$touch_cleared
EXPORT_1_EXIT_CODE=$export1_rc
EXPORT_2_EXIT_CODE=$export2_rc
EXPORT_1_ADDING=$export1_adding
EXPORT_1_GRADLE_BUILD=$export1_gradle
EXPORT_1_LOG_GRADLE_LINE=$gradle_log_line
EXPORT_1_LOG_LINES=$export1_lines
EXPORT_APK_BYTES=$apk_bytes
EXPORT_APK_PATH=$apk_path
GIT_HEAD=$git_head
GOAL_EVIDENCE_RESULT=PASS
EOF
cat "$OUT"