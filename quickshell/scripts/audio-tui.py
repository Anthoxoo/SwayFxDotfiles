#!/usr/bin/env python3
import curses
import subprocess
import re
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

def run(cmd):
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=3)
        return res.stdout.strip()
    except Exception:
        return ""

def get_devices(kind="sinks"):
    singular = "sink" if kind == "sinks" else "source"
    default_name = run(["pactl", f"get-default-{singular}"])
    out = run(["pactl", "list", kind])

    devs = []
    for block in out.split(f"{singular.capitalize()} #")[1:]:
        name_m = re.search(r"Name:\s*(.+)", block)
        desc_m = re.search(r"Description:\s*(.+)", block)
        mute_m = re.search(r"Mute:\s*(yes|no)", block)
        vol_m = re.search(r"Volume:.*?(\d+)%", block)

        if not name_m:
            continue
        name = name_m.group(1).strip()
        if kind == "sources" and ".monitor" in name:
            continue

        desc = desc_m.group(1).strip() if desc_m else name
        muted = (mute_m.group(1) == "yes") if mute_m else False
        vol = int(vol_m.group(1)) if vol_m else 0

        devs.append({
            "name": name,
            "desc": desc,
            "muted": muted,
            "vol": vol,
            "default": (name == default_name)
        })
    return devs

def set_vol(delta):
    sign = "+" if delta > 0 else "-"
    subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{sign}{abs(delta)}%"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def toggle_mute(target="sink"):
    if target == "sink":
        subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.run(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def set_default(kind, name):
    singular = "sink" if kind == "sinks" else "source"
    subprocess.run(["pactl", f"set-default-{singular}", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def main(stdscr):
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    curses.use_default_colors()
    stdscr.timeout(400)

    # Palette alignée sur la config (#141416, #e5e5e5, #ff8800, #888888, #2e2e32, #242428)
    curses.init_pair(1, 7, -1)  # #e5e5e5 (texte principal)
    curses.init_pair(2, 3, -1)  # #ff8800 (accent orange)
    curses.init_pair(3, 4, -1)  # #888888 (texte secondaire)
    curses.init_pair(4, 8, -1)  # #2e2e32 (bordures & barre vide)
    curses.init_pair(5, 1, -1)  # #e05252 (critique)
    curses.init_pair(6, 3, 2)   # #ff8800 sur fond #242428 (sélection sobre)

    tab = "sinks"
    idx = 0

    while True:
        sinks = get_devices("sinks")
        sources = get_devices("sources")
        cur_sink = next((s for s in sinks if s["default"]), sinks[0] if sinks else None)
        cur_src = next((s for s in sources if s["default"]), sources[0] if sources else None)

        items = sinks if tab == "sinks" else sources
        if items:
            idx = max(0, min(idx, len(items) - 1))

        stdscr.erase()
        h, w = stdscr.getmaxyx()

        stdscr.attron(curses.color_pair(4))
        try:
            stdscr.border()
        except curses.error:
            pass
        stdscr.attroff(curses.color_pair(4))

        safe_addstr(stdscr, 0, 3, " audio ", curses.color_pair(2))

        if cur_sink:
            st = "muted" if cur_sink["muted"] else f"{cur_sink['vol']}%"
            safe_addstr(stdscr, 0, max(2, w - len(st) - 5), f" {st} ", curses.color_pair(3))

            # Jauge bicolore (rempli = #ff8800, vide = #2e2e32)
            bar_w = max(10, w - 16)
            filled = int(round((min(100, cur_sink["vol"]) / 100.0) * bar_w))
            empty = bar_w - filled
            bar_pair = curses.color_pair(3) if cur_sink["muted"] else curses.color_pair(2)

            if filled > 0:
                safe_addstr(stdscr, 2, 4, "█" * filled, bar_pair)
            if empty > 0:
                safe_addstr(stdscr, 2, 4 + filled, "░" * empty, curses.color_pair(4))
            safe_addstr(stdscr, 2, 4 + bar_w + 2, f"{cur_sink['vol']:3d}%", curses.color_pair(3 if cur_sink["muted"] else 1))

            safe_addstr(stdscr, 4, 4,  "output", curses.color_pair(3))
            safe_addstr(stdscr, 4, 13, cur_sink["desc"][:w - 18], curses.color_pair(1))

        if cur_src:
            mic_st = "muted" if cur_src["muted"] else f"{cur_src['vol']}%"
            safe_addstr(stdscr, 5, 4,  "input", curses.color_pair(3))
            safe_addstr(stdscr, 5, 13, f"{cur_src['desc'][:w - 28]} ({mic_st})", curses.color_pair(3 if cur_src["muted"] else 1))

        try:
            stdscr.hline(7, 1, curses.ACS_HLINE | curses.color_pair(4), w - 2)
        except curses.error:
            pass

        out_attr = curses.color_pair(2) if tab == "sinks" else curses.color_pair(3)
        in_attr = curses.color_pair(2) if tab == "sources" else curses.color_pair(3)
        safe_addstr(stdscr, 8, 4,  "output", out_attr)
        safe_addstr(stdscr, 8, 14, "input", in_attr)

        for i, dev in enumerate(items):
            y = 10 + i
            if y >= h - 2:
                break
            is_sel = (i == idx)
            mark = "●" if dev["default"] else "·"
            label = dev["desc"][:max(10, w - 16)]
            line = f"  {mark}  {label:<{max(10, w - 14)}}"

            if is_sel:
                safe_addstr(stdscr, y, 4, line, curses.color_pair(6))
            elif dev["default"]:
                safe_addstr(stdscr, y, 4, line, curses.color_pair(1))
            else:
                safe_addstr(stdscr, y, 4, line, curses.color_pair(3))

        footer = "[h/l] vol   [m] mute   [i] mic   [tab] view   [ret] set   [q] quit"
        safe_addstr(stdscr, h - 2, 4, footer, curses.color_pair(3))

        stdscr.refresh()

        ch = stdscr.getch()
        if ch == -1:
            continue
        elif ch == curses.KEY_RESIZE:
            curses.update_lines_cols()
        elif ch in (ord('q'), 27):
            break
        elif ch in (ord('j'), curses.KEY_DOWN):
            if items:
                idx = (idx + 1) % len(items)
        elif ch in (ord('k'), curses.KEY_UP):
            if items:
                idx = (idx - 1) % len(items)
        elif ch in (ord('l'), curses.KEY_RIGHT, ord('+')):
            set_vol(2)
        elif ch in (ord('h'), curses.KEY_LEFT, ord('-')):
            set_vol(-2)
        elif ch == ord('m'):
            toggle_mute("sink")
        elif ch == ord('i'):
            toggle_mute("source")
        elif ch == 9:
            tab = "sources" if tab == "sinks" else "sinks"
            idx = 0
        elif ch in (10, 13, curses.KEY_ENTER) and items:
            set_default(tab, items[idx]["name"])

if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        pass
