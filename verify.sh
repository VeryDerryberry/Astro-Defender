#!/usr/bin/env bash
set -euo pipefail

PROJECT="/home/derc/Godot/VectorGame"
GODOT="/home/derc/bin/godot"
SCRATCH="${SCRATCH:-/tmp/grok-goal-98594fc3f297/implementer}"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"
JAVA_HOME="${JAVA_HOME:-/home/derc/.local/jdk-17.0.14+7}"
export ANDROID_HOME JAVA_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
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
grep -q 'RUNTIME options_custom=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: custom options not set"; exit 1; }
grep -q 'RUNTIME options_applied=' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: options not applied"; exit 1; }
grep -q 'RUNTIME options_applied=.*enemies=6' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: custom enemy count not applied"; exit 1; }
grep -q 'RUNTIME fire_rate_applied=0.100000' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: custom fire rate not applied"; exit 1; }
grep -q 'RUNTIME touch_events_processed=' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: touch not processed"; exit 1; }
grep -q 'RUNTIME touch_thrust_peak=' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: touch thrust not measured"; exit 1; }
grep -q 'RUNTIME touch_thrust_cleared=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: touch thrust not cleared on release"; exit 1; }
grep -q 'RUNTIME touch_shoot_score=100' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: touch shoot score"; exit 1; }
grep -q 'RUNTIME sfx_played=' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: sfx not played"; exit 1; }
grep -q 'RUNTIME music_looping=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: music not looping"; exit 1; }
grep -q 'RUNTIME spawner_enemy_count=6' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: spawner enemy count mismatch"; exit 1; }
grep -q 'RUNTIME wall_right_inside=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: right wall confinement"; exit 1; }
grep -q 'RUNTIME wall_left_inside=true' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: left wall confinement"; exit 1; }
grep -q 'RUNTIME lives_after_hit=4' "$SCRATCH/godot_launch_1.log" || { echo "FAIL: collision lives"; exit 1; }
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
grep -rq 'has_active_aim' "$PROJECT/scripts"
grep -q 'func reset_state' "$PROJECT/scripts/touch_input.gd"
grep -q 'thrust_dir = Vector2.ZERO' "$PROJECT/scripts/touch_input.gd"
grep -q 'LEFT_ZONE_FRACTION' "$PROJECT/scripts/touch_input.gd"
grep -q '_finger_zones.erase' "$PROJECT/scripts/touch_input.gd"
grep -q 'func _recompute_state' "$PROJECT/scripts/touch_input.gd"
test -f "$PROJECT/export_presets.cfg"
grep -q 'platform="Android"' "$PROJECT/export_presets.cfg"
! grep -rE 'Sprite2D|TextureRect|AnimatedSprite' "$PROJECT/scenes" "$PROJECT/scripts" 2>/dev/null
test -f "$PROJECT/scripts/headless_verify.gd"
test -f "$PROJECT/scripts/game_options.gd"
test -f "$PROJECT/scripts/touch_input.gd"
test -f "$PROJECT/scripts/audio_manager.gd"
test -f "$PROJECT/scripts/procedural_audio.gd"
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

echo "[VP-5] Android export preset fields"
test -f "$PROJECT/export_presets.cfg"
grep -q 'name="Android"' "$PROJECT/export_presets.cfg"
grep -q 'platform="Android"' "$PROJECT/export_presets.cfg"
grep -q 'export_path="build/AstroDefender.apk"' "$PROJECT/export_presets.cfg"
grep -q 'architectures/armeabi-v7a=true' "$PROJECT/export_presets.cfg"
grep -q 'architectures/arm64-v8a=true' "$PROJECT/export_presets.cfg"
grep -q 'package/unique_name="com.astrodefender.game"' "$PROJECT/export_presets.cfg"
grep -q 'name="Web"' "$PROJECT/export_presets.cfg"
grep -q 'platform="Web"' "$PROJECT/export_presets.cfg"

"$ANDROID_HOME/platform-tools/adb" start-server >/dev/null 2>&1 || true

_export_apk() {
  local label="$1"
  local logfile="$2"
  echo "[VP-5] Android export $label"
  set +e
  "$GODOT" --headless --path "$PROJECT" --export-release "Android" build/AstroDefender.apk 2>&1 | tee "$logfile"
  local rc=${PIPESTATUS[0]}
  set -e
  echo "EXPORT_${label}_EXIT_CODE=$rc"
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: export $label exit code $rc"
    exit 1
  fi
  if grep -qiE 'ERROR: (Cannot export|Project export for preset)' "$logfile"; then
    echo "FAIL: export $label reported configuration/export error"
    exit 1
  fi
  sed 's/\x1b\[[0-9;]*m//g' "$logfile" | grep -q '\[ DONE \] export' || { echo "FAIL: export $label did not finish"; exit 1; }
}

_export_apk "1" "$SCRATCH/godot_export_1.log"
_export_apk "2" "$SCRATCH/godot_export_2.log"

APK="$PROJECT/build/AstroDefender.apk"
test -f "$APK" || { echo "FAIL: APK missing"; exit 1; }
APK_BYTES=$(stat -c%s "$APK")
echo "EXPORT_APK_BYTES=$APK_BYTES" | tee -a "$SCRATCH/verify_output.log"
awk -v s="$APK_BYTES" 'BEGIN { if (s < 5000000) exit 1 }' || { echo "FAIL: APK too small ($APK_BYTES bytes)"; exit 1; }
unzip -l "$APK" > "$SCRATCH/apk_listing.txt"
grep -q 'AndroidManifest.xml' "$SCRATCH/apk_listing.txt" || { echo "FAIL: no AndroidManifest"; exit 1; }
grep -q 'libgodot' "$SCRATCH/apk_listing.txt" || { echo "FAIL: no libgodot"; exit 1; }
grep -q 'assets/' "$SCRATCH/apk_listing.txt" || { echo "FAIL: no assets"; exit 1; }

(cd "$PROJECT" && git ls-files) > "$SCRATCH/changed_files_manifest.txt"

: > "$SCRATCH/verify_output.log"
echo "VERIFY_EXIT_CODE=0" >> "$SCRATCH/verify_output.log"
echo "VERIFY_WALL_VELOCITY=$WALL_VEL" >> "$SCRATCH/verify_output.log"
echo "PASS: plan verification complete" >> "$SCRATCH/verify_output.log"
cat "$SCRATCH/verify_output.log"

cat > "$SCRATCH/vp_evidence.txt" <<EOF
VERIFY_EXIT_CODE=0
VERIFY_WALL_VELOCITY=$WALL_VEL
EXPORT_APK_BYTES=$APK_BYTES
EXPORT_1_EXIT_CODE=0
EXPORT_2_EXIT_CODE=0

VP-1a: godot_launch_1.log — custom options (enemies=6,lives=5,fire_rate=0.10)
  - touch_thrust_cleared=true, touch_shoot_score=100, verify_exit=0
VP-1b: godot_launch_2.log — repeat verify launch
VP-2/3: autoloads, touch release/recompute logic present
VP-4: plain launches clean
VP-5: godot_export_1.log + godot_export_2.log — CLI export succeeded, APK validated

Changed files: see changed_files_manifest.txt ($(wc -l < "$SCRATCH/changed_files_manifest.txt") git-tracked files)
EOF