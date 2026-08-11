#!/usr/bin/env python3
"""Remove the Quickshell Command Shortcuts registered by install.py.

Deletes the .desktop launchers and their [services][...] sections from
kglobalshortcutsrc, then reloads kglobalaccel so the key grabs are released.

Usage: python3 uninstall.py
"""
import json
import os
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
APPS_DIR = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "applications")
SHORTCUTS_RC = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "kglobalshortcutsrc")


def main():
    with open(os.path.join(SCRIPT_DIR, "shortcuts.json"), encoding="utf-8") as f:
        table = json.load(f)
    removed_sections = set()
    for entry in table["shortcuts"]:
        desktop_path = os.path.join(APPS_DIR, entry["id"] + ".desktop")
        if os.path.exists(desktop_path):
            os.remove(desktop_path)
            print(f"[global-shortcuts] 删除 {desktop_path}")
        removed_sections.add(f"[services][{entry['id']}.desktop]")

    try:
        with open(SHORTCUTS_RC, encoding="utf-8") as f:
            lines = f.readlines()
    except FileNotFoundError:
        lines = []
    kept, skip_section = [], False
    for line in lines:
        stripped = line.strip()
        if stripped in removed_sections:
            skip_section = True
            continue
        if skip_section:
            if stripped.startswith("[") and stripped.endswith("]"):
                skip_section = False
            else:
                continue
        kept.append(line)
    with open(SHORTCUTS_RC, "w", encoding="utf-8") as f:
        f.writelines(kept)
    print("[global-shortcuts] kglobalshortcutsrc 已清理")

    subprocess.run(["systemctl", "--user", "restart", "plasma-kglobalaccel.service"],
                   check=False)
    print("[global-shortcuts] 完成；kglobalaccel 已重载")


if __name__ == "__main__":
    main()
