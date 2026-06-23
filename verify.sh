#!/usr/bin/env bash
set -euo pipefail

PROJECT="/home/derc/Godot/VectorGame"
GODOT="/home/derc/bin/godot"
SCRATCH="${SCRATCH:-/tmp/grok-goal-24707ec209ef/implementer}"
mkdir -p "$SCRATCH"

echo "=== Astro Defender verification (plan VP) ==="

echo "[VP-1a] Headless launch 1 (main.tscn --verify)"
set +e
"$GODOT" --headless --path "$PROJECT" -- --verify --quit-after 600 2>&1 | tee "$SCRATCH/godot_launch_1.log"
LAUNCH1_RC=${PIPESTATUS[0]}
set -e
if [ "$LAUNCH1_RC" -ne 0 ]; then
  echo "FAIL: launch 1 exit code $LAUNCH1_RC"
  exit 1
fi
if grep -qiE "Can't run project|fatal|SCRIPT ERROR|Parse Error" "$SCRATCH/godot_launch_1.log"; then
  echo "FAIL: launch 1 errors"
  exit 1
fi
grep -q 'RUNTIME verify_exit=0' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: verify did not pass in launch 1"; exit 1; }
grep -q 'RUNTIME game_started=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: game not started via input"; exit 1; }
grep -q 'RUNTIME options_applied=' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: options not applied"; exit 1; }
grep -q 'RUNTIME touch_events_processed=' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: touch not processed"; exit 1; }
grep -q 'RUNTIME sfx_played=' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: sfx not played"; exit 1; }
grep -q 'RUNTIME music_looping=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: music not looping"; exit 1; }
grep -q 'RUNTIME spawner_enemy_count=' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: spawner did not run"; exit 1; }
grep -q 'RUNTIME wall_right_inside=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: right wall confinement"; exit 1; }
grep -q 'RUNTIME wall_left_inside=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: left wall confinement"; exit 1; }
grep -q 'RUNTIME lives_after_hit=2' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: collision lives"; exit 1; }
grep -q 'RUNTIME score_after_shot=100' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: projectile score"; exit 1; }

WALL_VEL=$(grep '^RUNTIME wall_right_velocity=' "$SCRATCH/godot_launch_1.log" | tail -1 | cut -d= -f2)
awk -v v="$WALL_VEL" 'BEGIN { if (v > 5.0) exit 1 }'

echo "[VP-1b] Headless launch 2 (main.tscn --verify)"
set +e
"$GODOT" --headless --path "$PROJECT" -- --verify --quit-after 600 2>&1 | tee "$SCRATCH/godot_launch_2.log"
LAUNCH2_RC=${PIPESTATUS[0]}
set -e
if [ "$LAUNCH2_RC" -ne 0 ]; then
  echo "FAIL: launch 2 exit code $LAUNCH2_RC"
  exit 1
fi
if grep -qiE "Can't run project|fatal|SCRIPT ERROR|Parse Error" "$SCRATCH/godot_launch_2.log"; then
  echo "FAIL: launch 2 errors"
  exit 1
fi
grep -q 'RUNTIME verify_exit=0' "$SCRATCH/godot_launch_2.log" || { echo "FAIL: verify did not pass in launch 2"; exit 1; }

echo "[VP-2] project.godot"
grep -q 'config_version=5' "$PROJECT/project.godot"
grep -q 'config/name="Astro Defender"' "$PROJECT/project.godot"
grep -q '"4.6"' "$PROJECT/project.godot"
grep -q 'run/main_scene="res://main.tscn"' "$PROJECT/project.godot"
grep -q 'GameOptions=' "$PROJECT/project.godot"
grep -q 'TouchInput=' "$PROJECT/project.godot"
grep -q 'AudioManager=' "$PROJECT/project.godot"

echo "[VP-3] Source inspection"
for term in Line2D Polygon2D rotate thrust spawn wave lives score game_over start; do
  grep -rq "$term" "$PROJECT/scenes" "$PROJECT/scripts" "$PROJECT/main.tscn" || {
    echo "FAIL: missing term $term"
    exit 1
  }
done
grep -rq 'InputEventScreenTouch' "$PROJECT/scripts"
grep -rq 'InputEventScreenDrag' "$PROJECT/scripts"
grep -rq 'AudioStream' "$PROJECT/scripts"
grep -rq 'fire_rate' "$PROJECT/scripts"
test -f "$PROJECT/export_presets.cfg"
grep -q 'platform="Android"' "$PROJECT/export_presets.cfg"
! grep -rE 'Sprite2D|TextureRect|AnimatedSprite' "$PROJECT/scenes" "$PROJECT/scripts" 2>/dev/null
test -f "$PROJECT/scripts/headless_verify.gd"
grep -q 'ArenaWalls' "$PROJECT/main.tscn"
grep -q 'StaticBody2D' "$PROJECT/main.tscn"
grep -q 'SHIP_HULL_RADIUS' "$PROJECT/scripts/game_logic.gd"
grep -q 'move_and_slide' "$PROJECT/scripts/player.gd"
! grep -q 'clamp_to_arena' "$PROJECT/scripts/player.gd"

HULL_RADIUS=$(grep 'SHIP_HULL_RADIUS :=' "$PROJECT/scripts/game_logic.gd" | grep -oE '[0-9]+\.[0-9]+')
awk -v h="$HULL_RADIUS" 'BEGIN { if (h < 12.0) exit 1 }'

echo "[VP-4a] Final headless launch 1 (--quit-after 5)"
set +e
"$GODOT" --headless --path "$PROJECT" --quit-after 5 2>&1 | tee "$SCRATCH/godot_final_1.log"
FINAL1_RC=${PIPESTATUS[0]}
set -e
if [ "$FINAL1_RC" -ne 0 ]; then
  echo "FAIL: final launch 1 exit $FINAL1_RC"
  exit 1
fi
if grep -qiE "Can't run project|fatal|SCRIPT ERROR|Parse Error" "$SCRATCH/godot_final_1.log"; then
  echo "FAIL: final launch 1 errors"
  exit 1
fi

echo "[VP-4b] Final headless launch 2 (--quit-after 5)"
set +e
"$GODOT" --headless --path "$PROJECT" --quit-after 5 2>&1 | tee "$SCRATCH/godot_final_2.log"
FINAL2_RC=${PIPESTATUS[0]}
set -e
if [ "$FINAL2_RC" -ne 0 ]; then
  echo "FAIL: final launch 2 exit $FINAL2_RC"
  exit 1
fi
if grep -qiE "Can't run project|fatal|SCRIPT ERROR|Parse Error" "$SCRATCH/godot_final_2.log"; then
  echo "FAIL: final launch 2 errors"
  exit 1
fi

echo "[VP-5] Android export preset (source only)"
test -f "$PROJECT/export_presets.cfg"

(cd "$PROJECT" && git ls-files) > "$SCRATCH/changed_files_manifest.txt"

echo "VERIFY_EXIT_CODE=0" | tee "$SCRATCH/verify_output.log"
echo "VERIFY_WALL_VELOCITY=$WALL_VEL" | tee -a "$SCRATCH/verify_output.log"
echo "PASS: plan verification complete" | tee -a "$SCRATCH/verify_output.log"

cat > "$SCRATCH/vp_evidence.txt" <<EOF
VERIFY_EXIT_CODE=0
VERIFY_WALL_VELOCITY=$WALL_VEL

VP-1a: godot_launch_1.log — main.tscn with --verify
  - verify_exit=0, options_applied, touch_events_processed, sfx_played, music_looping=true
  - lives_after_hit=2, score_after_shot=100
VP-1b: godot_launch_2.log — repeat verify launch
VP-2: project.godot — GameOptions, TouchInput, AudioManager autoloads
VP-3: source — screen touch, audio, options, export_presets.cfg Android
VP-4: godot_final_1.log + godot_final_2.log — plain launches clean
VP-5: export_presets.cfg present (APK build requires Android templates)

Changed files: see changed_files_manifest.txt ($(wc -l < "$SCRATCH/changed_files_manifest.txt") git-tracked files)
EOF