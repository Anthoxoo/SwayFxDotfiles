#!/usr/bin/env python3
import sys
import json
import subprocess

def run_out(cmd, timeout=4):
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""

def get_status(do_scan=False):
    if do_scan:
        try:
            subprocess.run(["bluetoothctl", "--timeout", "3", "scan", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
        except Exception:
            pass

    show_out = run_out(["bluetoothctl", "show"], timeout=2)
    powered = ("Powered: yes" in show_out)

    if not powered:
        print(json.dumps({
            "powered": False,
            "connectedCount": 0,
            "devices": []
        }), flush=True)
        return

    paired_out = run_out(["bluetoothctl", "devices", "Paired"], timeout=2)
    paired_macs = set()
    for line in paired_out.splitlines():
        parts = line.strip().split(" ", 2)
        if len(parts) >= 2:
            paired_macs.add(parts[1])

    all_out = run_out(["bluetoothctl", "devices"], timeout=2)
    devices = []
    conn_count = 0

    for line in all_out.splitlines():
        parts = line.strip().split(" ", 2)
        if len(parts) < 3:
            continue
        mac, name = parts[1], parts[2].strip()
        # Ignorer les adresses MAC anonymes sans vrai nom si non appairées
        if mac not in paired_macs and name.replace("-", ":") == mac:
            continue

        info = run_out(["bluetoothctl", "info", mac], timeout=2)
        is_conn = ("Connected: yes" in info)
        is_paired = (mac in paired_macs) or ("Paired: yes" in info)

        bat = -1
        for iline in info.splitlines():
            iline = iline.strip()
            if iline.startswith("Battery Percentage:"):
                try:
                    bat = int(iline.split("(")[-1].split(")")[0])
                except Exception:
                    pass

        if is_conn:
            conn_count += 1

        devices.append({
            "mac": mac,
            "name": name.lower(),
            "connected": is_conn,
            "paired": is_paired,
            "battery": bat
        })

    devices.sort(key=lambda d: (0 if d["connected"] else (1 if d["paired"] else 2), d["name"]))

    print(json.dumps({
        "powered": True,
        "connectedCount": conn_count,
        "devices": devices[:14]
    }), flush=True)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        get_status(False)
    elif cmd == "scan":
        get_status(True)
    elif cmd == "toggle-power":
        show_out = run_out(["bluetoothctl", "show"], timeout=2)
        target = "off" if "Powered: yes" in show_out else "on"
        subprocess.run(["bluetoothctl", "power", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif cmd == "toggle-device" and len(sys.argv) >= 3:
        mac = sys.argv[2]
        info = run_out(["bluetoothctl", "info", mac], timeout=2)
        if "Connected: yes" in info:
            subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=6)
        else:
            if "Paired: yes" not in info:
                subprocess.run(["bluetoothctl", "pair", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8)
            subprocess.run(["bluetoothctl", "trust", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
            subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8)
    elif cmd == "remove" and len(sys.argv) >= 3:
        subprocess.run(["bluetoothctl", "remove", sys.argv[2]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
