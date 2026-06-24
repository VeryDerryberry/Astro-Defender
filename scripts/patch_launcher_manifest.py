#!/usr/bin/env python3
"""Patch Godot release AndroidManifest: LAUNCHER on GodotAppLauncher alias."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ALIAS_BLOCK = """        <activity-alias
            tools:node="merge"
            android:name=".GodotAppLauncher"
            android:targetActivity=".GodotApp"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>"""


def patch_manifest(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text

    text = text.replace(
        '<category android:name="android.intent.category.HOME" />',
        "",
    )

    text, count = re.subn(
        r"        <activity-alias\b[\s\S]*?</activity-alias>",
        ALIAS_BLOCK,
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit(f"FAIL: could not patch GodotAppLauncher alias in {path}")

    if "GodotAppLauncher" not in text:
        raise SystemExit(f"FAIL: GodotAppLauncher missing after patch in {path}")
    if "android.intent.category.LAUNCHER" not in text:
        raise SystemExit(f"FAIL: LAUNCHER missing after patch in {path}")

    alias_match = re.search(
        r"<activity-alias[^>]*GodotAppLauncher[\s\S]*?</activity-alias>",
        text,
    )
    if alias_match is None or "android.intent.category.LAUNCHER" not in alias_match.group(0):
        raise SystemExit(f"FAIL: LAUNCHER not inside GodotAppLauncher alias in {path}")

    changed = text != original
    if changed:
        path.write_text(text, encoding="utf-8")
    return changed


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <release/AndroidManifest.xml>")
    changed = patch_manifest(Path(sys.argv[1]))
    print("PATCH_CHANGED=" + ("yes" if changed else "no"))


if __name__ == "__main__":
    main()