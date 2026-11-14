pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Agenda iCal (Google Agenda via son "adresse secrète au format iCal", ou tout autre .ics)
//   configuration : ~/.config/quickshell/ical.conf   (voir scripts/ical-fetch.py)
//   cache         : ~/.cache/quickshell/agenda.json  (affiché tout de suite au démarrage)
//   rafraîchi toutes les 15 min, et à l'ouverture du calendrier si le cache a plus de 5 min
//   qs ipc call agenda refresh | today
// Le script n'est lancé que si ical.conf existe.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string confPath: home + "/.config/quickshell/ical.conf"
    readonly property string cachePath: home + "/.cache/quickshell/agenda.json"
    readonly property string script: home + "/.config/quickshell/scripts/ical-fetch.py"

    property bool configured: false
    property var events: []
    property var calendars: []
    property string error: ""
    property real lastFetch: 0

    // "YYYY-MM-DD" (heure locale)
    function dayKey(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    // Index jour -> événements (les événements sur plusieurs jours apparaissent chaque jour)
    readonly property var byDay: {
        let map = {};
        for (let i = 0; i < root.events.length; i++) {
            let ev = root.events[i];
            let s = new Date(ev.allDay ? ev.start + "T00:00:00" : ev.start);
            let e = new Date(ev.allDay ? ev.end + "T00:00:00" : ev.end);
            if (isNaN(s.getTime())) continue;
            if (isNaN(e.getTime()) || e <= s) e = new Date(s.getTime() + (ev.allDay ? 86400000 : 1));
            let d = new Date(s.getFullYear(), s.getMonth(), s.getDate());
            for (let n = 0; n < 62 && d < e; n++) {
                let k = root.dayKey(d);
                if (!map[k]) map[k] = [];
                map[k].push(ev);
                d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1);
            }
        }
        return map;
    }

    function eventsOn(d) {
        return root.byDay[root.dayKey(d)] || [];
    }

    function hasEvents(d) {
        return root.byDay[root.dayKey(d)] !== undefined;
    }

    // "09:00–10:30" ou "all day"
    function timeRange(ev, day) {
        if (ev.allDay) return "all day";
        let s = new Date(ev.start), e = new Date(ev.end);
        let fmt = t => String(t.getHours()).padStart(2, "0") + ":" + String(t.getMinutes()).padStart(2, "0");
        let k = root.dayKey(day);
        let sTxt = root.dayKey(s) === k ? fmt(s) : "…";
        let eTxt = root.dayKey(e) === k ? fmt(e) : "…";
        return sTxt + "–" + eTxt;
    }

    // =====================================================================
    // Création d'événement : ouvre le formulaire Google Agenda pré-rempli
    // (aucun accès en écriture stocké ici ; on valide d'un clic dans le navigateur)
    // =====================================================================

    // Créneau saisi pour le jour `day` :
    //   ""  /  "all day"            -> journée entière
    //   "14"  "14h"  "14:30"        -> 1 h à partir de cette heure
    //   "14-16"  "14h-15h30"  "9:00-10:15"
    //   "14h+30m"  "9:00+2h"        -> durée
    // Renvoie { allDay, start, end } ou null si invalide.
    function parseSlot(str, day) {
        let s = (str || "").trim().toLowerCase().replace(/\s+/g, "");
        let base = new Date(day.getFullYear(), day.getMonth(), day.getDate());
        if (s === "" || s === "allday" || s === "journée" || s === "journee") {
            return { allDay: true, start: base, end: new Date(base.getFullYear(), base.getMonth(), base.getDate() + 1) };
        }
        let m = /^(\d{1,2})(?:[:h](\d{2})?)?(?:-(\d{1,2})(?:[:h](\d{2})?)?|\+(\d+)(h|m|min))?$/.exec(s);
        if (!m) return null;
        let h1 = parseInt(m[1]), mi1 = parseInt(m[2] || "0");
        if (h1 > 23 || mi1 > 59) return null;
        let start = new Date(base);
        start.setHours(h1, mi1, 0, 0);
        let end;
        if (m[3] !== undefined) {
            let h2 = parseInt(m[3]), mi2 = parseInt(m[4] || "0");
            if (h2 > 24 || mi2 > 59) return null;
            end = new Date(base);
            end.setHours(h2, mi2, 0, 0);
            if (end <= start) end.setDate(end.getDate() + 1);   // ex. 23h-1h
        } else if (m[5] !== undefined) {
            let n = parseInt(m[5]);
            end = new Date(start.getTime() + n * (m[6] === "h" ? 3600000 : 60000));
        } else {
            end = new Date(start.getTime() + 3600000);
        }
        if (end <= start) return null;
        return { allDay: false, start: start, end: end };
    }

    function slotLabel(slot) {
        if (!slot) return "";
        let days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        let d = slot.start;
        let head = days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()];
        if (slot.allDay) return head + " · all day";
        let fmt = t => String(t.getHours()).padStart(2, "0") + ":" + String(t.getMinutes()).padStart(2, "0");
        return head + " · " + fmt(slot.start) + "–" + fmt(slot.end);
    }

    // "titre @ lieu" -> { title, location }
    function splitTitle(text) {
        let t = (text || "").trim();
        let i = t.lastIndexOf(" @ ");
        if (i < 0) return { title: t, location: "" };
        return { title: t.substring(0, i).trim(), location: t.substring(i + 3).trim() };
    }

    function createUrl(text, when, day) {
        let parts = root.splitTitle(text);
        let slot = root.parseSlot(when, day);
        if (parts.title === "" || !slot) return "";
        let p2 = n => String(n).padStart(2, "0");
        let localDate = d => d.getFullYear() + p2(d.getMonth() + 1) + p2(d.getDate());
        let utc = d => d.getUTCFullYear() + p2(d.getUTCMonth() + 1) + p2(d.getUTCDate())
                       + "T" + p2(d.getUTCHours()) + p2(d.getUTCMinutes()) + "00Z";
        let dates = slot.allDay ? (localDate(slot.start) + "/" + localDate(slot.end))
                                : (utc(slot.start) + "/" + utc(slot.end));
        return "https://calendar.google.com/calendar/render?action=TEMPLATE"
             + "&text=" + encodeURIComponent(parts.title)
             + "&dates=" + dates
             + (parts.location !== "" ? "&location=" + encodeURIComponent(parts.location) : "");
    }

    // Renvoie "" si OK, sinon un message d'erreur
    function openCreate(text, when, day) {
        if (root.splitTitle(text).title === "") return "title required";
        if (!root.parseSlot(when, day)) return "invalid time: 14:00 · 14-16 · 9h+30m · empty = all day";
        opener.command = ["xdg-open", root.createUrl(text, when, day)];
        opener.startDetached();
        // L'événement apparaîtra au prochain téléchargement : forcer le rafraîchissement
        root.lastFetch = 0;
        refreshSoon.restart();
        return "";
    }

    Process { id: opener }

    Timer {
        id: refreshSoon
        interval: 90000
        onTriggered: root.refresh()
    }

    function applyJson(raw) {
        try {
            let d = JSON.parse(raw);
            root.events = d.events || [];
            root.calendars = d.calendars || [];
            let errs = (d.calendars || []).filter(c => !c.ok).map(c => c.name);
            root.error = d.error ? d.error : (errs.length > 0 ? ("unreachable: " + errs.join(", ")) : "");
        } catch (e) {}
    }

    // Relit la config (création / modification de ical.conf) puis télécharge
    function refresh() {
        root.wantFetch = true;
        confView.reload();
    }
    property bool wantFetch: false

    function startFetch() {
        root.wantFetch = false;
        if (root.configured && !fetcher.running) fetcher.running = true;
    }

    // À l'ouverture du calendrier : relire le cache (ex. script lancé à la main), puis
    // re-télécharger si le dernier téléchargement a plus de 5 min
    function refreshIfStale() {
        cacheView.reload();
        if (Date.now() - root.lastFetch > 5 * 60 * 1000) root.refresh();
        else confView.reload();
    }

    // Présence de la configuration
    FileView {
        id: confView
        path: root.confPath
        printErrors: false
        onLoaded: {
            let hasUrl = text().split("\n").some(l => l.trim() !== "" && !l.trim().startsWith("#"));
            let was = root.configured;
            root.configured = hasUrl;
            if (hasUrl && (!was || root.wantFetch)) root.startFetch();
        }
        onLoadFailed: err => {
            root.configured = false;
            root.wantFetch = false;
        }
    }

    // Un fichier qui n'existe pas encore ne peut pas être surveillé : on relit la config
    // toutes les 30 s (lecture d'un petit fichier, aucun processus lancé)
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: confView.reload()
    }

    // Dernier résultat connu (affiché immédiatement, même hors ligne)
    FileView {
        id: cacheView
        path: root.cachePath
        printErrors: false
        onLoaded: root.applyJson(text())
    }

    Process {
        id: fetcher
        command: [root.home + "/.local/bin/uv", "run", "--quiet", "--script", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") root.applyJson(text);
                root.lastFetch = Date.now();
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: root.configured
        repeat: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "agenda"

        function refresh(): void { root.refresh(); }
        // Test : URL générée sans rien ouvrir (date au format AAAA-MM-JJ)
        function newEventUrl(text: string, when: string, date: string): string {
            let p = date.split("-");
            let day = new Date(parseInt(p[0]), parseInt(p[1]) - 1, parseInt(p[2]));
            let slot = root.parseSlot(when, day);
            return root.slotLabel(slot) + "\n" + root.createUrl(text, when, day);
        }
        function today(): string {
            let list = root.eventsOn(new Date());
            return list.map(ev => root.timeRange(ev, new Date()) + "  " + ev.title).join("\n");
        }
    }
}
