#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["icalendar>=6", "recurring-ical-events>=3"]
# ///
"""Agenda iCal pour Quickshell (core/Agenda.qml).

Lit les calendriers listés dans ~/.config/quickshell/ical.conf, une ligne par calendrier :
    perso = https://calendar.google.com/calendar/ical/.../basic.ics
    https://exemple.org/autre.ics          (sans nom : "calendar")
Les lignes vides et celles qui commencent par # sont ignorées. Un chemin local fonctionne aussi.

Écrit ~/.cache/quickshell/agenda.json (droits 600) et l'affiche sur stdout.
Les événements récurrents sont dépliés sur la fenêtre [aujourd'hui - 7 j, aujourd'hui + 90 j].
En cas d'échec réseau, les événements du dernier cache sont conservés pour ce calendrier.
"""
import datetime as dt
import json
import os
import pathlib
import sys
import tempfile
import urllib.request

import icalendar
import recurring_ical_events

HOME = pathlib.Path.home()
# Surchargeables pour les tests : QS_ICAL_CONF, QS_AGENDA_CACHE
CONF = pathlib.Path(os.environ.get("QS_ICAL_CONF", HOME / ".config/quickshell/ical.conf"))
CACHE = pathlib.Path(os.environ.get("QS_AGENDA_CACHE", HOME / ".cache/quickshell/agenda.json"))
PAST_DAYS, FUTURE_DAYS = 7, 90


def read_conf():
    cals = []
    if not CONF.exists():
        return None
    for raw in CONF.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line and not line.split("=", 1)[0].strip().startswith(("http", "/", "webcal")):
            name, url = (p.strip() for p in line.split("=", 1))
        else:
            name, url = "calendar", line
        if url.startswith("webcal://"):
            url = "https://" + url[len("webcal://"):]
        cals.append((name or "calendar", url))
    return cals


def fetch(url):
    if url.startswith(("http://", "https://")):
        req = urllib.request.Request(url, headers={"User-Agent": "quickshell-agenda/1.0"})
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.read()
    return pathlib.Path(os.path.expanduser(url.removeprefix("file://"))).read_bytes()


def to_local(value):
    """date -> (iso date, True) ; datetime -> (iso datetime local, False)"""
    if isinstance(value, dt.datetime):
        if value.tzinfo is None:          # heure "flottante" : heure locale
            value = value.astimezone()
        return value.astimezone().isoformat(timespec="minutes"), False
    return value.isoformat(), True


def expand(name, data, start, end):
    cal = icalendar.Calendar.from_ical(data)
    out = []
    for ev in recurring_ical_events.of(cal).between(start, end):
        if str(ev.get("STATUS", "")).upper() == "CANCELLED":
            continue
        dtstart = ev.get("DTSTART")
        if dtstart is None:
            continue
        s = dtstart.dt
        if ev.get("DTEND") is not None:
            e = ev.get("DTEND").dt
        elif ev.get("DURATION") is not None:
            e = s + ev.get("DURATION").dt
        else:
            e = s + (dt.timedelta(days=1) if not isinstance(s, dt.datetime) else dt.timedelta(0))
        s_iso, all_day = to_local(s)
        e_iso, _ = to_local(e)
        out.append({
            "title": str(ev.get("SUMMARY", "(no title)")).strip() or "(no title)",
            "start": s_iso,
            "end": e_iso,              # exclusif pour les journées entières (norme iCal)
            "allDay": all_day,
            "location": str(ev.get("LOCATION", "")).strip(),
            "calendar": name,
        })
    return out


def load_cache():
    try:
        return json.loads(CACHE.read_text())
    except Exception:
        return {}


def write_cache(obj):
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=CACHE.parent, prefix=".agenda-")
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, CACHE)


def main():
    cals = read_conf()
    if not cals:
        print(json.dumps({"configured": False, "events": [], "calendars": []}))
        return

    today = dt.date.today()
    start = today - dt.timedelta(days=PAST_DAYS)
    end = today + dt.timedelta(days=FUTURE_DAYS)
    previous = load_cache()
    events, status = [], []

    for name, url in cals:
        try:
            events += expand(name, fetch(url), start, end)
            status.append({"name": name, "ok": True, "error": ""})
        except Exception as exc:  # réseau, URL invalide, ICS corrompu…
            kept = [e for e in previous.get("events", []) if e.get("calendar") == name]
            events += kept
            status.append({"name": name, "ok": False, "error": type(exc).__name__ + ": " + str(exc)[:120]})

    events.sort(key=lambda e: (e["start"][:10], not e["allDay"], e["start"]))
    result = {
        "configured": True,
        "updated": dt.datetime.now().astimezone().isoformat(timespec="minutes"),
        "calendars": status,
        "events": events,
    }
    write_cache(result)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(json.dumps({"configured": True, "events": [], "calendars": [],
                          "error": type(exc).__name__ + ": " + str(exc)[:200]}))
        sys.exit(1)
