pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string activeWindowTitle: ""
    property string swayMode: ""
    property string wifiIcon: "󰤨"
    property string wifiSsid: ""
    property bool wifiConnected: true
    property bool wifiCompact: true
    property string wifiTooltipHtml: ""
    property string btText: ""
    property bool btCompact: true
    property string btTooltipHtml: ""

    // Luminosité (icône graphique seule dans la barre, détails au survol)
    property int brightValue: 100
    property string backlightText: "󰪥"
    property string brightTooltipHtml: ""
    property bool brightnessMenuOpen: false
    property bool nightLightOn: false
    property int nightLightTemp: 4500
    property bool osdVisible: false

    // OmaPods (AirPods)
    property bool podsMenuOpen: false
    property bool podsHideWhenDisconnected: false
    property var podsState: ({ running: false, connected: false, barPct: -1, modes: [] })
    property string podsTooltipHtml: "<span style='color:#888888;'>󱡏  disconnected</span>"

    // Audio
    property string audioText: "󰕾 0%"
    property bool audioMuted: false
    property string audioTooltipHtml: ""

    // Batterie (conservée telle quelle)
    property string batText: " 100%"
    property string batState: "normal"
    property string batTooltipHtml: ""

    property string calTooltipHtml: ""
    property bool clockAlt: false
    property bool calendarMenuOpen: false
    property bool powerMenuOpen: false
    property bool launcherOpen: false
    property bool dndMode: false
    property var appList: []

    signal clearNotificationsRequested()

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/scripts"

    Process {
        id: cmdRunner
    }

    function runCmd(cmd) {
        cmdRunner.command = ["sh", "-c", cmd];
        cmdRunner.startDetached();
    }

    function podsCmd(arg) {
        runCmd("python3 " + root.scriptsDir + "/omapods-ctl.py '" + arg + "'");
        statusPoller.running = true;
    }

    function podsSetMode(m) {
        let copy = Object.assign({}, root.podsState);
        copy.mode = m;
        root.podsState = copy;
        podsCmd("noise:" + m);
    }

    function podsToggleCa() {
        let nextVal = !(root.podsState && root.podsState.ca);
        let copy = Object.assign({}, root.podsState);
        copy.ca = nextVal;
        root.podsState = copy;
        podsCmd("ca:" + (nextVal ? "on" : "off"));
    }

    function podsToggleOneBud() {
        let nextVal = !(root.podsState && root.podsState.oneBud);
        let copy = Object.assign({}, root.podsState);
        copy.oneBud = nextVal;
        root.podsState = copy;
        podsCmd("onebud:" + (nextVal ? "on" : "off"));
    }

    function podsSetAdaptive(val) {
        let copy = Object.assign({}, root.podsState);
        copy.adaptiveLevel = val;
        root.podsState = copy;
        podsCmd("adaptive:" + val);
    }

    function podsCycleEar() {
        let order = ["one", "both", "off"];
        let cur = (root.podsState && root.podsState.ear) ? root.podsState.ear : "one";
        let idx = (order.indexOf(cur) + 1) % order.length;
        let nextEar = order[idx];
        let copy = Object.assign({}, root.podsState);
        copy.ear = nextEar;
        root.podsState = copy;
        podsCmd("ear:" + nextEar);
    }

    function updateBrightLabel(val) {
        let b = Math.max(1, Math.min(100, val));
        root.brightValue = b;
        let bIcons = ["󰄰", "󰪞", "󰪟", "󰪠", "󰪡", "󰪢", "󰪣", "󰪤", "󰪥"];
        let bIdx = Math.min(8, Math.max(0, Math.floor(b / 12)));
        let icon = root.nightLightOn ? "󰖔" : bIcons[bIdx];
        root.backlightText = icon;
        let nlStr = root.nightLightOn ? (root.nightLightTemp + "K") : "off";
        root.brightTooltipHtml = "<tt>"
            + "<span style='color:#ff8800;'>" + icon + "  display</span><br>"
            + "<span style='color:#888888;'>brightness </span><span style='color:#e5e5e5;'>" + b + "%</span><br>"
            + "<span style='color:#888888;'>night      </span><span style='color:#e5e5e5;'>" + nlStr + "</span>"
            + "</tt>";
    }

    function setBrightness(val, showOsdPopup) {
        let clamped = Math.max(1, Math.min(100, Math.round(val)));
        updateBrightLabel(clamped);
        if (showOsdPopup) triggerOsd();
        brightApplyTimer.targetVal = clamped;
        brightApplyTimer.restart();
    }

    function stepBrightness(delta) {
        setBrightness(root.brightValue + delta, true);
    }

    function toggleNightLight() {
        root.nightLightOn = !root.nightLightOn;
        updateBrightLabel(root.brightValue);
        if (root.nightLightOn) {
            runCmd(root.scriptsDir + "/brightness.sh night-on " + root.nightLightTemp);
        } else {
            runCmd(root.scriptsDir + "/brightness.sh night-off");
        }
    }

    function setNightTemp(temp) {
        root.nightLightTemp = temp;
        root.nightLightOn = true;
        updateBrightLabel(root.brightValue);
        runCmd(root.scriptsDir + "/brightness.sh night-on " + temp);
    }

    function triggerOsd() {
        if (!root.brightnessMenuOpen) {
            root.osdVisible = true;
            osdTimer.restart();
        }
    }

    Timer {
        id: brightApplyTimer
        property int targetVal: 100
        interval: 25
        repeat: false
        onTriggered: {
            root.runCmd("brightnessctl -c backlight set " + targetVal + "% -q");
        }
    }

    Timer {
        id: osdTimer
        interval: 1200
        repeat: false
        onTriggered: root.osdVisible = false
    }

    function launchApp(appId, execCmd, isTerm) {
        cmdRunner.command = ["python3", root.scriptsDir + "/launch-app.py", appId, execCmd, isTerm ? "true" : "false"];
        cmdRunner.startDetached();
        reloadAppsTimer.restart();
    }

    function refresh() {
        statusPoller.running = true;
    }

    function refreshApps() {
        appsPoller.running = true;
    }

    Timer {
        id: reloadAppsTimer
        interval: 600
        repeat: false
        onTriggered: appsPoller.running = true
    }

    Process {
        id: appsPoller
        running: true
        command: ["python3", root.scriptsDir + "/apps.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.appList = JSON.parse(data.trim());
                } catch (e) {}
            }
        }
    }

    Process {
        id: ipcServer
        running: true
        command: ["python3", "-u", "-c", "import os; p='/tmp/quickshell-ipc.fifo';\ntry: os.unlink(p)\nexcept: pass\nos.mkfifo(p)\nfd=os.open(p, os.O_RDWR)\nwith os.fdopen(fd, 'r') as f:\n    for line in f:\n        print(line.strip(), flush=True)"]
        stdout: SplitParser {
            onRead: data => {
                let cmd = data.trim();
                if (cmd === "toggle-launcher") {
                    root.powerMenuOpen = false;
                    root.calendarMenuOpen = false;
                    root.brightnessMenuOpen = false;
                    root.podsMenuOpen = false;
                    root.launcherOpen = !root.launcherOpen;
                } else if (cmd === "close-launcher") {
                    root.launcherOpen = false;
                } else if (cmd === "toggle-power") {
                    root.launcherOpen = false;
                    root.brightnessMenuOpen = false;
                    root.podsMenuOpen = false;
                    root.powerMenuOpen = !root.powerMenuOpen;
                } else if (cmd === "toggle-brightness") {
                    root.launcherOpen = false;
                    root.powerMenuOpen = false;
                    root.podsMenuOpen = false;
                    root.brightnessMenuOpen = !root.brightnessMenuOpen;
                } else if (cmd === "toggle-pods") {
                    root.launcherOpen = false;
                    root.powerMenuOpen = false;
                    root.calendarMenuOpen = false;
                    root.brightnessMenuOpen = false;
                    root.podsMenuOpen = !root.podsMenuOpen;
                } else if (cmd === "clear-notifs") {
                    root.clearNotificationsRequested();
                } else if (cmd === "toggle-dnd") {
                    root.dndMode = !root.dndMode;
                } else if (cmd.startsWith("osd-bright:")) {
                    let v = parseInt(cmd.split(":")[1]);
                    if (!isNaN(v)) {
                        root.updateBrightLabel(v);
                        root.triggerOsd();
                    }
                } else if (cmd === "refresh") {
                    statusPoller.running = true;
                }
            }
        }
    }

    function formatWindow(appId, title) {
        if (!appId && !title) return "";
        let raw = (appId || "") + ">>>" + (title || "");
        let m;

        if ((m = raw.match(/.*>>>(.+?)(?: — | - | \| | : ).*Firefox.*/))) return "󰈹  Firefox — " + m[1];
        if (/.*>>>(?:Mozilla )?Firefox.*/.test(raw)) return "󰈹  Firefox";

        if (/.*[Zz]ed.*>>>Zed$/.test(raw)) return "ζ Zed";
        if ((m = raw.match(/.*[Zz]ed.*>>>(.*)/))) return "ζ  Zed — " + m[1];

        if ((m = raw.match(/.*>>>n?vim .*\/([^\/]+)$/))) return "  Neovim — " + m[1];
        if ((m = raw.match(/.*>>>n?vim ([^\/]+)$/))) return "  Neovim — " + m[1];
        if ((m = raw.match(/.*>>>(.*) [—-] N[Vv]im$/))) return "  Neovim — " + m[1];

        if ((m = raw.match(/.*>>>(.*) [—-] Deezer/))) return "󰎆  Deezer — " + m[1];
        if (/.*>>>Deezer.*/.test(raw)) return "󰎆  Deezer";
        if ((m = raw.match(/.*[Dd]eezer.*>>>(.*)/))) return "󰎆  Deezer — " + m[1];

        if ((m = raw.match(/.*>>>antoine@[^:]*:.*\/([^\/]+)$/))) return "  Alacritty (" + m[1] + ")";
        if ((m = raw.match(/.*>>>antoine@[^:]*:(.*)/))) return "  Alacritty (" + m[1] + ")";

        if ((m = raw.match(/.*>>>(.*) [—-] (Discord|Vesktop)/))) return "󰙯  Discord — " + m[1];

        let fallback = title || appId || "";
        return fallback.length > 55 ? fallback.substring(0, 52) + "..." : fallback;
    }

    Process {
        id: statusPoller
        command: [root.scriptsDir + "/status.sh"]
        stdout: SplitParser {
            onRead: data => {
                let p = data.trim().split("@@SEP@@");
                if (p.length < 18) return;

                let winParts = p[0].split(">>>");
                let formatted = root.formatWindow(winParts[0] || "", winParts[1] || "");
                root.activeWindowTitle = formatted.length > 55 ? formatted.substring(0, 52) + "..." : formatted;

                root.swayMode = (p[1] !== "default" && p[1] !== "") ? p[1] : "";

                // Audio + Tooltip
                root.audioMuted = (p[2] === "true");
                let v = parseInt(p[3]) || 0;
                let sinkDesc = p[16] || "default";
                if (sinkDesc.length > 28) sinkDesc = sinkDesc.substring(0, 25) + "...";
                let micState = p[17] || "active";
                let aIcon = root.audioMuted ? "󰝟" : (v < 33 ? "󰕿" : (v < 66 ? "󰖀" : "󰕾"));

                if (root.audioMuted) {
                    root.audioText = "󰝟";
                } else {
                    root.audioText = aIcon + " " + v + "%";
                }
                root.audioTooltipHtml = "<tt>"
                    + "<span style='color:#ff8800;'>" + aIcon + "  " + (root.audioMuted ? "muted (" + v + "%)" : v + "%") + "</span><br>"
                    + "<span style='color:#888888;'>output  </span><span style='color:#e5e5e5;'>" + sinkDesc + "</span><br>"
                    + "<span style='color:#888888;'>mic     </span><span style='color:#e5e5e5;'>" + micState + "</span>"
                    + "</tt>";

                // Luminosité (icône seule + Tooltip)
                if (!brightApplyTimer.running) {
                    let b = parseInt(p[4]) || 100;
                    root.updateBrightLabel(b);
                }

                // Batterie (inchangée)
                let cap = parseInt(p[5]) || 100;
                let st = p[6];
                let batW = p[13] || "0.0";
                let pwrProf = p[14] || "balanced";
                let batIcons = ["", "", "", "", ""];
                let batIdx = Math.min(4, Math.max(0, Math.floor(cap / 22)));
                if (st === "Charging") {
                    root.batText = "󰂄 " + cap + "%";
                    root.batState = "charging";
                } else if (st === "Full" || st === "Not charging") {
                    root.batText = " " + cap + "%";
                    root.batState = "charging";
                } else {
                    root.batText = batIcons[batIdx] + " " + cap + "%";
                    root.batState = cap <= 15 ? "critical" : (cap <= 30 ? "warning" : "normal");
                }
                root.batTooltipHtml = "<tt>"
                    + "<span style='color:#ff8800;'>" + root.batText + " · " + st.toLowerCase() + "</span><br>"
                    + "<span style='color:#888888;'>power   </span><span style='color:#e5e5e5;'>" + batW + " W</span><br>"
                    + "<span style='color:#888888;'>profile </span><span style='color:#e5e5e5;'>" + pwrProf + "</span>"
                    + "</tt>";

                // Bluetooth
                if (p[7] !== "on") {
                    root.btText = "󰂲";
                    root.btTooltipHtml = "<span style='color:#888888;'>󰂲  bluetooth off</span>";
                } else if (p[8] !== "") {
                    root.btText = root.btCompact ? "" : (" " + p[8]);
                    root.btTooltipHtml = "<tt><span style='color:#ff8800;'>  connected</span><br><span style='color:#e5e5e5;'>" + p[8] + "</span></tt>";
                } else {
                    root.btText = "";
                    root.btTooltipHtml = "<span style='color:#888888;'>  disconnected</span>";
                }

                // Wi-Fi
                let wRadio = p[9];
                let wLine = p[10];
                let ethCon = p[11];
                let ipAddr = p[12] || "-";

                if (wRadio === "disabled") {
                    root.wifiIcon = "󰤮";
                    root.wifiSsid = "";
                    root.wifiConnected = false;
                    root.wifiTooltipHtml = "<span style='color:#ff8800;'>󰤮  wifi off</span>";
                } else if (wLine !== "") {
                    let wParts = wLine.split(":");
                    let ssid = wParts[1] || "Wi-Fi";
                    let sig = parseInt(wParts[2]) || 0;
                    let sec = wParts[3] || "Open";
                    let wIcons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
                    let wIdx = Math.min(4, Math.max(0, Math.floor(sig / 22)));

                    root.wifiIcon = wIcons[wIdx];
                    root.wifiSsid = ssid;
                    root.wifiConnected = true;
                    root.wifiTooltipHtml = "<tt>"
                        + "<span style='color:#ff8800;'>" + root.wifiIcon + "  " + ssid + "</span><br>"
                        + "<span style='color:#888888;'>signal  </span><span style='color:#e5e5e5;'>" + sig + "%</span><br>"
                        + "<span style='color:#888888;'>ip      </span><span style='color:#e5e5e5;'>" + ipAddr + "</span><br>"
                        + "<span style='color:#888888;'>sec     </span><span style='color:#e5e5e5;'>" + sec + "</span>"
                        + "</tt>";
                } else if (ethCon !== "") {
                    root.wifiIcon = "󰈀";
                    root.wifiSsid = "Ethernet";
                    root.wifiConnected = true;
                    root.wifiTooltipHtml = "<tt>"
                        + "<span style='color:#ff8800;'>󰈀  ethernet</span><br>"
                        + "<span style='color:#888888;'>ip  </span><span style='color:#e5e5e5;'>" + ipAddr + "</span>"
                        + "</tt>";
                } else {
                    root.wifiIcon = "󰤯";
                    root.wifiSsid = "Disconnected";
                    root.wifiConnected = false;
                    root.wifiTooltipHtml = "<span style='color:#888888;'>󰤯  disconnected</span>";
                }

                // AirPods / OmaPods + Tooltip
                try {
                    let ps = JSON.parse(p[15]);
                    root.podsState = ps;
                    if (!ps.running) {
                        root.podsTooltipHtml = "<span style='color:#888888;'>󱡏  daemon off</span>";
                    } else if (!ps.connected) {
                        root.podsTooltipHtml = "<span style='color:#888888;'>󱡏  disconnected</span>";
                    } else {
                        let lStr = (ps.left && ps.left.level > 0) ? (ps.left.level + "%") : "-";
                        let rStr = (ps.right && ps.right.level > 0) ? (ps.right.level + "%") : "-";
                        let cStr = (ps.case && ps.case.level > 0) ? (ps.case.level + "%") : "-";
                        let mStr = ps.mode || "off";
                        root.podsTooltipHtml = "<tt>"
                            + "<span style='color:#ff8800;'>󱡏  " + (ps.name || "airpods").toLowerCase() + "</span><br>"
                            + "<span style='color:#888888;'>left    </span><span style='color:#e5e5e5;'>" + lStr + "</span><br>"
                            + "<span style='color:#888888;'>right   </span><span style='color:#e5e5e5;'>" + rStr + "</span><br>"
                            + "<span style='color:#888888;'>case    </span><span style='color:#e5e5e5;'>" + cStr + "</span><br>"
                            + "<span style='color:#888888;'>mode    </span><span style='color:#e5e5e5;'>" + mStr + "</span>"
                            + "</tt>";
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: calPoller
        command: ["python3", root.scriptsDir + "/cal_gen.py"]
        stdout: SplitParser {
            onRead: data => { root.calTooltipHtml = data.trim(); }
        }
    }

    Timer {
        interval: 800
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusPoller.running = true
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            calPoller.running = true;
            appsPoller.running = true;
        }
    }
}
