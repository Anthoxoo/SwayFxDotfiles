#!/usr/bin/env python3
import curses
import subprocess
import glob
import os
import locale

try:
    locale.setlocale(locale.LC_ALL, '')
except Exception:
    pass

def safe_addstr(win, y, x, text, attr=0):
    try:
        h, w = win.getmaxyx()
        if 0 <= y < h and 0 <= x < w:
            max_len = w - x - 1
            if max_len > 0:
                win.addstr(y, x, text[:max_len], attr)
    except curses.error:
        pass

def read_sys(path, default=""):
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except Exception:
        return default

def get_history(current_cap, width):
    vals = []
    files = sorted(glob.glob("/var/lib/upower/history-charge-*.dat"), key=os.path.getmtime, reverse=True)
    if files:
        try:
            with open(files[0], "r") as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 2:
                        v = float(parts[1])
                        if 0 < v <= 100:
                            vals.append(v)
        except Exception:
            pass
    vals.append(float(current_cap))
    if len(vals) < width:
        vals = [vals[0]] * (width - len(vals)) + vals
    else:
        vals = vals[-width:]
    return vals

def get_bat_info():
    bats = sorted(glob.glob("/sys/class/power_supply/BAT*"))
    if not bats:
        return {"present": False}
    b = bats[0]
    cap = max(0, min(100, int(read_sys(f"{b}/capacity", "0") or 0)))
    status = read_sys(f"{b}/status", "Unknown")
    cycles = read_sys(f"{b}/cycle_count", "-")

    volt_uv = int(read_sys(f"{b}/voltage_now", "0") or 0)
    power_uw = int(read_sys(f"{b}/power_now", "0") or 0)
    curr_ua = int(read_sys(f"{b}/current_now", "0") or 0)

    if power_uw == 0 and curr_ua > 0 and volt_uv > 0:
        power_uw = int((curr_ua * volt_uv) / 1e6)

    energy_now = int(read_sys(f"{b}/energy_now", "0") or 0)
    energy_full = int(read_sys(f"{b}/energy_full", "0") or 0)
    energy_design = int(read_sys(f"{b}/energy_full_design", "0") or 0)

    if energy_now == 0:
        charge_now = int(read_sys(f"{b}/charge_now", "0") or 0)
        charge_full = int(read_sys(f"{b}/charge_full", "0") or 0)
        charge_design = int(read_sys(f"{b}/charge_full_design", "0") or 0)
        v_factor = (volt_uv / 1e6) if volt_uv > 0 else 11.4
        energy_now = int(charge_now * v_factor)
        energy_full = int(charge_full * v_factor)
        energy_design = int(charge_design * v_factor)

    power_w = power_uw / 1e6
    health = (energy_full / energy_design * 100.0) if energy_design > 0 else 100.0

    time_str = "-"
    if power_uw > 100000:
        if status == "Discharging" and energy_now > 0:
            hours = energy_now / power_uw
            time_str = f"{int(hours)}h {int((hours % 1) * 60):02d}m"
        elif status == "Charging" and energy_full > energy_now:
            hours = (energy_full - energy_now) / power_uw
            time_str = f"{int(hours)}h {int((hours % 1) * 60):02d}m"
    elif status in ("Full", "Not charging"):
        time_str = "AC"

    thresh_path = f"{b}/charge_control_end_threshold"
    thresh = read_sys(thresh_path, "") if os.path.exists(thresh_path) else None

    return {
        "present": True,
        "cap": cap,
        "status": status,
        "power_w": power_w,
        "health": health,
        "cycles": cycles,
        "time_str": time_str,
        "thresh_path": thresh_path if thresh else None,
        "thresh": thresh
    }

def get_profile():
    try:
        res = subprocess.run(["powerprofilesctl", "get"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
        if res.returncode == 0 and res.stdout.strip():
            return res.stdout.strip()
    except Exception:
        pass
    return "balanced"

def set_profile(prof):
    try:
        subprocess.run(["powerprofilesctl", "set", prof], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=4)
        return True
    except Exception:
        return False

def toggle_threshold(info):
    p = info.get("thresh_path")
    if not p:
        return False, "limit unsupported"
    cur = info.get("thresh", "100")
    new_val = "80" if cur == "100" else "100"
    try:
        with open(p, "w") as f:
            f.write(new_val)
        return True, f"limit set to {new_val}%"
    except Exception:
        return False, "permission denied"

def main(stdscr):
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    curses.use_default_colors()
    stdscr.timeout(1000)

    # Palette alignée sur la config (#141416, #e5e5e5, #ff8800, #888888, #2e2e32, #242428)
    curses.init_pair(1, 7, -1)  # #e5e5e5 (texte principal)
    curses.init_pair(2, 3, -1)  # #ff8800 (accent orange)
    curses.init_pair(3, 4, -1)  # #888888 (texte secondaire)
    curses.init_pair(4, 8, -1)  # #2e2e32 (bordures & barre vide)
    curses.init_pair(5, 1, -1)  # #e05252 (critique)
    curses.init_pair(6, 3, 2)   # #ff8800 sur fond #242428 (sélection sobre)

    profiles = [
        ("power-saver", "power-saver"),
        ("balanced",    "balanced"),
        ("performance", "performance")
    ]

    cur_prof = get_profile()
    idx = next((i for i, p in enumerate(profiles) if p[0] == cur_prof), 1)
    msg = ""
    blocks = " ▁▂▃▄▅▆▇█"

    while True:
        info = get_bat_info()
        cur_prof = get_profile()

        stdscr.erase()
        h, w = stdscr.getmaxyx()

        stdscr.attron(curses.color_pair(4))
        try:
            stdscr.border()
        except curses.error:
            pass
        stdscr.attroff(curses.color_pair(4))

        safe_addstr(stdscr, 0, 3, " battery ", curses.color_pair(2))

        if not info["present"]:
            safe_addstr(stdscr, 2, 4, "no battery detected", curses.color_pair(5))
        else:
            st = info["status"].lower()
            safe_addstr(stdscr, 0, max(2, w - len(st) - 5), f" {st} ", curses.color_pair(3))

            # Jauge bicolore (rempli = #ff8800, vide = #2e2e32)
            bar_w = max(10, w - 16)
            filled = int(round((info["cap"] / 100.0) * bar_w))
            empty = bar_w - filled
            cap_pair = curses.color_pair(5) if info["cap"] <= 15 else curses.color_pair(2)

            if filled > 0:
                safe_addstr(stdscr, 2, 4, "█" * filled, cap_pair)
            if empty > 0:
                safe_addstr(stdscr, 2, 4 + filled, "░" * empty, curses.color_pair(4))
            safe_addstr(stdscr, 2, 4 + bar_w + 2, f"{info['cap']:3d}%", curses.color_pair(1))

            # Graphe d'historique (sparkline)
            hist = get_history(info["cap"], bar_w)
            spark = "".join(blocks[min(8, max(1, int(round(v / 12.5))))] for v in hist)
            safe_addstr(stdscr, 3, 4, spark, curses.color_pair(3))
            safe_addstr(stdscr, 3, 4 + bar_w + 2, "hist", curses.color_pair(3))

            # Statistiques sobres
            col2 = max(26, w // 2)
            safe_addstr(stdscr, 5, 4,    "power", curses.color_pair(3))
            safe_addstr(stdscr, 5, 13,   f"{info['power_w']:.1f} W", curses.color_pair(1))
            safe_addstr(stdscr, 5, col2, "time", curses.color_pair(3))
            safe_addstr(stdscr, 5, col2 + 9, info["time_str"], curses.color_pair(1))

            safe_addstr(stdscr, 6, 4,    "health", curses.color_pair(3))
            safe_addstr(stdscr, 6, 13,   f"{info['health']:.0f}%", curses.color_pair(1))
            safe_addstr(stdscr, 6, col2, "cycles", curses.color_pair(3))
            safe_addstr(stdscr, 6, col2 + 9, str(info["cycles"]), curses.color_pair(1))

            if info["thresh"]:
                safe_addstr(stdscr, 7, 4,  "limit", curses.color_pair(3))
                safe_addstr(stdscr, 7, 13, f"{info['thresh']}%", curses.color_pair(2 if info["thresh"] == "80" else 1))

        try:
            stdscr.hline(9, 1, curses.ACS_HLINE | curses.color_pair(4), w - 2)
        except curses.error:
            pass

        safe_addstr(stdscr, 10, 4, "profile", curses.color_pair(3))

        for i, (p_id, p_label) in enumerate(profiles):
            y = 12 + i
            if y >= h - 2:
                break
            is_sel = (i == idx)
            is_act = (p_id == cur_prof)
            mark = "●" if is_act else "·"
            line = f"  {mark}  {p_label:<16}"

            if is_sel:
                safe_addstr(stdscr, y, 4, line, curses.color_pair(6))
            elif is_act:
                safe_addstr(stdscr, y, 4, line, curses.color_pair(2))
            else:
                safe_addstr(stdscr, y, 4, line, curses.color_pair(3))

        footer = msg if msg else "[ret] apply   [l] limit   [q] quit"
        safe_addstr(stdscr, h - 2, 4, footer, curses.color_pair(3))

        stdscr.refresh()

        ch = stdscr.getch()
        if ch == -1:
            continue
        msg = ""
        if ch == curses.KEY_RESIZE:
            curses.update_lines_cols()
        elif ch in (ord('q'), 27):
            break
        elif ch in (ord('j'), curses.KEY_DOWN):
            idx = (idx + 1) % len(profiles)
        elif ch in (ord('k'), curses.KEY_UP):
            idx = (idx - 1) % len(profiles)
        elif ch in (ord('1'), ord('2'), ord('3')):
            idx = ch - ord('1')
            set_profile(profiles[idx][0])
        elif ch in (10, 13, curses.KEY_ENTER):
            set_profile(profiles[idx][0])
        elif ch == ord('l') and info.get("present"):
            _, msg = toggle_threshold(info)

if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        pass
