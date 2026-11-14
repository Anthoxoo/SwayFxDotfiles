#!/usr/bin/env python3
import sys
import os
import json
import subprocess

CFG_FILE = os.path.expanduser("~/.cache/quickshell_monitors_cfg.json")

def load_cfg():
    try:
        if os.path.exists(CFG_FILE):
            with open(CFG_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {"hideWhenSingle": False}

def save_cfg(cfg):
    os.makedirs(os.path.dirname(CFG_FILE), exist_ok=True)
    with open(CFG_FILE, "w", encoding="utf-8") as f:
        json.dump(cfg, f)

def get_raw_outputs():
    try:
        res = subprocess.run(["swaymsg", "-t", "get_outputs", "-r"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
        if res.returncode == 0:
            return json.loads(res.stdout)
    except Exception:
        pass
    return []

def parse_outputs():
    raw = get_raw_outputs()
    outputs = []
    for o in raw:
        name = o.get("name", "")
        if not name or name.startswith("HEADLESS"):
            continue
        active = bool(o.get("active", False))
        scale = float(o.get("scale", 1.0) or 1.0)
        if scale <= 0:
            scale = 1.0

        rect = o.get("rect") or {}
        all_modes = o.get("modes") or []
        mode = o.get("current_mode") or (all_modes[0] if all_modes else {})
        phys_w = int(mode.get("width", 1920) or 1920)
        phys_h = int(mode.get("height", 1080) or 1080)
        cur_ref_mhz = int(mode.get("refresh", 60000) or 60000)
        cur_hz = int(round(cur_ref_mhz / 1000.0))

        # Extraire tous les taux de rafraîchissement supportés pour cette résolution
        hz_map = {}
        for m in all_modes:
            mw = int(m.get("width", 0) or 0)
            mh = int(m.get("height", 0) or 0)
            mref = int(m.get("refresh", 0) or 0)
            if mw == phys_w and mh == phys_h and mref > 0:
                hz_int = int(round(mref / 1000.0))
                # Garder la valeur mHz la plus proche de l'entier (ex: 60000 plutôt que 59940)
                if hz_int not in hz_map or abs(mref - hz_int * 1000) < abs(hz_map[hz_int] - hz_int * 1000):
                    hz_map[hz_int] = mref

        if not hz_map:
            hz_map[cur_hz] = cur_ref_mhz

        rates = [
            {
                "hz": h,
                "modeStr": f"{phys_w}x{phys_h}@{hz_map[h] / 1000.0:.3f}Hz"
            }
            for h in sorted(hz_map.keys())
        ]

        w = int(rect.get("width", 0) or round(phys_w / scale))
        h = int(rect.get("height", 0) or round(phys_h / scale))
        x = int(rect.get("x", 0) or 0)
        y = int(rect.get("y", 0) or 0)

        desc = f"{o.get('make', '')} {o.get('model', '')}".strip()
        if not desc or desc == "Unknown Unknown":
            desc = name

        outputs.append({
            "name": name,
            "desc": desc.lower(),
            "active": active,
            "focused": bool(o.get("focused", False)),
            "scale": round(scale, 2),
            "x": x,
            "y": y,
            "width": w,
            "height": h,
            "physWidth": phys_w,
            "physHeight": phys_h,
            "hz": cur_hz,
            "rates": rates,
            "hasHighHz": len(rates) > 1 or any(r["hz"] > 60 for r in rates)
        })

    outputs.sort(key=lambda item: (0 if item["name"].startswith(("eDP", "LVDS")) else 1, item["name"]))
    return outputs

def print_status():
    cfg = load_cfg()
    outs = parse_outputs()
    active_outs = [o for o in outs if o["active"]]
    out_data = {
        "count": len(outs),
        "activeCount": len(active_outs),
        "hideWhenSingle": bool(cfg.get("hideWhenSingle", False)),
        "outputs": outs
    }
    print(json.dumps(out_data), flush=True)

def apply_positions(pos_map):
    outs = parse_outputs()
    active_list = []
    for o in outs:
        if not o["active"]:
            continue
        name = o["name"]
        nx = int(pos_map.get(name, {}).get("x", o["x"]))
        ny = int(pos_map.get(name, {}).get("y", o["y"]))
        active_list.append((name, nx, ny))

    if not active_list:
        return

    min_x = min(item[1] for item in active_list)
    min_y = min(item[2] for item in active_list)

    cmds = []
    for name, nx, ny in active_list:
        cmds.append(f"output {name} pos {nx - min_x} {ny - min_y}")

    subprocess.run(["swaymsg", "; ".join(cmds)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def place_relative(target_name, direction):
    outs = parse_outputs()
    active = [o for o in outs if o["active"]]
    if len(active) < 2:
        return

    target = next((o for o in active if o["name"] == target_name), active[-1])
    anchor = next((o for o in active if o["name"] != target["name"]), active[0])

    ax, ay, aw, ah = anchor["x"], anchor["y"], anchor["width"], anchor["height"]
    tw, th = target["width"], target["height"]

    if direction == "left":
        tx = ax - tw
        ty = ay + (ah - th) // 2
    elif direction == "right":
        tx = ax + aw
        ty = ay + (ah - th) // 2
    elif direction == "above":
        tx = ax + (aw - tw) // 2
        ty = ay - th
    elif direction == "below":
        tx = ax + (aw - tw) // 2
        ty = ay + ah
    else:
        return

    pos_map = {o["name"]: {"x": o["x"], "y": o["y"]} for o in active}
    pos_map[target["name"]] = {"x": tx, "y": ty}
    apply_positions(pos_map)

def toggle_output(target_name):
    outs = parse_outputs()
    target = next((o for o in outs if o["name"] == target_name), None)
    if not target:
        return
    active_count = sum(1 for o in outs if o["active"])
    if target["active"] and active_count <= 1:
        return
    state = "disable" if target["active"] else "enable"
    subprocess.run(["swaymsg", f"output {target_name} {state}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def set_scale(target_name, scale_val):
    subprocess.run(["swaymsg", f"output {target_name} scale {scale_val}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def set_rate(target_name, mode_str):
    subprocess.run(["swaymsg", f"output {target_name} mode {mode_str}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print_status()
    elif cmd == "place" and len(sys.argv) >= 4:
        place_relative(sys.argv[2], sys.argv[3])
    elif cmd == "set-pos" and len(sys.argv) >= 3:
        try:
            apply_positions(json.loads(sys.argv[2]))
        except Exception:
            pass
    elif cmd == "toggle" and len(sys.argv) >= 3:
        toggle_output(sys.argv[2])
    elif cmd == "scale" and len(sys.argv) >= 4:
        set_scale(sys.argv[2], sys.argv[3])
    elif cmd == "rate" and len(sys.argv) >= 4:
        set_rate(sys.argv[2], sys.argv[3])
    elif cmd == "toggle-autohide":
        c = load_cfg()
        c["hideWhenSingle"] = not bool(c.get("hideWhenSingle", False))
        save_cfg(c)
