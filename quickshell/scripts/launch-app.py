#!/usr/bin/env python3
import sys
import os
import json
import subprocess

HIST_FILE = os.path.expanduser("~/.cache/quickshell_apps_hist.json")

def bump_score(app_id):
    if not app_id:
        return
    data = {}
    try:
        if os.path.exists(HIST_FILE):
            with open(HIST_FILE, "r") as f:
                data = json.load(f)
    except Exception:
        data = {}
    data[app_id] = data.get(app_id, 0) + 1
    try:
        with open(HIST_FILE, "w") as f:
            json.dump(data, f)
    except Exception:
        pass

def main():
    if len(sys.argv) < 4:
        return
    app_id = sys.argv[1]
    exec_cmd = sys.argv[2]
    is_term = sys.argv[3].lower() == "true"
    bump_score(app_id)
    cmd = f"alacritty -e {exec_cmd}" if is_term else exec_cmd
    subprocess.run(["swaymsg", "exec", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == "__main__":
    main()
