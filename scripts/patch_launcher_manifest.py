#!/usr/bin/env python3
"""Patch Godot release AndroidManifest for launcher: alias + GodotApp."""
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

ACTIVITY_BLOCK = (
    '        <activity android:name=".GodotApp" '
    'tools:replace="android:screenOrientation,android:excludeFromRecents,android:resizeableActivity,android:exported" '
    'tools:node="merge" android:exported="true" '
    'android:excludeFromRecents="false" android:screenOrientation="portrait" '
    'android:resizeableActivity="true">\n'
    "            <intent-filter>\n"
    '                <action android:name="android.intent.action.MAIN" />\n'
    '                <category android:name="android.intent.category.LAUNCHER" />\n'
    '                <category android:name="android.intent.category.DEFAULT" />\n'
    "            </intent-filter>\n"
    "        </activity>"
)


def patch_alias_block(text: str) -> str:
    text = text.replace(
        '<category android:name="android.intent.category.HOME" />',
        "",
    )
    patched, count = re.subn(
        r"        <activity-alias\b[\s\S]*?</activity-alias>",
        ALIAS_BLOCK,
        text,
        count=1,
    )
    if count != 1:
        raise ValueError("could not patch GodotAppLauncher alias block")
    return patched


def patch_godot_app_block(text: str) -> str:
    patched, count = re.subn(
        r'        <activity android:name="\.GodotApp"[^>]*>\s*</activity>',
        ACTIVITY_BLOCK,
        text,
        count=1,
    )
    if count != 1:
        raise ValueError("could not patch GodotApp activity block")
    return patched


def validate_patched_manifest(text: str) -> None:
    alias_match = re.search(
        r"<activity-alias[^>]*GodotAppLauncher[\s\S]*?</activity-alias>",
        text,
    )
    if alias_match is None or "android.intent.category.LAUNCHER" not in alias_match.group(0):
        raise ValueError("LAUNCHER missing inside GodotAppLauncher alias")

    activity_match = re.search(
        r'<activity android:name="\.GodotApp"[\s\S]*?</activity>',
        text,
    )
    if activity_match is None:
        raise ValueError("GodotApp activity missing after patch")
    block = activity_match.group(0)
    if 'android:exported="true"' not in block:
        raise ValueError("GodotApp not exported=true after patch")
    if "android.intent.category.LAUNCHER" not in block:
        raise ValueError("LAUNCHER missing inside GodotApp activity")


def patch_manifest_text(text: str) -> tuple[str, bool]:
    original = text
    text = patch_alias_block(text)
    text = patch_godot_app_block(text)
    validate_patched_manifest(text)
    return text, text != original


def patch_manifest(path: Path) -> bool:
    text, changed = patch_manifest_text(path.read_text(encoding="utf-8"))
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