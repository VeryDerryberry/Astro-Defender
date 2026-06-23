#!/usr/bin/env bash
set -euo pipefail

PROJECT="/home/derc/Godot/VectorGame"
GODOT="/home/derc/bin/godot"
SCRATCH="${SCRATCH:-/tmp/grok-goal-dcc37aa7901f/implementer}"
mkdir -p "$SCRATCH"

echo "=== Astro Defender verification (plan VP) ==="

echo "[VP-1a] Headless launch 1"
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

echo "[VP-1b] Headless launch 2"
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

echo "[VP-2] project.godot"
grep -q 'config_version=5' "$PROJECT/project.godot"
grep -q 'config/name="Astro Defender"' "$PROJECT/project.godot"
grep -q '"4.6"' "$PROJECT/project.godot"
grep -q 'run/main_scene="res://main.tscn"' "$PROJECT/project.godot"
grep -q 'ArenaContext=' "$PROJECT/project.godot"

echo "[VP-3] Source grep: vector graphics, gameplay, UI, arena walls"
for term in Line2D Polygon2D rotate thrust spawn wave lives score game_over start; do
  grep -rq "$term" "$PROJECT/scenes" "$PROJECT/scripts" "$PROJECT/main.tscn" || {
    echo "FAIL: missing term $term"
    exit 1
  }
done
! grep -rE 'Sprite2D|TextureRect|AnimatedSprite' "$PROJECT/scenes" "$PROJECT/scripts" 2>/dev/null
grep -q 'ArenaWalls' "$PROJECT/main.tscn"
grep -q 'StaticBody2D' "$PROJECT/main.tscn"
grep -q 'CollisionShape2D' "$PROJECT/main.tscn"
grep -q 'SHIP_HULL_RADIUS' "$PROJECT/scripts/game_logic.gd"
grep -q 'zero_velocity_into_wall' "$PROJECT/scripts/game_logic.gd"
grep -q 'playable_rect' "$PROJECT/scripts/game_logic.gd"
grep -q 'arena_border_points' "$PROJECT/scripts/game_logic.gd"
grep -q 'zero_velocity_into_wall' "$PROJECT/scripts/player.gd"
grep -q 'collision_mask = 4' "$PROJECT/scenes/player.tscn"
grep -q 'area_entered' "$PROJECT/scripts/player.gd"
grep -q 'area_entered' "$PROJECT/scripts/projectile.gd"
grep -q 'ArenaContext.get_entities' "$PROJECT/scripts/player.gd"
grep -q 'wave_spawn_positions' "$PROJECT/scripts/spawner.gd"
grep -q 'Press Any Key to Start' "$PROJECT/main.tscn"
grep -q 'GAME OVER' "$PROJECT/main.tscn"
grep -q 'ArenaBorder' "$PROJECT/main.tscn"
! grep -q 'clamp_to_arena' "$PROJECT/scripts/player.gd"

HULL_RADIUS=$(grep 'SHIP_HULL_RADIUS :=' "$PROJECT/scripts/game_logic.gd" | grep -oE '[0-9]+\.[0-9]+')
awk -v h="$HULL_RADIUS" 'BEGIN { if (h < 12.0) exit 1 }'

echo "[VP-4] Final headless launch"
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

echo "PASS: plan verification complete"