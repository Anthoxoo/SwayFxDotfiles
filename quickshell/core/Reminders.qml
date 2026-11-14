pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Rappels : un texte + une échéance, puis une notification au bon moment.
// Persistés dans ~/.local/state/quickshell/reminders.json (survivent aux redémarrages
// de Quickshell ; un rappel échu pendant que Quickshell était arrêté part au démarrage).
//   qs ipc call reminders add "10m" "sortir le linge" | list | clear
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/quickshell"

    property var items: []            // [{ id, text, due (ms epoch) }], triés par échéance
    property bool loaded: false
    property real now: Date.now()     // horloge pour les comptes à rebours affichés

    readonly property int count: items.length
    readonly property string tooltipHtml: {
        if (items.length === 0) return "";
        let lines = [Theme.tipTitle("\u{F009A}  reminders (" + items.length + ")")];
        for (let i = 0; i < Math.min(items.length, 6); i++) {
            lines.push(Theme.tipRow(root.clockOf(items[i].due), items[i].text, 7));
        }
        return Theme.tipBlock(lines);
    }

    // --- Analyse de l'échéance -------------------------------------------------
    //   durée :  "10" (minutes)  "10m"  "45s"  "2h"  "1h30"  "1h30m"  "1d2h"
    //   heure :  "17:45"  -> aujourd'hui à 17:45 (demain si déjà passée)
    // Renvoie un timestamp en ms, ou -1 si invalide.
    function parseWhen(str) {
        let s = (str || "").trim().toLowerCase().replace(/\s+/g, "");
        if (s === "") return -1;
        let m;

        if ((m = /^(\d{1,2}):(\d{2})$/.exec(s))) {
            let h = parseInt(m[1]), mi = parseInt(m[2]);
            if (h > 23 || mi > 59) return -1;
            let d = new Date();
            d.setHours(h, mi, 0, 0);
            if (d.getTime() <= Date.now()) d.setDate(d.getDate() + 1);
            return d.getTime();
        }

        let secs = -1;
        if (/^\d+$/.test(s)) {
            secs = parseInt(s) * 60;
        } else if ((m = /^(\d+)h(\d+)$/.exec(s))) {
            secs = parseInt(m[1]) * 3600 + parseInt(m[2]) * 60;
        } else if ((m = /^(?:(\d+)d)?(?:(\d+)h)?(?:(\d+)(?:min|m))?(?:(\d+)s)?$/.exec(s))) {
            secs = parseInt(m[1] || 0) * 86400 + parseInt(m[2] || 0) * 3600
                 + parseInt(m[3] || 0) * 60 + parseInt(m[4] || 0);
        }
        if (secs <= 0) return -1;
        return Date.now() + secs * 1000;
    }

    function clockOf(ms) {
        let d = new Date(ms);
        let t = String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
        let today = new Date();
        if (d.toDateString() !== today.toDateString()) {
            let days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
            t = days[d.getDay()] + " " + t;
        }
        return t;
    }

    function remaining(ms) {
        let s = Math.max(0, Math.round((ms - root.now) / 1000));
        if (s < 60) return s + "s";
        let m = Math.floor(s / 60);
        if (m < 60) return m + "m";
        let h = Math.floor(m / 60);
        if (h < 24) return h + "h" + String(m % 60).padStart(2, "0");
        return Math.floor(h / 24) + "d" + (h % 24) + "h";
    }

    // --- Actions -----------------------------------------------------------------
    // Renvoie "" si OK, sinon un message d'erreur
    function add(text, when) {
        let t = (text || "").trim();
        if (t === "") return "empty reminder";
        let due = root.parseWhen(when);
        if (due < 0) return "invalid time: try 10m, 1h30, 17:45";
        let list = root.items.slice();
        list.push({ id: Date.now() + "-" + Math.floor(Math.random() * 1e6), text: t, due: due });
        list.sort((a, b) => a.due - b.due);
        root.items = list;
        root.save();
        root.notify("normal", "\u{F009A}  reminder set · " + root.clockOf(due), t);
        return "";
    }

    function remove(id) {
        root.items = root.items.filter(r => r.id !== id);
        root.save();
    }

    function clear() {
        let n = root.items.length;
        root.items = [];
        root.save();
        if (n > 0) root.notify("low", "\u{F009A}  reminders cleared", n + " removed");
    }

    function save() {
        store.setText(JSON.stringify(root.items));
    }

    function notify(urgency, summary, body) {
        notifier.command = ["notify-send", "-a", "reminder", "-u", urgency, summary, body];
        notifier.startDetached();
    }

    function fire(r, late) {
        root.notify("critical", "\u{F009A}  reminder" + (late ? " (late)" : ""), r.text);
    }

    function checkDue() {
        if (!root.loaded || root.items.length === 0) return;
        let t = Date.now();
        let due = root.items.filter(r => r.due <= t);
        if (due.length === 0) return;
        for (let i = 0; i < due.length; i++) root.fire(due[i], t - due[i].due > 60000);
        root.items = root.items.filter(r => r.due > t);
        root.save();
    }

    Process { id: notifier }

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
    }

    FileView {
        id: store
        path: root.stateDir + "/reminders.json"
        printErrors: false
        onLoaded: {
            try {
                let v = JSON.parse(text());
                root.items = Array.isArray(v) ? v.sort((a, b) => a.due - b.due) : [];
            } catch (e) {
                root.items = [];
            }
            root.loaded = true;
            root.checkDue();
        }
        onLoadFailed: err => {
            root.loaded = true;
        }
    }

    Timer {
        interval: 1000
        running: root.loaded && root.items.length > 0
        repeat: true
        onTriggered: {
            root.now = Date.now();
            root.checkDue();
        }
    }

    IpcHandler {
        target: "reminders"

        function add(when: string, text: string): string {
            let err = root.add(text, when);
            return err === "" ? "ok" : err;
        }
        function list(): string {
            return root.items.map(r => root.clockOf(r.due) + "  " + r.text).join("\n");
        }
        function clear(): void { root.clear(); }
    }
}
