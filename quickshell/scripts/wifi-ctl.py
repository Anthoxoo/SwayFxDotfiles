#!/usr/bin/env python3
import sys
import json
import subprocess

def run_out(cmd, timeout=6):
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ""

def get_saved_ssids():
    out = run_out(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"], timeout=3)
    saved = set()
    for line in out.splitlines():
        if ":802-11-wireless" in line:
            saved.add(line.rsplit(":", 1)[0])
    return saved

def get_status(rescan=False):
    radio = run_out(["nmcli", "-t", "-f", "WIFI", "g"], timeout=2)
    enabled = (radio.lower() == "enabled")

    ip_addr = "-"
    ip_out = run_out(["ip", "-4", "route", "get", "1.1.1.1"], timeout=2)
    if "src" in ip_out:
        parts = ip_out.split()
        if "src" in parts:
            idx = parts.index("src")
            if idx + 1 < len(parts):
                ip_addr = parts[idx + 1]

    if not enabled:
        print(json.dumps({
            "enabled": False,
            "connected": False,
            "activeSsid": "",
            "ip": "-",
            "networks": []
        }), flush=True)
        return

    saved = get_saved_ssids()
    rescan_arg = "yes" if rescan else "no"
    raw = run_out(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", rescan_arg], timeout=8)

    by_ssid = {}
    active_ssid = ""

    for line in raw.splitlines():
        if not line.strip():
            continue
        in_use = line.startswith("*:")
        rest = line[2:] if (line.startswith("*:") or line.startswith(" :")) else line
        parts = rest.rsplit(":", 2)
        if len(parts) < 3:
            continue
        ssid = parts[0].replace("\\:", ":").strip()
        if not ssid:
            continue
        try:
            sig = int(parts[1])
        except Exception:
            sig = 0
        sec = parts[2].strip() or "open"
        is_sec = bool(sec and sec.lower() not in ("", "--", "open"))

        if in_use:
            active_ssid = ssid

        prev = by_ssid.get(ssid)
        if not prev or in_use or sig > prev["signal"]:
            by_ssid[ssid] = {
                "ssid": ssid,
                "signal": sig,
                "secure": is_sec,
                "security": sec.lower(),
                "active": in_use,
                "saved": (ssid in saved) or in_use
            }

    nets = list(by_ssid.values())
    nets.sort(key=lambda n: (0 if n["active"] else (1 if n["saved"] else 2), -n["signal"]))

    print(json.dumps({
        "enabled": True,
        "connected": bool(active_ssid),
        "activeSsid": active_ssid,
        "ip": ip_addr,
        "networks": nets[:14]
    }), flush=True)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        get_status(False)
    elif cmd == "scan":
        get_status(True)
    elif cmd == "toggle-radio":
        radio = run_out(["nmcli", "-t", "-f", "WIFI", "g"], timeout=2)
        target = "off" if radio.lower() == "enabled" else "on"
        subprocess.run(["nmcli", "radio", "wifi", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif cmd == "disconnect":
        devs = run_out(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "dev"], timeout=2)
        for line in devs.splitlines():
            p = line.split(":")
            if len(p) >= 3 and p[1] == "wifi" and p[2] == "connected":
                subprocess.run(["nmcli", "dev", "disconnect", p[0]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif cmd == "connect" and len(sys.argv) >= 3:
        ssid = sys.argv[2]
        pwd = sys.argv[3] if len(sys.argv) >= 4 else ""
        saved = get_saved_ssids()
        if pwd:
            subprocess.run(["nmcli", "dev", "wifi", "connect", ssid, "password", pwd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        elif ssid in saved:
            subprocess.run(["nmcli", "connection", "up", "id", ssid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=12)
        else:
            subprocess.run(["nmcli", "dev", "wifi", "connect", ssid], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=12)
    elif cmd == "forget" and len(sys.argv) >= 3:
        subprocess.run(["nmcli", "connection", "delete", "id", sys.argv[2]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
