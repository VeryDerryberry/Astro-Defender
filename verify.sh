#!/usr/bin/env bash
set -euo pipefail

PROJECT="/home/derc/Godot/VectorGame"
GODOT="/home/derc/bin/godot"
SCRATCH="${SCRATCH:-/tmp/grok-goal-dcc37aa7901f/implementer}"
mkdir -p "$SCRATCH"

echo "=== Astro Defender verification (plan VP) ==="

echo "[VP-1a] Headless launch 1 (--quit-after 5)"
set +e
"$GODOT" --headless --path "$PROJECT" --quit-after 5 2>&1 | tee "$SCRATCH/godot_launch_1.log"
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

echo "[VP-1b] Headless launch 2 (--quit-after 5)"
set +e
"$GODOT" --headless --path "$PROJECT" --quit-after 5 2>&1 | tee "$SCRATCH/godot_launch_2.log"
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

echo "[VP-1c] Runtime probe (main scene: thrust/walls/spawn/collision)"
set +e
"$GODOT" --headless --path "$PROJECT" res://runtime_probe.tscn 2>&1 | tee "$SCRATCH/runtime_probe.log"
PROBE_RC=${PIPESTATUS[0]}
set -e
cat "$SCRATCH/runtime_probe.log" >> "$SCRATCH/godot_launch_1.log"
if [ "$PROBE_RC" -ne 0 ]; then
  echo "FAIL: runtime probe exit $PROBE_RC"
  exit 1
fi
grep -q 'RUNTIME probe_exit=0' "$SCRATCH/runtime_probe.log" || { echo "FAIL: probe did not pass"; exit 1; }
grep -q 'RUNTIME arena_walls_present=true' "$SCRATCH/runtime_probe.log" || { echo "FAIL: walls not present"; exit 1; }
grep -q 'RUNTIME wall_right_inside=true' "$SCRATCH/runtime_probe.log" || { echo "FAIL: right wall confinement"; exit 1; }
grep -q 'RUNTIME wall_left_inside=true' "$SCRATCH/runtime_probe.log" || { echo "FAIL: left wall confinement"; exit 1; }
grep -q 'RUNTIME lives_after_hit=2' "$SCRATCH/runtime_probe.log" || { echo "FAIL: collision lives"; exit 1; }
grep -q 'RUNTIME score_after_shot=100' "$SCRATCH/runtime_probe.log" || { echo "FAIL: projectile score"; exit 1; }

WALL_VEL=$(grep '^RUNTIME wall_right_velocity=' "$SCRATCH/runtime_probe.log" | tail -1 | cut -d= -f2)
awk -v v="$WALL_VEL" 'BEGIN { if (v > 5.0) exit 1 }'

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
test -f "$PROJECT/scripts/runtime_probe.gd"
test -f "$PROJECT/runtime_probe.tscn"
grep -q 'ArenaWalls' "$PROJECT/main.tscn"
grep -q 'StaticBody2D' "$PROJECT/main.tscn"
grep -q 'SHIP_HULL_RADIUS' "$PROJECT/scripts/game_logic.gd"
grep -q 'zero_velocity_into_wall' "$PROJECT/scripts/player.gd"
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

echo "VERIFY_EXIT_CODE=0"
echo "VERIFY_WALL_VELOCITY=$WALL_VEL"
echo "PASS: plan verification complete"