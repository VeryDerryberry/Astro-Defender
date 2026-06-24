#!/usr/bin/env python3
"""Patch Godot release AndroidManifest for app-drawer launcher visibility."""
from __future__ import annotations

import sys
from pathlib import Path


def patch_manifest(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    original = text

    text = text.replace(
        '<category android:name="android.intent.category.HOME" />',
        "",
    )
    text = text.replace('tools:node="mergeOnlyAttributes"', 'tools:node="merge"')

    activity_block = (
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

    import re

    text, count = re.subn(
        r'        <activity android:name="\.GodotApp"[^>]*>\s*</activity>',
        activity_block,
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit(f"FAIL: could not patch GodotApp activity block in {path}")

    if "android.intent.category.LAUNCHER" not in text:
        raise SystemExit(f"FAIL: LAUNCHER missing after patch in {path}")

    if text != original:
        path.write_text(text, encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <release/AndroidManifest.xml>")
    patch_manifest(Path(sys.argv[1]))


if __name__ == "__main__":
    main()