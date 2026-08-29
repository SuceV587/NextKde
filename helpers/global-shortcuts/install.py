#!/usr/bin/env python3
"""Register the Quickshell global shortcuts as KDE Command Shortcuts.

Each shortcut in shortcuts.json becomes:
  - a .desktop launcher in ~/.local/share/applications whose Exec runs
    `qs -p <config> ipc call <target> <action>` (the same Command Shortcut
    mechanism the existing net.local.qs shortcuts use), and
  - a `[services][<id>.desktop] _launch=<combo>` entry in kglobalshortcutsrc
    that binds the default combo.

Conflicts are detected against every existing _launch binding in
kglobalshortcutsrc; a duplicate combo is reported and skipped so two actions
never fight over one key. Run install.py again after editing shortcuts.json to
re-apply. Combo changes are best done in System Settings → Shortcuts, which
keeps the per-user bindings (this script only seeds defaults).

Usage: python3 install.py [config-dir]     (default: this repository root)
"""
import json
import os
import re
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_DIR = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(SCRIPT_DIR, "..", ".."))
APPS_DIR = os.path.join(os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")), "applications")
SHORTCUTS_RC = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "kglobalshortcutsrc")


def load_table():
    with open(os.path.join(SCRIPT_DIR, "shortcuts.json"), encoding="utf-8") as f:
        return json.load(f)


def existing_launch_bindings():
    """Return {combo: [section ids]} parsed from kglobalshortcutsrc."""
    bindings = {}
    section = None
    try:
        with open(SHORTCUTS_RC, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                m = re.match(r"\[services\]\[(.+)\]", line)
                if m:
                    section = m.group(1)
                    continue
                m = re.match(r"_launch=(\S+)", line)
                if m and section:
                    bindings.setdefault(m.group(1), []).append(section)
    except FileNotFoundError:
        pass
    return bindings


KEY_MAP = {
    "space": 0x20,
    "tab": 0x01000001,
    "return": 0x01000004,
    "enter": 0x01000004,
    "esc": 0x01000000,
    "escape": 0x01000000,
}

MOD_MAP = {
    "meta": 0x10000000,
    "super": 0x10000000,
    "ctrl": 0x04000000,
    "control": 0x04000000,
    "alt": 0x08000000,
    "shift": 0x02000000,
}


def parse_combo(combo: str) -> int:
    mods = 0
    key = 0
    for part in combo.split("+"):
        pl = part.lower()
        if pl in MOD_MAP:
            mods |= MOD_MAP[pl]
        elif pl in KEY_MAP:
            key = KEY_MAP[pl]
        elif len(part) == 1:
            key = ord(part.upper())
    return mods | key


def register_via_dbus(shortcuts):
    try:
        import dbus
        bus = dbus.SessionBus()
        kg = bus.get_object("org.kde.kglobalaccel", "/kglobalaccel")
        iface = dbus.Interface(kg, "org.kde.KGlobalAccel")
        for entry in shortcuts:
            desktop_name = entry["id"] + ".desktop"
            action_id = [desktop_name, "_launch", entry["description"], entry["description"]]
            iface.doRegister(action_id)
            key_code = parse_combo(entry["default"])
            keys = dbus.Array([dbus.Int32(key_code)], signature="i")
            iface.setForeignShortcut(action_id, keys)
            print(f"[global-shortcuts] DBus 实时注册: {desktop_name} -> {entry['default']}")
    except Exception as e:
        print(f"[global-shortcuts] DBus 注册跳过/警告: {e}")


def main():
    table = load_table()
    os.makedirs(APPS_DIR, exist_ok=True)
    bindings = existing_launch_bindings()
    registered_shortcuts = []
    for entry in table["shortcuts"]:
        shortcut_id = entry["id"]
        command = table["command"].format(config=CONFIG_DIR,
                                          target=entry["target"],
                                          action=entry["action"])
        desktop_path = os.path.join(APPS_DIR, shortcut_id + ".desktop")

        # Conflict detection: a combo already claimed by any section is refused
        # unless it is this exact shortcut re-binding its own default.
        conflict = [sec for sec in bindings.get(entry["default"], [])
                    if sec != shortcut_id + ".desktop"]
        if conflict:
            print(f"[global-shortcuts] 冲突: {entry['default']} 已被 "
                  f"{', '.join(conflict)} 占用，跳过 {shortcut_id}")
            continue

        with open(desktop_path, "w", encoding="utf-8") as f:
            f.write(
                "[Desktop Entry]\n"
                f"Exec={command}\n"
                f"Name={entry['description']}\n"
                "NoDisplay=true\n"
                "StartupNotify=false\n"
                "Type=Application\n"
                "X-KDE-GlobalAccel-CommandShortcut=true\n"
            )
        print(f"[global-shortcuts] 写入 {desktop_path}")

        # Seed the default binding. The section must exist even when the user
        # later rebinds the combo in System Settings, or the shortcut is shown
        # as unbound until then.
        section = f"[services][{shortcut_id}.desktop]"
        try:
            with open(SHORTCUTS_RC, encoding="utf-8") as f:
                rc_lines = f.readlines()
        except FileNotFoundError:
            rc_lines = []
        header_at = None
        in_section = False
        updated = False
        for index, line in enumerate(rc_lines):
            stripped = line.strip()
            if stripped.startswith("[services][") and stripped.endswith("]"):
                in_section = stripped == section
                if in_section:
                    header_at = index
            elif in_section and stripped.startswith("_launch="):
                rc_lines[index] = f"_launch={entry['default']}\n"
                updated = True
                break
        if not updated:
            if header_at is not None:
                # Section exists but has no _launch yet.
                rc_lines.insert(header_at + 1, f"_launch={entry['default']}\n")
            else:
                # Append a fresh section at the end of the file. Section
                # ordering is irrelevant to kglobalaccel.
                rc_lines.append(f"{section}\n_launch={entry['default']}\n")
        with open(SHORTCUTS_RC, "w", encoding="utf-8") as f:
            f.writelines(rc_lines)
        print(f"[global-shortcuts] 绑定 {entry['default']} -> {shortcut_id}")
        registered_shortcuts.append(entry)

    # Register via DBus directly into kglobalaccel daemon
    register_via_dbus(registered_shortcuts)

    # kglobalacceld watches the applications directory; notify it by restarting
    # the user service so the new Command Shortcuts become active immediately.
    subprocess.run(["systemctl", "--user", "restart", "plasma-kglobalaccel.service"],
                   check=False)
    print("[global-shortcuts] 完成；kglobalaccel 已重载")


if __name__ == "__main__":
    main()
