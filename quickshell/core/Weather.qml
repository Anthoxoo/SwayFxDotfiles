pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Météo via wttr.in (JSON, sans clé d'API). Rafraîchie toutes les 30 min.
// Les icônes sont écrites en échappements \u{...} (glyphes Nerd Font).
Singleton {
    id: root

    // Vide = localisation automatique par IP. Sinon une ville, ex. "Toulouse".
    property string location: ""

    property bool ready: false
    property string temp: ""
    property string feels: ""
    property string desc: ""
    property string icon: "\u{F0590}"
    property string humidity: ""
    property string wind: ""
    property string area: ""
    property var days: []          // [{ label, min, max, icon, desc }]
    property string updated: ""

    readonly property string barText: ready ? (icon + " " + temp + "°") : ""

    // Codes météo wttr.in (WWO) -> icône
    function iconFor(code, night) {
        let c = parseInt(code);
        if (c === 113) return night ? "\u{F0594}" : "\u{F0599}";                 // clair
        if (c === 116) return night ? "\u{F0F31}" : "\u{F0595}";                 // partiellement nuageux
        if (c === 119 || c === 122) return "\u{F0590}";                          // nuageux / couvert
        if ([143, 248, 260].includes(c)) return "\u{F0591}";                     // brouillard
        if ([200, 386, 389, 392, 395].includes(c)) return "\u{F0593}";           // orage
        if ([179, 182, 185, 227, 230, 317, 320, 323, 326, 329, 332, 335, 338,
             350, 362, 365, 368, 371, 374, 377].includes(c)) return "\u{F0598}"; // neige / grésil
        if ([299, 302, 305, 308, 356, 359].includes(c)) return "\u{F0596}";      // forte pluie
        return "\u{F0597}";                                                      // pluie / bruine
    }

    // "07:47 AM" -> minutes depuis minuit
    function parseClock(s) {
        let m = /(\d+):(\d+)\s*(AM|PM)/i.exec(s || "");
        if (!m) return -1;
        let h = parseInt(m[1]) % 12;
        if (m[3].toUpperCase() === "PM") h += 12;
        return h * 60 + parseInt(m[2]);
    }

    function refresh() {
        if (!fetcher.running) fetcher.running = true;
    }

    Process {
        id: fetcher
        command: ["curl", "-sf", "--max-time", "15",
                  "https://wttr.in/" + encodeURIComponent(root.location) + "?format=j1"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(text);
                    let cur = d.current_condition[0];
                    let now = new Date();
                    let mins = now.getHours() * 60 + now.getMinutes();
                    let astro = d.weather[0].astronomy[0];
                    let rise = root.parseClock(astro.sunrise);
                    let set = root.parseClock(astro.sunset);
                    let night = rise >= 0 && set >= 0 && (mins < rise || mins > set);

                    root.temp = cur.temp_C;
                    root.feels = cur.FeelsLikeC;
                    root.desc = (cur.weatherDesc[0].value || "").toLowerCase();
                    root.icon = root.iconFor(cur.weatherCode, night);
                    root.humidity = cur.humidity;
                    root.wind = cur.windspeedKmph;
                    root.area = (d.nearest_area && d.nearest_area[0]) ? d.nearest_area[0].areaName[0].value.toLowerCase() : "";

                    let labels = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
                    let out = [];
                    for (let i = 0; i < d.weather.length; i++) {
                        let w = d.weather[i];
                        let midday = w.hourly[Math.min(4, w.hourly.length - 1)];  // 12:00
                        let dt = new Date(w.date + "T12:00:00");
                        out.push({
                            label: i === 0 ? "today" : labels[dt.getDay()],
                            min: w.mintempC,
                            max: w.maxtempC,
                            icon: root.iconFor(midday.weatherCode, false),
                            desc: (midday.weatherDesc[0].value || "").toLowerCase()
                        });
                    }
                    root.days = out;
                    root.updated = String(now.getHours()).padStart(2, "0") + ":" + String(now.getMinutes()).padStart(2, "0");
                    root.ready = true;
                    pollTimer.interval = 30 * 60 * 1000;
                } catch (e) {
                    pollTimer.interval = 5 * 60 * 1000;   // réessayer plus tôt
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) pollTimer.interval = 5 * 60 * 1000;
        }
    }

    Timer {
        id: pollTimer
        interval: 30 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    onLocationChanged: refresh()
}
