#!/usr/bin/env bash
# Unit test: patch_launcher_manifest.py adds LAUNCHER to alias intent-filter.
set -euo pipefail

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${SCRATCH:-/tmp/grok-goal-220491e2a408/implementer}"
FIXTURE="$SCRATCH/test_manifest_fixture.xml"
PATCHED="$SCRATCH/test_manifest_patched.xml"

mkdir -p "$SCRATCH"

cat > "$FIXTURE" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application>
        <activity android:name=".GodotApp" tools:node="mergeOnlyAttributes" android:exported="false" />
        <activity-alias
            tools:node="mergeOnlyAttributes"
            android:name=".GodotAppLauncher"
            android:targetActivity=".GodotApp"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </activity-alias>
    </application>
</manifest>
EOF

cp "$FIXTURE" "$PATCHED"
python3 "$PROJECT/scripts/patch_launcher_manifest.py" "$PATCHED"

grep -q 'GodotAppLauncher' "$PATCHED" || { echo "FAIL: alias missing"; exit 1; }
grep -A8 'GodotAppLauncher' "$PATCHED" | grep -q 'android.intent.category.LAUNCHER' \
  || { echo "FAIL: LAUNCHER not in alias intent-filter block"; exit 1; }
grep -A8 'GodotAppLauncher' "$PATCHED" | grep -q 'android.intent.action.MAIN' \
  || { echo "FAIL: MAIN not in alias intent-filter block"; exit 1; }
grep -A2 'GodotAppLauncher' "$PATCHED" | grep -q 'android:exported="true"' \
  || { echo "FAIL: alias not exported=true"; exit 1; }

echo "TEST_PATCH_LAUNCHER_MANIFEST=PASS" | tee "$SCRATCH/test_patch_launcher_manifest.log"
echo "PASS: test_patch_launcher_manifest.sh"