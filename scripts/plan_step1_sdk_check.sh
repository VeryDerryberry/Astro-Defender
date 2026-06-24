#!/usr/bin/env bash
set -euo pipefail

SCRATCH="${SCRATCH:-/tmp/grok-goal-98594fc3f297/implementer}"
ANDROID_HOME="${ANDROID_HOME:-/home/derc/Android/Sdk}"
JAVA_HOME="${JAVA_HOME:-/home/derc/.local/jdk-17.0.14+7}"
EDITOR_SETTINGS="/home/derc/.config/godot/editor_settings-4.6.tres"
LOG="$SCRATCH/sdk_check.log"

export ANDROID_HOME JAVA_HOME
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
mkdir -p "$SCRATCH"

{
  echo "=== Plan verification step 1: SDK check $(date -Iseconds) ==="
  echo "ANDROID_HOME=$ANDROID_HOME"
  echo "JAVA_HOME=$JAVA_HOME"
  echo ""
  echo "--- editor_settings export/android/*_sdk_path ---"
  grep -E 'export/android/(java_sdk|android_sdk)_path' "$EDITOR_SETTINGS"
  echo ""
  echo "--- ls /home/derc/Android/Sdk ---"
  ls -la "$ANDROID_HOME/"
  echo ""
  echo "--- platform-tools/adb ---"
  ls -la "$ANDROID_HOME/platform-tools/adb"
  echo ""
  echo "--- sdkmanager --sdk_root=$ANDROID_HOME --list_installed ---"
  sdkmanager --sdk_root="$ANDROID_HOME" --list_installed 2>&1
  echo ""
  echo "--- required component assertions ---"
  test -d "$ANDROID_HOME/platform-tools" && echo "OK: platform-tools"
  test -x "$ANDROID_HOME/platform-tools/adb" && echo "OK: platform-tools/adb"
  test -d "$ANDROID_HOME/build-tools/35.0.1" && echo "OK: build-tools;35.0.1"
  test -d "$ANDROID_HOME/build-tools/36.0.0" && echo "OK: build-tools;36.0.0"
  test -d "$ANDROID_HOME/platforms/android-35" && echo "OK: platforms;android-35"
  test -d "$ANDROID_HOME/platforms/android-36" && echo "OK: platforms;android-36"
  test -d "$ANDROID_HOME/cmake/3.10.2.4988404" && echo "OK: cmake;3.10.2.4988404"
  test -d "$ANDROID_HOME/ndk/28.1.13356709" && echo "OK: ndk;28.1.13356709"
  if [ -d "$ANDROID_HOME/cmdline-tools/latest" ] || [ -d "$ANDROID_HOME/cmdline-tools/latest-2" ]; then
    echo "OK: cmdline-tools;latest"
  else
    echo "MISSING: cmdline-tools;latest"
    exit 1
  fi
  test -x "$JAVA_HOME/bin/java" && echo "OK: java bin/java"
  "$JAVA_HOME/bin/java" -version 2>&1
  echo "SDK_CHECK_RESULT=PASS"
} | tee "$LOG"