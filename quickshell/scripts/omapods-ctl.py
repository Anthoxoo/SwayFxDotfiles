#!/usr/bin/env python3
# Commandes AirPods pour Quickshell (core/SysState.qml).
# L'état affiché (batteries, mode, réglages) est lu directement par Quickshell dans
# $XDG_STATE_HOME/librepods/status.json ; ce script ne sert plus qu'aux actions et au profil audio.
#   omapods-ctl.py profile                 -> "a2dp" ou "hfp"
#   omapods-ctl.py noise:<mode> | adaptive:<0-100> | ca:on|off | onebud:on|off | ear:one|both|off
#   omapods-ctl.py profile:a2dp|hfp | bt-toggle | reopen | cycle-mode
import os
import re
import sys
import json
import subprocess

CACHE_FILE = os.path.expanduser("~/.cache/quickshell_pods_prefs.json")
CTL_BIN = os.path.expanduser("~/.local/bin/librepods-ctl")
if not os.path.exists(CTL_BIN):
    CTL_BIN = "librepods-ctl"

# Pendant un scan Bluetooth, bluetoothctl intercale des événements « [CHG] Device … » dans sa
# sortie : on ne garde que les vraies lignes « Device <MAC> <nom> » et les lignes indentées de `info`.
DEVICE_LINE = re.compile(r"^Device ((?:[0-9A-F]{2}:){5}[0-9A-F]{2}) (.+)$", re.IGNORECASE)

def load_prefs():
    try:
        if os.path.exists(CACHE_FILE):
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {
        "mode": "anc",
        "adaptiveLevel": 50,
        "ca": False,
        "oneBud": True,
        "ear": "one"
    }

def save_prefs(prefs):
    try:
        os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(prefs, f)
    except Exception:
        pass

def find_airpods_bt():
    """Détecte les AirPods via BlueZ (connectés ou appairés) et le profil PipeWire/PulseAudio."""
    mac, name, connected = "", "", False
    try:
        res = subprocess.run(["bluetoothctl", "devices"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=3)
        for line in res.stdout.splitlines():
            m = DEVICE_LINE.match(line.strip())
            if not m or "airpods" not in m.group(2).lower():
                continue
            cand_mac, cand_name = m.group(1).upper(), m.group(2).strip()
            info = subprocess.run(["bluetoothctl", "info", cand_mac], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2).stdout
            is_conn = "Connected: yes" in [l.strip() for l in info.splitlines() if l[:1] in ("\t", " ")]
            if is_conn or not mac:
                mac, name, connected = cand_mac, cand_name, is_conn
            if is_conn:
                break
    except Exception:
        pass

    profile = "a2dp"
    card_name = ""
    if mac:
        card_guess = "bluez_card." + mac.replace(":", "_")
        try:
            cards = subprocess.run(["pactl", "list", "cards"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2).stdout
            if card_guess in cards:
                card_name = card_guess
                block = cards.split(card_guess, 1)[1].split("Card #", 1)[0]
                for line in block.splitlines():
                    if "Active Profile:" in line:
                        act = line.split(":", 1)[1].strip().lower()
                        if "headset" in act or "hfp" in act or "hsp" in act:
                            profile = "hfp"
                        break
        except Exception:
            pass

    return {"mac": mac, "name": name, "connected": connected, "profile": profile, "card": card_name}

def run_ctl(verb):
    try:
        subprocess.run([CTL_BIN, verb], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
    except Exception:
        pass

def set_audio_profile(target_prof):
    bt = find_airpods_bt()
    card = bt.get("card")
    if not card:
        return
    try:
        cards = subprocess.run(["pactl", "list", "cards"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2).stdout
        block = cards.split(card, 1)[1].split("Card #", 1)[0]
        profiles = []
        in_prof = False
        for line in block.splitlines():
            if line.strip().startswith("Profiles:"):
                in_prof = True
                continue
            if in_prof:
                if line.strip().startswith("Active Profile:") or line.strip().startswith("Ports:"):
                    break
                pname = line.strip().split(":", 1)[0].strip()
                if pname:
                    profiles.append(pname)
        chosen = ""
        if target_prof == "hfp":
            for p in profiles:
                if any(k in p.lower() for k in ("msbc", "headset-head-unit", "hfp", "hsp")):
                    chosen = p
                    break
        else:
            for p in profiles:
                if "sbc_xq" in p.lower() or "a2dp" in p.lower():
                    chosen = p
                    break
        if chosen:
            subprocess.run(["pactl", "set-card-profile", card, chosen], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    prefs = load_prefs()

    if arg == "":
        print(f"usage: {sys.argv[0]} profile | noise:<mode> | adaptive:<n> | ca:on|off | onebud:on|off | ear:<one|both|off> | profile:<a2dp|hfp> | bt-toggle | reopen", file=sys.stderr)
        sys.exit(1)
    elif arg == "profile":
        print(find_airpods_bt()["profile"])
    elif arg == "cycle-mode":
        order = ["anc", "adaptive", "transparency", "off"]
        cur = prefs.get("mode", "anc")
        nxt = order[(order.index(cur) + 1) % len(order)] if cur in order else "anc"
        prefs["mode"] = nxt
        save_prefs(prefs)
        run_ctl(f"noise:{nxt}")
    elif arg.startswith("noise:"):
        m = arg.split(":", 1)[1]
        prefs["mode"] = m
        save_prefs(prefs)
        run_ctl(f"noise:{m}")
    elif arg.startswith("adaptive:"):
        try:
            lvl = max(0, min(100, int(arg.split(":", 1)[1])))
            prefs["adaptiveLevel"] = lvl
            save_prefs(prefs)
            run_ctl(f"adaptive:{lvl}")
        except Exception:
            pass
    elif arg.startswith("ca:"):
        val = arg.split(":", 1)[1].lower() in ("on", "true", "1")
        prefs["ca"] = val
        save_prefs(prefs)
        run_ctl(f"ca:{'on' if val else 'off'}")
    elif arg.startswith("onebud:"):
        val = arg.split(":", 1)[1].lower() in ("on", "true", "1")
        prefs["oneBud"] = val
        save_prefs(prefs)
        run_ctl(f"onebud:{'on' if val else 'off'}")
    elif arg.startswith("ear:"):
        val = arg.split(":", 1)[1].lower()
        prefs["ear"] = val
        save_prefs(prefs)
        run_ctl(f"ear:{val}")
    elif arg.startswith("profile:"):
        set_audio_profile(arg.split(":", 1)[1].lower())
    elif arg == "bt-toggle":
        bt = find_airpods_bt()
        if bt["mac"]:
            verb = "disconnect" if bt["connected"] else "connect"
            subprocess.run(["bluetoothctl", verb, bt["mac"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if verb == "connect":
                run_ctl("reopen")
    elif arg == "reopen":
        run_ctl("reopen")
    else:
        run_ctl(arg)
