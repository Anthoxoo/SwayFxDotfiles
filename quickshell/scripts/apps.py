#!/usr/bin/env python3
import os
import glob
import json
import re
import configparser

HIST_FILE = os.path.expanduser("~/.cache/quickshell_apps_hist.json")

APP_DIRS = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/local/share/applications",
    "/usr/share/applications",
    "/var/lib/flatpak/exports/share/applications",
    os.path.expanduser("~/.local/share/flatpak/exports/share/applications"),
]

ICON_DIRS = [
    os.path.expanduser("~/.local/share/icons"),
    "/usr/share/icons/Papirus-Dark/48x48/apps",
    "/usr/share/icons/Papirus/48x48/apps",
    "/usr/share/icons/hicolor/48x48/apps",
    "/usr/share/icons/hicolor/scalable/apps",
    "/usr/share/icons/hicolor/128x128/apps",
    "/usr/share/icons/Adwaita/scalable/apps",
    "/usr/share/pixmaps",
]

def load_history():
    try:
        with open(HIST_FILE, "r") as f:
            return json.load(f)
    except Exception:
        return {}

def resolve_icon(icon_name):
    if not icon_name:
        return ""
    if os.path.isabs(icon_name) and os.path.exists(icon_name):
        return f"file://{icon_name}"
    for d in ICON_DIRS:
        if not os.path.isdir(d):
            continue
        for ext in (".svg", ".png", ".xpm"):
            p = os.path.join(d, icon_name + ext)
            if os.path.exists(p):
                return f"file://{p}"
    return ""

def clean_exec(cmd):
    return re.sub(r"\s+%[fFuUdDnNickvm]", "", cmd).strip()

def main():
    hist = load_history()
    apps = {}

    for d in APP_DIRS:
        if not os.path.isdir(d):
            continue
        for path in glob.glob(os.path.join(d, "*.desktop")):
            desktop_id = os.path.basename(path)
            if desktop_id in apps:
                continue
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(path, encoding="utf-8")
            except Exception:
                continue
            if "Desktop Entry" not in cp:
                continue
            sec = cp["Desktop Entry"]
            if sec.get("NoDisplay", "false").lower() == "true":
                continue
            if sec.get("Hidden", "false").lower() == "true":
                continue
            if sec.get("Type", "Application") != "Application":
                continue

            name = sec.get("Name", "").strip()
            exec_cmd = clean_exec(sec.get("Exec", ""))
            if not name or not exec_cmd:
                continue

            generic = sec.get("GenericName", "") or sec.get("Categories", "").split(";")[0]
            keywords = sec.get("Keywords", "").replace(";", " ")
            terminal = sec.get("Terminal", "false").lower() == "true"
            icon_url = resolve_icon(sec.get("Icon", "").strip())

            apps[desktop_id] = {
                "id": desktop_id,
                "name": name,
                "desc": generic.strip().lower(),
                "keywords": f"{name} {generic} {keywords} {exec_cmd}".lower(),
                "exec": exec_cmd,
                "terminal": terminal,
                "icon": icon_url,
                "score": hist.get(desktop_id, 0)
            }

    sorted_apps = sorted(apps.values(), key=lambda x: (-x["score"], x["name"].lower()))
    print(json.dumps(sorted_apps), flush=True)

if __name__ == "__main__":
    main()
