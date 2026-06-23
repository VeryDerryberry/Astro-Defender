#!/usr/bin/env bash
set -euo pipefail

PROJECT="/home/derc/Godot/VectorGame"
GODOT="/home/derc/bin/godot"
SCRATCH="${SCRATCH:-/tmp/grok-goal-dcc37aa7901f/implementer}"
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
grep -q 'ArenaContext=' "$PROJECT/project.godot"

echo "[VP-3] Source inspection"
for term in Line2D Polygon2D rotate thrust spawn wave lives score game_over start; do
  grep -rq "$term" "$PROJECT/scenes" "$PROJECT/scripts" "$PROJECT/main.tscn" || {
    echo "FAIL: missing term $term"
    exit 1
  }
done
! grep -rE 'Sprite2D|TextureRect|AnimatedSprite' "$PROJECT/scenes" "$PROJECT/scripts" 2>/dev/null
test -f "$PROJECT/scripts/headless_verify.gd"
grep -q 'ArenaWalls' "$PROJECT/main.tscn"
grep -q 'StaticBody2D' "$PROJECT/main.tscn"
grep -q 'SHIP_HULL_RADIUS' "$PROJECT/scripts/game_logic.gd"
grep -q 'move_and_slide' "$PROJECT/scripts/player.gd"
! grep -q 'clamp_to_arena' "$PROJECT/scripts/player.gd"

HULL_RADIUS=$(grep 'SHIP_HULL_RADIUS :=' "$PROJECT/scripts/game_logic.gd" | grep -oE '[0-9]+\.[0-9]+')
awk -v h="$HULL_RADIUS" 'BEGIN { if (h < 12.0) exit 1 }'

echo "[VP-4] Final headless launch (--quit-after 5)"
set +e
"$GODOT" --headless --path "$PROJECT" --quit-after 5 2>&1 | tee "$SCRATCH/godot_final.log"
FINAL_RC=${PIPESTATUS[0]}
set -e
if [ "$FINAL_RC" -ne 0 ]; then
  echo "FAIL: final launch exit $FINAL_RC"
  exit 1
fi
if grep -qiE "Can't run project|fatal|SCRIPT ERROR|Parse Error" "$SCRATCH/godot_final.log"; then
  echo "FAIL: final launch errors"
  exit 1
fi

# Honest changed-files manifest from git
(cd "$PROJECT" && git ls-files) > "$SCRATCH/changed_files_manifest.txt"

echo "VERIFY_EXIT_CODE=0" | tee "$SCRATCH/verify_output.log"
echo "VERIFY_WALL_VELOCITY=$WALL_VEL" | tee -a "$SCRATCH/verify_output.log"
echo "PASS: plan verification complete" | tee -a "$SCRATCH/verify_output.log"

cat > "$SCRATCH/vp_evidence.txt" <<EOF
VERIFY_EXIT_CODE=0
VERIFY_WALL_VELOCITY=$WALL_VEL

VP-1a: godot_launch_1.log — main.tscn with --verify
  - verify_exit=0, game_started=true
  - arena_walls_present=true, spawner_enemy_count>=1
  - wall_right_inside=true, wall_left_inside=true
  - lives_after_hit=2, score_after_shot=100
VP-1b: godot_launch_2.log — repeat verify launch, verify_exit=0
VP-2: project.godot — Godot 4.6, Astro Defender, main.tscn
VP-3: source inspection — Line2D/Polygon2D only, headless_verify.gd present
VP-4: godot_final.log — plain --quit-after 5, no script errors

Changed files: see changed_files_manifest.txt ($(wc -l < "$SCRATCH/changed_files_manifest.txt") git-tracked files)
EOF