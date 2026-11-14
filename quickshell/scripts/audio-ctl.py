#!/usr/bin/env python3
import sys
import json
import subprocess

def run_out(cmd):
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=2)
        return r.stdout if r.returncode == 0 else ""
    except Exception:
        return ""

def get_status():
    def_sink = run_out(["pactl", "get-default-sink"]).strip()
    def_src = run_out(["pactl", "get-default-source"]).strip()

    sinks_raw = []
    sources_raw = []
    inputs_raw = []
    try:
        sinks_raw = json.loads(run_out(["pactl", "-f", "json", "list", "sinks"]) or "[]")
        sources_raw = json.loads(run_out(["pactl", "-f", "json", "list", "sources"]) or "[]")
        inputs_raw = json.loads(run_out(["pactl", "-f", "json", "list", "sink-inputs"]) or "[]")
    except Exception:
        pass

    def extract_vol(obj):
        vol_dict = obj.get("volume") or {}
        for k, v in vol_dict.items():
            vp = str(v.get("value_percent", "0%")).replace("%", "").strip()
            try:
                return max(0, min(150, int(vp)))
            except Exception:
                pass
        return 0

    sinks = []
    out_vol = 0
    out_muted = False
    for s in sinks_raw:
        name = s.get("name", "")
        props = s.get("properties") or {}
        desc = s.get("description") or props.get("device.description") or name
        v = extract_vol(s)
        m = bool(s.get("mute", False))
        is_def = (name == def_sink)
        if is_def:
            out_vol = v
            out_muted = m
        sinks.append({
            "name": name,
            "desc": str(desc).lower(),
            "vol": v,
            "muted": m,
            "active": is_def
        })

    sources = []
    mic_vol = 0
    mic_muted = False
    for s in sources_raw:
        name = s.get("name", "")
        if ".monitor" in name:
            continue
        props = s.get("properties") or {}
        desc = s.get("description") or props.get("device.description") or name
        v = extract_vol(s)
        m = bool(s.get("mute", False))
        is_def = (name == def_src)
        if is_def:
            mic_vol = v
            mic_muted = m
        sources.append({
            "name": name,
            "desc": str(desc).lower(),
            "vol": v,
            "muted": m,
            "active": is_def
        })

    apps = []
    for inp in inputs_raw:
        idx = inp.get("index")
        props = inp.get("properties") or {}
        app_name = props.get("application.name") or props.get("media.name") or "stream"
        v = extract_vol(inp)
        m = bool(inp.get("mute", False))
        apps.append({
            "id": str(idx),
            "name": str(app_name).lower(),
            "vol": v,
            "muted": m
        })

    print(json.dumps({
        "vol": out_vol,
        "muted": out_muted,
        "micVol": mic_vol,
        "micMuted": mic_muted,
        "sinks": sinks,
        "sources": sources,
        "apps": apps
    }), flush=True)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        get_status()
    elif cmd == "set-vol" and len(sys.argv) >= 3:
        subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{sys.argv[2]}%"])
    elif cmd == "toggle-mute":
        subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"])
    elif cmd == "set-mic-vol" and len(sys.argv) >= 3:
        subprocess.run(["pactl", "set-source-volume", "@DEFAULT_SOURCE@", f"{sys.argv[2]}%"])
    elif cmd == "toggle-mic":
        subprocess.run(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"])
    elif cmd == "set-sink" and len(sys.argv) >= 3:
        target = sys.argv[2]
        subprocess.run(["pactl", "set-default-sink", target])
        try:
            inputs = json.loads(run_out(["pactl", "-f", "json", "list", "sink-inputs"]) or "[]")
            for inp in inputs:
                if "index" in inp:
                    subprocess.run(["pactl", "move-sink-input", str(inp["index"]), target])
        except Exception:
            pass
    elif cmd == "set-source" and len(sys.argv) >= 3:
        subprocess.run(["pactl", "set-default-source", sys.argv[2]])
    elif cmd == "set-app-vol" and len(sys.argv) >= 4:
        subprocess.run(["pactl", "set-sink-input-volume", sys.argv[2], f"{sys.argv[3]}%"])
    elif cmd == "toggle-app-mute" and len(sys.argv) >= 3:
        subprocess.run(["pactl", "set-sink-input-mute", sys.argv[2], "toggle"])
