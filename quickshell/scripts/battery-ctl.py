#!/usr/bin/env python3
import sys
import os
import glob
import json
import subprocess

def read_file(path, default=""):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return default

def read_int(path, default=0):
    val = read_file(path, "")
    try:
        return int(val)
    except Exception:
        return default

def get_status():
    bats = sorted(glob.glob("/sys/class/power_supply/BAT*"))
    bat_dir = bats[0] if bats else ""

    cap = read_int(os.path.join(bat_dir, "capacity"), 100) if bat_dir else 100
    status = read_file(os.path.join(bat_dir, "status"), "Discharging").lower() if bat_dir else "ac"
    cycles = read_int(os.path.join(bat_dir, "cycle_count"), 0) if bat_dir else 0

    # Puissance en Watts
    power_uw = read_int(os.path.join(bat_dir, "power_now"), 0) if bat_dir else 0
    if power_uw == 0 and bat_dir:
        curr_ua = read_int(os.path.join(bat_dir, "current_now"), 0)
        volt_uv = read_int(os.path.join(bat_dir, "voltage_now"), 0)
        power_uw = (curr_ua * volt_uv) // 1000000
    watts = round(power_uw / 1000000.0, 1)

    # Énergie & Santé (Health)
    e_now = read_int(os.path.join(bat_dir, "energy_now"), 0) if bat_dir else 0
    e_full = read_int(os.path.join(bat_dir, "energy_full"), 0) if bat_dir else 0
    e_des = read_int(os.path.join(bat_dir, "energy_full_design"), 0) if bat_dir else 0
    if e_full == 0 and bat_dir:
        v_nom = read_int(os.path.join(bat_dir, "voltage_min_design"), 11400000) or 11400000
        e_now = (read_int(os.path.join(bat_dir, "charge_now"), 0) * v_nom) // 1000000
        e_full = (read_int(os.path.join(bat_dir, "charge_full"), 0) * v_nom) // 1000000
        e_des = (read_int(os.path.join(bat_dir, "charge_full_design"), 0) * v_nom) // 1000000

    health = round((e_full / e_des) * 100) if e_des > 0 else 100
    health = max(1, min(100, health))

    # Estimation du temps restant
    time_str = "on ac power"
    if status == "discharging" and power_uw > 500000 and e_now > 0:
        hours = e_now / float(power_uw)
        h = int(hours)
        m = int((hours - h) * 60)
        time_str = f"{h}h {m:02d}m remaining"
    elif status == "charging" and power_uw > 500000 and e_full > e_now:
        hours = (e_full - e_now) / float(power_uw)
        h = int(hours)
        m = int((hours - h) * 60)
        time_str = f"{h}h {m:02d}m until full"
    elif status == "full":
        time_str = "fully charged"

    # Profil d'énergie
    prof = "balanced"
    try:
        r = subprocess.run(["powerprofilesctl", "get"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=1)
        if r.returncode == 0 and r.stdout.strip():
            prof = r.stdout.strip()
    except Exception:
        pass

    print(json.dumps({
        "capacity": cap,
        "status": status,
        "watts": watts,
        "timeStr": time_str,
        "health": health,
        "cycles": cycles,
        "profile": prof
    }), flush=True)

def set_profile(prof):
    try:
        subprocess.run(["powerprofilesctl", "set", prof], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
    except Exception:
        pass

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        get_status()
    elif cmd == "set-profile" and len(sys.argv) >= 3:
        set_profile(sys.argv[2])
    elif cmd == "cycle-profile":
        order = ["power-saver", "balanced", "performance"]
        cur = "balanced"
        try:
            r = subprocess.run(["powerprofilesctl", "get"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=1)
            if r.returncode == 0 and r.stdout.strip():
                cur = r.stdout.strip()
        except Exception:
            pass
        nxt = order[(order.index(cur) + 1) % len(order)] if cur in order else "balanced"
        set_profile(nxt)
