#!/usr/bin/env python3
import re
import sys
import json
import subprocess

# Pendant un scan Bluetooth (le sien ou celui de librepods), bluetoothctl intercale dans sa
# sortie des événements du type « [CHG] Device AA:BB:… RSSI: … » : on ne garde que les vraies
# lignes « Device <MAC> <nom> », et, pour `info` / `show`, les lignes indentées.
DEVICE_LINE = re.compile(r"^Device ((?:[0-9A-F]{2}:){5}[0-9A-F]{2}) (.+)$", re.IGNORECASE)

def run_out(cmd, timeout=4):
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""

def list_devices(*filters):
    """[(mac, nom)] d'après `bluetoothctl devices [Paired|Connected]`."""
    out = run_out(["bluetoothctl", "devices", *filters], timeout=3)
    found = []
    for line in out.splitlines():
        m = DEVICE_LINE.match(line.strip())
        if m:
            found.append((m.group(1).upper(), m.group(2).strip()))
    return found

def own_lines(cmd, timeout=2):
    """Lignes indentées (propres à l'appareil ou au contrôleur), sans les événements intercalés."""
    return [l.strip() for l in run_out(cmd, timeout=timeout).splitlines() if l[:1] in ("\t", " ")]

def device_info(mac):
    return own_lines(["bluetoothctl", "info", mac])

def controller_powered():
    return "Powered: yes" in own_lines(["bluetoothctl", "show"])

def get_status(do_scan=False):
    if do_scan:
        try:
            subprocess.run(["bluetoothctl", "--timeout", "3", "scan", "on"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
        except Exception:
            pass

    if not controller_powered():
        print(json.dumps({
            "powered": False,
            "connectedCount": 0,
            "devices": []
        }), flush=True)
        return

    paired_macs = {mac for mac, _ in list_devices("Paired")}
    connected_macs = {mac for mac, _ in list_devices("Connected")}
    devices = []

    for mac, name in list_devices():
        is_paired = mac in paired_macs
        # Ignorer les adresses MAC anonymes sans vrai nom si non appairées
        if not is_paired and name.replace("-", ":").upper() == mac:
            continue
        is_conn = mac in connected_macs

        # `bluetoothctl info` seulement pour la batterie des appareils connectés
        bat = -1
        if is_conn:
            for iline in device_info(mac):
                if iline.startswith("Battery Percentage:"):
                    try:
                        bat = int(iline.split("(")[-1].split(")")[0])
                    except Exception:
                        pass

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
        "connectedCount": len([d for d in devices if d["connected"]]),
        "devices": devices[:14]
    }), flush=True)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        get_status(False)
    elif cmd == "scan":
        get_status(True)
    elif cmd == "toggle-power":
        target = "off" if controller_powered() else "on"
        subprocess.run(["bluetoothctl", "power", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif cmd == "toggle-device" and len(sys.argv) >= 3:
        mac = sys.argv[2]
        info = device_info(mac)
        if "Connected: yes" in info:
            subprocess.run(["bluetoothctl", "disconnect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=6)
        else:
            if "Paired: yes" not in info:
                subprocess.run(["bluetoothctl", "pair", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8)
            subprocess.run(["bluetoothctl", "trust", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
            subprocess.run(["bluetoothctl", "connect", mac], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=8)
    elif cmd == "remove" and len(sys.argv) >= 3:
        subprocess.run(["bluetoothctl", "remove", sys.argv[2]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
