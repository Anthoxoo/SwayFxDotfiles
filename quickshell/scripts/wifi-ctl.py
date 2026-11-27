#!/usr/bin/env python3
"""Wi-Fi backend of the Quickshell menu (modules/WifiMenu.qml), through nmcli.

    wifi-ctl.py status | scan          JSON state on stdout
    wifi-ctl.py toggle-radio | disconnect
    wifi-ctl.py connect <ssid> [password]
    wifi-ctl.py forget <ssid>

SSIDs are kept exactly as broadcast (a trailing space is part of the name), and saved
networks are matched by the SSID stored in each connection, not by the connection's name.
Connection failures are reported with a notification carrying nmcli's message.
"""
import json
import re
import subprocess
import sys


def run_out(cmd, timeout=6):
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
        return r.stdout
    except Exception:
        return ""


def unescape(field):
    """nmcli terse output escapes ':' and '\\' with a backslash."""
    return re.sub(r"\\(.)", r"\1", field)


def saved_networks():
    """{ssid: connection uuid} for every saved Wi-Fi connection."""
    out = run_out(["nmcli", "-t", "-f", "UUID,TYPE", "connection", "show"], timeout=3)
    saved = {}
    for line in out.splitlines():
        uuid, _, ctype = line.partition(":")
        if ctype != "802-11-wireless":
            continue
        ssid = run_out(["nmcli", "-g", "802-11-wireless.ssid", "connection", "show", "uuid", uuid], timeout=3)
        ssid = unescape(ssid.rstrip("\n"))
        if ssid:
            saved.setdefault(ssid, uuid)
    return saved


def notify(title, body):
    subprocess.run(["notify-send", "-a", "Wi-Fi", "-i", "network-wireless", title, body],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def nmcli_action(args, ssid, timeout):
    """Runs a connecting nmcli command; notifies on failure (not on a slow activation)."""
    try:
        r = subprocess.run(["nmcli", "--wait", str(timeout - 5), *args], stdout=subprocess.DEVNULL,
                           stderr=subprocess.PIPE, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return  # NetworkManager keeps trying on its own
    if r.returncode != 0:
        msg = (r.stderr.strip().splitlines() or ["unknown error"])[-1]
        msg = re.sub(r"^Error:\s*", "", msg)
        notify(f"Can't connect to {ssid.strip() or ssid}", msg)


def get_status(rescan=False):
    radio = run_out(["nmcli", "-t", "-f", "WIFI", "g"], timeout=2).strip()
    enabled = (radio.lower() == "enabled")

    ip_addr = "-"
    parts = run_out(["ip", "-4", "route", "get", "1.1.1.1"], timeout=2).split()
    if "src" in parts:
        idx = parts.index("src")
        if idx + 1 < len(parts):
            ip_addr = parts[idx + 1]

    if not enabled:
        print(json.dumps({"enabled": False, "connected": False, "activeSsid": "", "ip": "-",
                          "networks": []}), flush=True)
        return

    saved = saved_networks()
    raw = run_out(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list",
                   "--rescan", "yes" if rescan else "no"], timeout=8)

    by_ssid = {}
    active_ssid = ""
    for line in raw.splitlines():
        if len(line) < 2 or line[1] != ":":
            continue
        in_use = line[0] == "*"
        # SSID may contain escaped colons: split the two last fields from the right
        fields = line[2:].rsplit(":", 2)
        if len(fields) < 3:
            continue
        ssid = unescape(fields[0])
        if not ssid:
            continue  # hidden network
        try:
            sig = int(fields[1])
        except ValueError:
            sig = 0
        sec = fields[2].strip() or "open"
        is_sec = sec.lower() not in ("", "--", "open")

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
                "saved": ssid in saved or in_use,
            }

    nets = sorted(by_ssid.values(),
                  key=lambda n: (0 if n["active"] else (1 if n["saved"] else 2), -n["signal"]))
    print(json.dumps({"enabled": True, "connected": bool(active_ssid), "activeSsid": active_ssid,
                      "ip": ip_addr, "networks": nets[:14]}), flush=True)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        get_status(False)
    elif cmd == "scan":
        get_status(True)
    elif cmd == "toggle-radio":
        radio = run_out(["nmcli", "-t", "-f", "WIFI", "g"], timeout=2).strip()
        target = "off" if radio.lower() == "enabled" else "on"
        subprocess.run(["nmcli", "radio", "wifi", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif cmd == "disconnect":
        for line in run_out(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "dev"], timeout=2).splitlines():
            p = line.split(":")
            if len(p) >= 3 and p[1] == "wifi" and p[2] == "connected":
                subprocess.run(["nmcli", "dev", "disconnect", p[0]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif cmd == "connect" and len(sys.argv) >= 3:
        ssid = sys.argv[2]
        pwd = sys.argv[3] if len(sys.argv) >= 4 else ""
        uuid = saved_networks().get(ssid)
        if pwd:
            # Fallback only: the menu normally hands passwords to NetworkManager over D-Bus
            nmcli_action(["dev", "wifi", "connect", ssid, "password", pwd], ssid, 30)
        elif uuid:
            nmcli_action(["connection", "up", "uuid", uuid], ssid, 30)
        else:
            nmcli_action(["dev", "wifi", "connect", ssid], ssid, 30)
    elif cmd == "forget" and len(sys.argv) >= 3:
        uuid = saved_networks().get(sys.argv[2])
        target = ["uuid", uuid] if uuid else ["id", sys.argv[2]]
        subprocess.run(["nmcli", "connection", "delete", *target], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=4)


if __name__ == "__main__":
    main()
