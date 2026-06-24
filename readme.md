# Astro Defender

Retro vector arcade shooter built with Godot 4.6. Survive waves of enemies in a portrait mobile arena.

## Gameplay

You control a fast, agile spaceship in a 2D arena. Enemies spawn from the edges and fly toward you. Destroy them while avoiding collisions.

### Controls

**Desktop**
- WASD / Arrow keys: thrust
- Mouse: aim
- Left click: shoot

**Touch (Android)**
- Left side: virtual joystick for thrust
- Right side: aim and shoot

### Game Flow

1. Start screen with options (fire rate, lives, enemy count, speeds)
2. Main gameplay with increasing wave difficulty
3. Lives system (default 3 lives)
4. Game over screen with local high score

## Portrait Viewport & Camera

- Viewport: **720×1280** portrait (`project.godot`)
- Arena border, walls, and spawn positions are computed from the live viewport size (no landscape hardcodes)
- Camera centers on the playable arena
- **Dynamic zoom**: starts at **2.2×** when idle, smoothly zooms out to **1.5×** while the ship is moving

## Style

Clean retro vector graphics using only `Line2D` and `Polygon2D` nodes — no sprite images.

## Android Export

```bash
cd Godot/Astro-Defender
./scripts/plan_step4_export_apk.sh   # full clean export → build/AstroDefender.apk
```

Or run the full goal pipeline:

```bash
SCRATCH=/tmp/grok-goal-9bc1a73858f2/implementer ./run_android_goal.sh
```

## Git & APK

The release APK at `build/AstroDefender.apk` is tracked in git (other `build/` artifacts are ignored). To push source and APK to GitHub:

```bash
git add -f build/AstroDefender.apk
git add project.godot main.tscn scripts/ .gitignore readme.md
git commit -m "Portrait viewport, dynamic zoom, APK export"
git push origin master
```

Repository: https://github.com/VeryDerryberry/Astro-Defender