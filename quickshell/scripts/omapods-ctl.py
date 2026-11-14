#!/usr/bin/env python3
import os
import sys
import json
import subprocess

STATE_DIR = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
STATUS_FILE = os.path.join(STATE_DIR, "librepods", "status.json")
CACHE_FILE = os.path.expanduser("~/.cache/quickshell_pods_prefs.json")
CTL_BIN = os.path.expanduser("~/.local/bin/librepods-ctl")
if not os.path.exists(CTL_BIN):
    CTL_BIN = "librepods-ctl"

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

def is_daemon_running():
    res = subprocess.run(["pgrep", "-x", "librepods"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return res.returncode == 0

def get_val(d, keys, default=None):
    if not isinstance(d, dict):
        return default
    for k in keys:
        if k in d and d[k] is not None:
            return d[k]
    return default

def find_airpods_bt():
    """Détecte les AirPods via BlueZ (connectés ou appairés) et le profil PipeWire/PulseAudio."""
    mac, name, connected = "", "", False
    try:
        res = subprocess.run(["bluetoothctl", "devices"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2)
        for line in res.stdout.splitlines():
            parts = line.strip().split(" ", 2)
            if len(parts) >= 3 and "airpods" in parts[2].lower():
                cand_mac, cand_name = parts[1], parts[2]
                info = subprocess.run(["bluetoothctl", "info", cand_mac], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2).stdout
                is_conn = "Connected: yes" in info
                if is_conn or not mac:
                    mac, name, connected = cand_mac, cand_name, is_conn
                if is_conn:
                    break
    except Exception:
        pass

    profile = "a2dp"
    card_name = ""
    if mac:
        card_Guess = "bluez_card." + mac.replace(":", "_")
        try:
            cards = subprocess.run(["pactl", "list", "cards"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2).stdout
            if card_Guess in cards:
                card_name = card_Guess
                block = cards.split(card_Guess, 1)[1].split("Card #", 1)[0]
                for line in block.splitlines():
                    if "Active Profile:" in line:
                        act = line.split(":", 1)[1].strip().lower()
                        if "headset" in act or "hfp" in act or "hsp" in act:
                            profile = "hfp"
                        break
        except Exception:
            pass

    return {"mac": mac, "name": name, "connected": connected, "profile": profile, "card": card_name}

def parse_pod(raw, key_names):
    for k in key_names:
        v = raw.get(k)
        if isinstance(v, dict):
            avail = get_val(v, ["available", "connected", "isConnected"], True)
            st = str(get_val(v, ["status", "state"], "")).lower()
            chg = bool(get_val(v, ["charging", "isCharging", "is_charging"], False))
            ear = bool(get_val(v, ["inEar", "in_ear", "wearing"], False))
            lvl = get_val(v, ["battery", "level", "percent", "value"], -1)
            lvl = int(lvl) if isinstance(lvl, (int, float)) else -1
            if 0 < lvl <= 10 and get_val(v, ["scale"], 100) == 10:
                lvl *= 10
            if not avail or st == "disconnected" or (lvl <= 0 and not chg):
                lvl = -1
            return {"level": lvl, "charging": chg, "inEar": ear}
        elif isinstance(v, (int, float)):
            chg = bool(raw.get(f"{k}Charging", raw.get(f"{k}_charging", False)))
            ear = bool(raw.get(f"{k}InEar", raw.get(f"{k}_in_ear", False)))
            lvl = int(v)
            if lvl <= 0 and not chg:
                lvl = -1
            return {"level": lvl, "charging": chg, "inEar": ear}
    return {"level": -1, "charging": False, "inEar": False}

def run_ctl(verb):
    try:
        subprocess.run([CTL_BIN, verb], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
    except Exception:
        pass

def read_status():
    running = is_daemon_running()
    bt = find_airpods_bt()
    prefs = load_prefs()

    raw = {}
    if os.path.exists(STATUS_FILE):
        try:
            with open(STATUS_FILE, "r", encoding="utf-8") as f:
                content = f.read().strip()
            if content:
                raw = json.loads(content.splitlines()[-1])
                running = True
        except Exception:
            pass

    bat_obj = raw.get("battery") if isinstance(raw.get("battery"), dict) else (raw.get("pods") if isinstance(raw.get("pods"), dict) else raw)
    left = parse_pod(bat_obj, ["left", "leftPod", "left_pod", "L", "l"])
    right = parse_pod(bat_obj, ["right", "rightPod", "right_pod", "R", "r"])
    case = parse_pod(bat_obj, ["case", "caseBattery", "case_battery", "C", "c"])
    single = parse_pod(bat_obj, ["headphone", "single", "main"])

    active_levels = [p["level"] for p in (left, right, single) if p["level"] > 0]
    explicit_conn = get_val(raw, ["connected", "isConnected", "active"], None)
    state_str = str(get_val(raw, ["state", "status", "connectionState"], "")).lower()

    if explicit_conn is False or state_str in ("disconnected", "offline"):
        aap_connected = False
    elif explicit_conn is True or len(active_levels) > 0:
        aap_connected = True
    else:
        aap_connected = False

    # Si connectés en Bluetooth mais que le démon AAP n'a pas encore accroché le socket L2CAP
    connected = aap_connected or bt["connected"]

    if not connected:
        print(json.dumps({
            "running": running,
            "connected": False,
            "aapReady": False,
            "btMac": bt["mac"],
            "name": (bt["name"] or "airpods").lower(),
            "barPct": -1,
            "modes": ["anc", "adaptive", "transparency", "off"]
        }))
        return

    model_str = str(get_val(raw, ["model", "deviceModel", "product", "type"], bt["name"] or "AirPods 4 ANC"))
    name_str = str(get_val(raw, ["name", "deviceName", "alias"], bt["name"] or model_str))
    is_max = "max" in model_str.lower() or (single["level"] > 0 and left["level"] < 0 and right["level"] < 0)

    mode = str(get_val(raw, ["listeningMode", "noiseMode", "noise", "mode", "ancMode"], prefs.get("mode", "anc"))).lower()
    if mode in ("noise_cancellation", "noisecancellation", "nc"):
        mode = "anc"
    if mode not in ("anc", "adaptive", "transparency", "off"):
        mode = prefs.get("mode", "anc")

    caps = raw.get("capabilities") if isinstance(raw.get("capabilities"), dict) else raw
    modes_list = get_val(caps, ["modes", "listeningModes", "supportedModes", "noiseModes"], None)
    if not isinstance(modes_list, list) or len(modes_list) == 0:
        if "pro 3" in model_str.lower():
            modes_list = ["anc", "adaptive", "transparency"]
        else:
            modes_list = ["anc", "adaptive", "transparency", "off"]
    else:
        modes_list = [("anc" if m in ("noise_cancellation", "nc") else str(m).lower()) for m in modes_list]

    has_ca = bool(get_val(caps, ["conversationAwareness", "hasConversationAwareness", "ca", "supportsCa"], True))
    has_onebud = bool(get_val(caps, ["oneBudAnc", "hasOneBudAnc", "oneBud", "supportsOneBud"], not is_max))
    has_adaptive = "adaptive" in modes_list

    raw_ca = get_val(raw, ["conversationAwareness", "ca", "conversation_awareness"], None)
    if isinstance(raw_ca, dict):
        ca_val = bool(raw_ca.get("enabled", False))
    elif raw_ca is not None:
        ca_val = str(raw_ca).lower() in ("true", "1", "on", "yes", "enabled")
    else:
        ca_val = bool(prefs.get("ca", False))

    raw_ob = get_val(raw, ["oneBudAnc", "oneBud", "one_bud_anc", "singlePodAnc"], None)
    if isinstance(raw_ob, dict):
        onebud_val = bool(raw_ob.get("enabled", False))
    elif raw_ob is not None:
        onebud_val = str(raw_ob).lower() in ("true", "1", "on", "yes", "enabled")
    else:
        onebud_val = bool(prefs.get("oneBud", True))

    adaptive_lvl = int(get_val(raw, ["adaptiveLevel", "adaptiveNoiseLevel", "adaptive", "adaptive_level"], prefs.get("adaptiveLevel", 50)))
    ear_mode = str(get_val(raw, ["earDetection", "ear_detection", "ear"], prefs.get("ear", "one"))).lower()
    if ear_mode in ("never", "false", "0", "disabled"):
        ear_mode = "off"
    elif ear_mode not in ("one", "both", "off"):
        ear_mode = "one"

    lid_state = str(get_val(raw, ["caseLid", "lid", "lidState", "case_lid"], "")).lower()
    bar_pct = min(active_levels) if active_levels else -1

    out = {
        "running": running,
        "connected": True,
        "aapReady": aap_connected,
        "btMac": bt["mac"],
        "audioProfile": bt["profile"],
        "name": name_str,
        "model": model_str,
        "isMax": is_max,
        "barPct": bar_pct,
        "left": left,
        "right": right,
        "case": case,
        "single": single,
        "lid": lid_state,
        "mode": mode,
        "modes": modes_list,
        "hasCa": has_ca,
        "ca": ca_val,
        "hasOneBud": has_onebud,
        "oneBud": onebud_val,
        "hasAdaptive": has_adaptive,
        "adaptiveLevel": max(0, min(100, adaptive_lvl)),
        "ear": ear_mode
    }
    print(json.dumps(out))

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
    arg = sys.argv[1] if len(sys.argv) > 1 else "status"
    prefs = load_prefs()

    if arg == "status":
        read_status()
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
