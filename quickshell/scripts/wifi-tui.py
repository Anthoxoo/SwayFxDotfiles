#!/usr/bin/env python3
import curses
import subprocess
import locale
import os
import atexit

PID_FILE = "/tmp/omarchy-wifi.pid"

try:
    locale.setlocale(locale.LC_ALL, '')
except Exception:
    pass

def cleanup_pid():
    try:
        if os.path.exists(PID_FILE):
            os.remove(PID_FILE)
    except Exception:
        pass

with open(PID_FILE, "w") as f:
    f.write(str(os.getpid()))
atexit.register(cleanup_pid)

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
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=15)
        return res.returncode, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def get_wifi_state():
    _, out, _ = run(["nmcli", "-t", "-f", "WIFI", "general"])
    return out.strip() == "enabled"

def get_ip():
    _, out, _ = run(["sh", "-c", "ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i==\"src\") print $(i+1)}' | head -n1"])
    return out if out else "Aucune IP"

def get_saved_ssids():
    _, out, _ = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"])
    saved = set()
    for line in out.splitlines():
        if ":802-11-wireless" in line:
            saved.add(line.split(":")[0])
    return saved

def get_networks(rescan=False):
    if rescan:
        run(["nmcli", "dev", "wifi", "rescan"])
    _, out, _ = run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no"])
    saved = get_saved_ssids()
    nets = []
    seen = set()
    for line in out.splitlines():
        if not line:
            continue
        parts = line.replace("\\:", "__COLON__").split(":")
        if len(parts) < 4:
            continue
        in_use = parts[0] == "*"
        ssid = parts[1].replace("__COLON__", ":").strip()
        if not ssid or ssid in seen:
            continue
        seen.add(ssid)
        try:
            sig = int(parts[2])
        except ValueError:
            sig = 0
        sec = parts[3].strip()
        nets.append({
            "in_use": in_use,
            "ssid": ssid,
            "signal": sig,
            "security": sec if sec else "Ouvert",
            "saved": ssid in saved
        })
    nets.sort(key=lambda x: (not x["in_use"], not x["saved"], -x["signal"]))
    return nets

def sig_icon(sig):
    icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
    return icons[min(4, max(0, sig // 22))]

def prompt_password(stdscr, ssid):
    h, w = stdscr.getmaxyx()
    bw, bh = max(30, min(54, w - 4)), 7
    by, bx = max(1, (h - bh) // 2), max(1, (w - bw) // 2)

    win = curses.newwin(bh, bw, by, bx)
    win.keypad(True)
    win.bkgd(' ', curses.color_pair(1))

    pwd = ""
    try:
        curses.curs_set(1)
    except curses.error:
        pass

    while True:
        win.erase()
        win.attron(curses.color_pair(2))
        try:
            win.border()
        except curses.error:
            pass
        win.attroff(curses.color_pair(2))

        title = f"  Mot de passe : {ssid[:bw-22]} "
        safe_addstr(win, 0, 2, title, curses.color_pair(2) | curses.A_BOLD)
        safe_addstr(win, 2, 2, "Clé Wi-Fi (Entrée = valider, Échap = annuler) :", curses.color_pair(3))
        masked = "*" * len(pwd)
        safe_addstr(win, 4, 3, masked[-(bw - 6):], curses.color_pair(1))
        win.refresh()

        try:
            ch = win.get_wch()
        except curses.error:
            continue

        if ch in ("\n", "\r", curses.KEY_ENTER, 10, 13):
            try:
                curses.curs_set(0)
            except curses.error:
                pass
            return pwd
        elif ch in ("\x1b", 27):
            try:
                curses.curs_set(0)
            except curses.error:
                pass
            return None
        elif ch in ("\b", "\x7f", curses.KEY_BACKSPACE, 127, 263):
            pwd = pwd[:-1]
        elif isinstance(ch, str) and ch.isprintable():
            pwd += ch

def main(stdscr):
    try:
        curses.curs_set(0)
    except curses.error:
        pass
    curses.use_default_colors()
    stdscr.timeout(150)

    muted_fg = 8 if curses.COLORS > 8 else 7
    curses.init_pair(1, 7, -1)
    curses.init_pair(2, 3, -1)
    curses.init_pair(3, muted_fg, -1)
    curses.init_pair(4, 2, -1)
    curses.init_pair(5, 1, -1)
    curses.init_pair(6, 0, 3)

    wifi_on = get_wifi_state()
    ip_addr = get_ip()
    networks = get_networks(rescan=False) if wifi_on else []
    idx = 0
    scroll = 0
    status_msg = "Prêt — [r] pour scanner les réseaux"
    status_col = 3

    while True:
        stdscr.erase()
        h, w = stdscr.getmaxyx()

        if h < 10 or w < 30:
            safe_addstr(stdscr, 0, 0, "Fenêtre trop petite...", curses.color_pair(2))
            stdscr.refresh()
            if stdscr.getch() in (ord('q'), 27):
                break
            continue

        stdscr.attron(curses.color_pair(3))
        try:
            stdscr.border()
        except curses.error:
            pass
        stdscr.attroff(curses.color_pair(3))

        safe_addstr(stdscr, 0, 2, " 󰤨  OMARCHY WI-FI ", curses.color_pair(2) | curses.A_BOLD)

        state_str = " [ ON ] " if wifi_on else " [ OFF ] "
        state_pair = curses.color_pair(4) if wifi_on else curses.color_pair(5)
        safe_addstr(stdscr, 0, max(2, w - len(state_str) - 3), state_str, state_pair | curses.A_BOLD)

        safe_addstr(stdscr, 1, 2, f"IP locale : {ip_addr}", curses.color_pair(3))
        try:
            stdscr.hline(2, 1, curses.ACS_HLINE | curses.color_pair(3), w - 2)
        except curses.error:
            pass

        list_h = max(1, h - 6)
        if not wifi_on:
            msg = "󰤮  Wi-Fi désactivé (appuie sur [t] pour l'activer)"
            safe_addstr(stdscr, h // 2, max(2, (w - len(msg)) // 2), msg, curses.color_pair(5) | curses.A_BOLD)
        elif not networks:
            msg = "Aucun réseau trouvé (appuie sur [r] pour scanner)"
            safe_addstr(stdscr, h // 2, max(2, (w - len(msg)) // 2), msg, curses.color_pair(3))
        else:
            idx = max(0, min(idx, len(networks) - 1))
            if idx < scroll:
                scroll = idx
            elif idx >= scroll + list_h:
                scroll = idx - list_h + 1

            for i, net in enumerate(networks[scroll:scroll + list_h]):
                real_i = scroll + i
                y = 3 + i
                is_sel = (real_i == idx)

                icon = sig_icon(net["signal"])
                lock = "" if net["security"] != "Ouvert" else ""
                tag = "● Connecté" if net["in_use"] else ("✓ Enregistré" if net["saved"] else "")
                right_info = f"{tag}  {net['signal']:3d}% "
                max_ssid = max(6, w - len(right_info) - 12)
                ssid_disp = net["ssid"][:max_ssid]

                line_str = f" {icon}  {lock}  {ssid_disp:<{max_ssid}} {right_info}"
                line_str = line_str.ljust(max(1, w - 2))

                if is_sel:
                    safe_addstr(stdscr, y, 1, line_str, curses.color_pair(6) | curses.A_BOLD)
                elif net["in_use"]:
                    safe_addstr(stdscr, y, 1, line_str, curses.color_pair(2) | curses.A_BOLD)
                elif net["saved"]:
                    safe_addstr(stdscr, y, 1, line_str, curses.color_pair(1))
                else:
                    safe_addstr(stdscr, y, 1, line_str, curses.color_pair(3))

        try:
            stdscr.hline(h - 3, 1, curses.ACS_HLINE | curses.color_pair(3), w - 2)
        except curses.error:
            pass
        safe_addstr(stdscr, h - 2, 2, status_msg, curses.color_pair(status_col))
        help_bar = " [Entrée] Connecter  [d] Déconnecter  [r] Scanner  [t] On/Off  [x] Oublier  [q] Quitter "
        safe_addstr(stdscr, h - 1, 2, help_bar, curses.color_pair(2))

        stdscr.refresh()

        ch = stdscr.getch()
        if ch == -1:
            continue
        elif ch == curses.KEY_RESIZE:
            curses.update_lines_cols()
            continue
        elif ch in (ord('q'), 27):
            break
        elif ch in (ord('j'), curses.KEY_DOWN):
            if networks:
                idx = (idx + 1) % len(networks)
        elif ch in (ord('k'), curses.KEY_UP):
            if networks:
                idx = (idx - 1) % len(networks)
        elif ch == ord('t'):
            target = "off" if wifi_on else "on"
            status_msg = f"Basculement du Wi-Fi sur {target.upper()}..."
            status_col = 2
            safe_addstr(stdscr, h - 2, 2, status_msg.ljust(max(1, w - 4)), curses.color_pair(status_col))
            stdscr.refresh()
            run(["nmcli", "radio", "wifi", target])
            wifi_on = get_wifi_state()
            networks = get_networks(rescan=False) if wifi_on else []
            ip_addr = get_ip()
            status_msg = f"Wi-Fi {'activé' if wifi_on else 'désactivé'}."
            status_col = 4 if wifi_on else 5
        elif ch == ord('r') and wifi_on:
            status_msg = "Scan des réseaux Wi-Fi en cours..."
            status_col = 2
            safe_addstr(stdscr, h - 2, 2, status_msg.ljust(max(1, w - 4)), curses.color_pair(status_col))
            stdscr.refresh()
            networks = get_networks(rescan=True)
            ip_addr = get_ip()
            status_msg = f"{len(networks)} réseaux détectés."
            status_col = 4
        elif ch == ord('d') and wifi_on and networks:
            sel = networks[idx]
            if sel["in_use"]:
                status_msg = f"Déconnexion de {sel['ssid']}..."
                status_col = 2
                safe_addstr(stdscr, h - 2, 2, status_msg.ljust(max(1, w - 4)), curses.color_pair(status_col))
                stdscr.refresh()
                run(["nmcli", "connection", "down", "id", sel["ssid"]])
                networks = get_networks(rescan=False)
                ip_addr = get_ip()
                status_msg = f"Déconnecté de {sel['ssid']}."
                status_col = 3
        elif ch == ord('x') and wifi_on and networks:
            sel = networks[idx]
            if sel["saved"]:
                run(["nmcli", "connection", "delete", "id", sel["ssid"]])
                networks = get_networks(rescan=False)
                ip_addr = get_ip()
                status_msg = f"Profil {sel['ssid']} oublié."
                status_col = 5
        elif ch in (10, 13, curses.KEY_ENTER) and wifi_on and networks:
            sel = networks[idx]
            ssid = sel["ssid"]
            if sel["in_use"]:
                status_msg = f"Déjà connecté à {ssid}."
                status_col = 4
                continue

            if sel["saved"] or sel["security"] == "Ouvert":
                status_msg = f"Connexion à {ssid} en cours..."
                status_col = 2
                safe_addstr(stdscr, h - 2, 2, status_msg.ljust(max(1, w - 4)), curses.color_pair(status_col))
                stdscr.refresh()
                code, _, err = run(["nmcli", "dev", "wifi", "connect", ssid])
            else:
                pwd = prompt_password(stdscr, ssid)
                if pwd is None:
                    status_msg = "Connexion annulée."
                    status_col = 3
                    continue
                status_msg = f"Authentification sur {ssid}..."
                status_col = 2
                safe_addstr(stdscr, h - 2, 2, status_msg.ljust(max(1, w - 4)), curses.color_pair(status_col))
                stdscr.refresh()
                code, _, err = run(["nmcli", "dev", "wifi", "connect", ssid, "password", pwd])

            networks = get_networks(rescan=False)
            ip_addr = get_ip()
            if code == 0:
                status_msg = f"Connecté à {ssid} ({ip_addr})"
                status_col = 4
            else:
                status_msg = f"Échec : {err.splitlines()[-1] if err else 'Mot de passe ou signal invalide'}"
                status_col = 5

if __name__ == "__main__":
    try:
        curses.wrapper(main)
    except KeyboardInterrupt:
        pass
    finally:
        cleanup_pid()
