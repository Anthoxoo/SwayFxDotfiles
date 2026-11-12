#!/usr/bin/env python3
import os
import sys
import json
import subprocess

STATE_DIR = os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state"))
STATUS_FILE = os.path.join(STATE_DIR, "librepods", "status.json")
CTL_BIN = os.path.expanduser("~/.local/bin/librepods-ctl")
if not os.path.exists(CTL_BIN):
    CTL_BIN = "librepods-ctl"

def get_val(d, keys, default=None):
    if not isinstance(d, dict):
        return default
    for k in keys:
        if k in d and d[k] is not None:
            return d[k]
    return default

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

def read_status():
    if not os.path.exists(STATUS_FILE):
        print(json.dumps({"running": False, "connected": False, "barPct": -1}))
        return

    try:
        with open(STATUS_FILE, "r", encoding="utf-8") as f:
            content = f.read().strip()
        if not content:
            print(json.dumps({"running": True, "connected": False, "barPct": -1}))
            return
        raw = json.loads(content.splitlines()[-1])
    except Exception:
        print(json.dumps({"running": True, "connected": False, "barPct": -1}))
        return

    bat_obj = raw.get("battery") if isinstance(raw.get("battery"), dict) else raw
    left = parse_pod(bat_obj, ["left", "leftPod", "left_pod", "L"])
    right = parse_pod(bat_obj, ["right", "rightPod", "right_pod", "R"])
    case = parse_pod(bat_obj, ["case", "caseBattery", "case_battery", "C"])
    single = parse_pod(bat_obj, ["headphone", "single", "main"])

    active_levels = [p["level"] for p in (left, right, single) if p["level"] > 0]

    explicit_conn = get_val(raw, ["connected", "isConnected", "active"], None)
    state_str = str(get_val(raw, ["state", "status", "connectionState"], "")).lower()

    if explicit_conn is False or state_str in ("disconnected", "offline", "idle"):
        connected = False
    elif explicit_conn is True:
        connected = len(active_levels) > 0
    else:
        connected = len(active_levels) > 0

    if not connected:
        print(json.dumps({
            "running": True,
            "connected": False,
            "barPct": -1,
            "modes": []
        }))
        return

    model_str = str(get_val(raw, ["model", "deviceModel", "product", "type"], "AirPods"))
    name_str = str(get_val(raw, ["name", "deviceName", "alias"], model_str))
    is_max = "max" in model_str.lower() or (single["level"] > 0 and left["level"] < 0 and right["level"] < 0)

    mode = str(get_val(raw, ["listeningMode", "noiseMode", "noise", "mode", "ancMode"], "")).lower()
    if mode in ("noise_cancellation", "noisecancellation", "nc"):
        mode = "anc"

    caps = raw.get("capabilities") if isinstance(raw.get("capabilities"), dict) else raw
    modes_list = get_val(caps, ["modes", "listeningModes", "supportedModes", "noiseModes"], None)
    if not isinstance(modes_list, list):
        if "pro 3" in model_str.lower():
            modes_list = ["anc", "adaptive", "transparency"]
        elif any(x in model_str.lower() for x in ("pro", "max", "anc", "4")):
            modes_list = ["anc", "adaptive", "transparency", "off"]
        else:
            modes_list = []
    else:
        modes_list = [("anc" if m in ("noise_cancellation", "nc") else str(m).lower()) for m in modes_list]

    has_ca = bool(get_val(caps, ["conversationAwareness", "hasConversationAwareness", "ca", "supportsCa"], "adaptive" in modes_list))
    has_onebud = bool(get_val(caps, ["oneBudAnc", "hasOneBudAnc", "oneBud", "supportsOneBud"], (not is_max) and ("anc" in modes_list)))
    has_adaptive = "adaptive" in modes_list

    ca_val = bool(get_val(raw, ["conversationAwareness", "ca", "conversation_awareness"], False))
    if isinstance(raw.get("conversationAwareness"), dict):
        ca_val = bool(raw["conversationAwareness"].get("enabled", False))

    onebud_val = bool(get_val(raw, ["oneBudAnc", "oneBud", "one_bud_anc", "singlePodAnc"], False))
    if isinstance(raw.get("oneBudAnc"), dict):
        onebud_val = bool(raw["oneBudAnc"].get("enabled", False))

    adaptive_lvl = int(get_val(raw, ["adaptiveLevel", "adaptiveNoiseLevel", "adaptive", "adaptive_level"], 50))
    ear_mode = str(get_val(raw, ["earDetection", "ear_detection", "ear"], "one"))
    lid_state = str(get_val(raw, ["caseLid", "lid", "lidState", "case_lid"], ""))

    bar_pct = min(active_levels) if active_levels else -1

    out = {
        "running": True,
        "connected": True,
        "name": name_str,
        "model": model_str,
        "isMax": is_max,
        "barPct": bar_pct,
        "left": left,
        "right": right,
        "case": case,
        "single": single,
        "lid": lid_state.lower(),
        "mode": mode,
        "modes": modes_list,
        "hasCa": has_ca,
        "ca": ca_val,
        "hasOneBud": has_onebud,
        "oneBud": onebud_val,
        "hasAdaptive": has_adaptive,
        "adaptiveLevel": max(0, min(100, adaptive_lvl)),
        "ear": ear_mode.lower()
    }
    print(json.dumps(out))

def run_ctl(verb):
    try:
        subprocess.run([CTL_BIN, verb], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=3)
    except Exception:
        pass

if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] == "status":
        read_status()
    elif sys.argv[1] == "cycle-mode":
        try:
            with open(STATUS_FILE, "r", encoding="utf-8") as f:
                raw = json.loads(f.read().strip().splitlines()[-1])
            cur = str(get_val(raw, ["listeningMode", "noiseMode", "noise", "mode"], "off")).lower()
            if cur in ("noise_cancellation", "nc"):
                cur = "anc"
            caps = raw.get("capabilities") if isinstance(raw.get("capabilities"), dict) else raw
            modes = get_val(caps, ["modes", "listeningModes", "supportedModes"], ["anc", "adaptive", "transparency", "off"])
            modes = [("anc" if m in ("noise_cancellation", "nc") else str(m).lower()) for m in modes]
            if modes:
                nxt = modes[(modes.index(cur) + 1) % len(modes)] if cur in modes else modes[0]
                run_ctl(f"noise:{nxt}")
        except Exception:
            pass
    else:
        run_ctl(sys.argv[1])
