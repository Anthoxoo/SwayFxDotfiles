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
    property bool wifiMenuOpen: false
    property bool wifiScanning: false
    property var wifiDetailState: ({ enabled: true, connected: false, activeSsid: "", ip: "-", networks: [] })
    property bool btMenuOpen: false
    property bool btScanning: false
    property var btDetailState: ({ powered: true, connectedCount: 0, devices: [] })

    // Luminosité
    property int brightValue: 100
    property string backlightText: "󰪥"
    property string brightTooltipHtml: ""
    property bool brightnessMenuOpen: false
    property bool nightLightOn: false
    property int nightLightTemp: 4500
    property bool osdVisible: false

    // Écrans (Monitors)
    property bool monitorsMenuOpen: false
    property var monitorsState: ({ count: 1, activeCount: 1, hideWhenSingle: false, outputs: [] })
    property string monitorsTooltipHtml: ""

    // OmaPods (AirPods)
    property bool podsMenuOpen: false
    property bool podsHideWhenDisconnected: false
    property var podsState: ({ running: false, connected: false, barPct: -1, modes: [] })
    property string podsTooltipHtml: "<span style='color:#888888;'>󱡏  disconnected</span>"

    // Audio
    property string audioText: "󰕾 0%"
    property bool audioMuted: false
    property bool audioMenuOpen: false
    property var audioDetailState: ({ vol: 0, muted: false, micVol: 100, micMuted: false, sinks: [], sources: [], apps: [] })
    property bool audioOsdVisible: false
    property int audioOsdValue: 0
    property bool audioOsdMuted: false
    property bool batteryMenuOpen: false
    property var batteryDetailState: ({ capacity: 100, status: "discharging", watts: 0.0, timeStr: "-", health: 100, cycles: 0, profile: "balanced" })
    property string audioTooltipHtml: ""

    // Batterie
    property string batText: " 100%"
    property string batState: "normal"
    property string batTooltipHtml: ""

    // Menus & État global
    property bool clockAlt: false
    property bool calendarMenuOpen: false
    property bool powerMenuOpen: false
    property bool launcherOpen: false
    property bool dndMode: false
    property bool screenLocked: false
    property var appList: []
    property string lastPodsJson: ""
    property string lastMonsJson: ""

    signal clearNotificationsRequested()

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/scripts"

    Process {
        id: cmdRunner
    }

    function runCmd(cmd) {
        cmdRunner.command = ["sh", "-c", cmd];
        cmdRunner.startDetached();
    }

    // Contrôles Écrans (Monitors)
    Process {
        id: wifiDetailPoller
        property string modeArg: "status"
        command: ["python3", root.scriptsDir + "/wifi-ctl.py", wifiDetailPoller.modeArg]
        stdout: SplitParser {
            onRead: data => {
                root.wifiScanning = false;
                try {
                    root.wifiDetailState = JSON.parse(data.trim());
                } catch (e) {}
            }
        }
    }
Process {
        id: btDetailPoller
        property string modeArg: "status"
        command: ["python3", root.scriptsDir + "/bt-ctl.py", btDetailPoller.modeArg]
        stdout: SplitParser {
            onRead: data => {
                root.btScanning = false;
                try {
                    root.btDetailState = JSON.parse(data.trim());
                } catch (e) {}
            }
        }
    }

    function refreshWifiDetails(doScan) {
        if (wifiDetailPoller.running) return;
        root.wifiScanning = Boolean(doScan);
        wifiDetailPoller.modeArg = doScan ? "scan" : "status";
        wifiDetailPoller.running = true;
    }

    function refreshBtDetails(doScan) {
        if (btDetailPoller.running) return;
        root.btScanning = Boolean(doScan);
        btDetailPoller.modeArg = doScan ? "scan" : "status";
        btDetailPoller.running = true;
    }

    function wifiToggleRadio() {
        let copy = Object.assign({}, root.wifiDetailState);
        copy.enabled = !copy.enabled;
        root.wifiDetailState = copy;
        root.runCmd("python3 " + root.scriptsDir + "/wifi-ctl.py toggle-radio");
        reloadNetTimer.restart();
    }

    function wifiDisconnect() {
        root.runCmd("python3 " + root.scriptsDir + "/wifi-ctl.py disconnect");
        reloadNetTimer.restart();
    }

    function wifiConnect(ssid, pwd) {
        let escSsid = ssid.replace(/'/g, "'\''");
        let escPwd = (pwd || "").replace(/'/g, "'\''");
        if (escPwd !== "") {
            root.runCmd("python3 " + root.scriptsDir + "/wifi-ctl.py connect '" + escSsid + "' '" + escPwd + "'");
        }
else {
            root.runCmd("python3 " + root.scriptsDir + "/wifi-ctl.py connect '" + escSsid + "'");
        }
        reloadNetTimer.interval = 1800;
        reloadNetTimer.restart();
    }

    function wifiForget(ssid) {
        let escSsid = ssid.replace(/'/g, "'\''");
        root.runCmd("python3 " + root.scriptsDir + "/wifi-ctl.py forget '" + escSsid + "'");
        reloadNetTimer.restart();
    }

    function btTogglePower() {
        let copy = Object.assign({}, root.btDetailState);
        copy.powered = !copy.powered;
        root.btDetailState = copy;
        root.runCmd("python3 " + root.scriptsDir + "/bt-ctl.py toggle-power");
        reloadNetTimer.restart();
    }

    function btToggleDevice(mac) {
        root.runCmd("python3 " + root.scriptsDir + "/bt-ctl.py toggle-device '" + mac + "'");
        reloadNetTimer.interval = 1500;
        reloadNetTimer.restart();
    }

    function btRemoveDevice(mac) {
        root.runCmd("python3 " + root.scriptsDir + "/bt-ctl.py remove '" + mac + "'");
        reloadNetTimer.restart();
    }
Timer {
        id: reloadNetTimer
        interval: 500
        repeat: false
        onTriggered: {
            interval = 500;
            statusPoller.running = true;
            if (root.wifiMenuOpen) root.refreshWifiDetails(false);
            if (root.btMenuOpen) root.refreshBtDetails(false);
        }
    }
Process {
        id: audioDetailPoller
        command: ["python3", root.scriptsDir + "/audio-ctl.py", "status"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.audioDetailState = JSON.parse(data.trim());
                } catch (e) {}
            }
        }
    }
Process {
        id: batteryDetailPoller
        command: ["python3", root.scriptsDir + "/battery-ctl.py", "status"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.batteryDetailState = JSON.parse(data.trim());
                } catch (e) {}
            }
        }
    }
Timer {
        id: audioVolTimer
        property int targetVol: 50
        interval: 30
        repeat: false
        onTriggered: {
            root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py set-vol " + targetVol);
            statusPoller.running = true;
        }
    }
    Timer {
        id: audioOsdTimer
        interval: 1200
        repeat: false
        onTriggered: root.audioOsdVisible = false
    }
Timer {
        id: micVolTimer
        property int targetVol: 50
        interval: 30
        repeat: false
        onTriggered: {
            root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py set-mic-vol " + targetVol);
        }
    }

    function refreshAudioDetails() {
        audioDetailPoller.running = true;
    }

    function refreshBatteryDetails() {
        batteryDetailPoller.running = true;
    }

    function showAudioOsd(value, muted) {
        root.audioOsdValue = Math.max(0, Math.min(100, Math.round(value)));
        root.audioOsdMuted = muted;
        root.audioOsdVisible = true;
        audioOsdTimer.restart();
    }

    function audioSetVolume(val) {
        let clamped = Math.max(0, Math.min(100, Math.round(val)));
        let copy = Object.assign({}, root.audioDetailState);
        copy.vol = clamped;
        root.audioDetailState = copy;
        let aIcon = root.audioMuted ? "󰝟" : (clamped < 33 ? "󰕿" : (clamped < 66 ? "󰖀" : "󰕾"));
        root.audioText = root.audioMuted ? "󰝟" : (aIcon + " " + clamped + "%");
        root.showAudioOsd(clamped, root.audioMuted);
        audioVolTimer.targetVol = clamped;
        audioVolTimer.restart();
    }

    function audioToggleMute() {
        let nextM = !root.audioMuted;
        root.audioMuted = nextM;
        let copy = Object.assign({}, root.audioDetailState);
        copy.muted = nextM;
        root.audioDetailState = copy;
        root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py toggle-mute");
        reloadAudioTimer.restart();
    }

    function audioSetMicVolume(val) {
        let clamped = Math.max(0, Math.min(100, Math.round(val)));
        let copy = Object.assign({}, root.audioDetailState);
        copy.micVol = clamped;
        root.audioDetailState = copy;
        micVolTimer.targetVol = clamped;
        micVolTimer.restart();
    }

    function audioToggleMic() {
        let copy = Object.assign({}, root.audioDetailState);
        copy.micMuted = !copy.micMuted;
        root.audioDetailState = copy;
        root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py toggle-mic");
        reloadAudioTimer.restart();
    }

    function audioSetSink(sinkName) {
        root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py set-sink '" + sinkName + "'");
        reloadAudioTimer.restart();
    }

    function audioSetSource(srcName) {
        root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py set-source '" + srcName + "'");
        reloadAudioTimer.restart();
    }

    function audioSetAppVol(appId, val) {
        root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py set-app-vol '" + appId + "' " + Math.round(val));
        reloadAudioTimer.restart();
    }

    function batterySetProfile(prof) {
        let copy = Object.assign({}, root.batteryDetailState);
        copy.profile = prof;
        root.batteryDetailState = copy;
        root.runCmd("python3 " + root.scriptsDir + "/battery-ctl.py set-profile '" + prof + "'");
        reloadAudioTimer.restart();
    }
Timer {
        id: reloadAudioTimer
        interval: 150
        repeat: false
        onTriggered: {
            statusPoller.running = true;
            audioDetailPoller.running = true;
            batteryDetailPoller.running = true;
        }
    }

    function monitorsCmd(arg) {
        runCmd("python3 " + root.scriptsDir + "/monitors-ctl.py " + arg);
        reloadMonsTimer.restart();
    }

    function monitorsPlace(name, dir) {
        monitorsCmd("place '" + name + "' '" + dir + "'");
    }

    function monitorsSetPos(jsonStr) {
        monitorsCmd("set-pos '" + jsonStr + "'");
    }

    function monitorsToggle(name) {
        monitorsCmd("toggle '" + name + "'");
    }

    function monitorsRate(name, modeStr, hzVal) {
        if (root.monitorsState && root.monitorsState.outputs) {
            let copy = JSON.parse(JSON.stringify(root.monitorsState));
            for (let i = 0; i < copy.outputs.length; i++) {
                if (copy.outputs[i].name === name) {
                    copy.outputs[i].hz = hzVal;
                }
            }
            root.monitorsState = copy;
        }
        monitorsCmd("rate " + name + " '" + modeStr + "'");
    }

    function monitorsScale(name, sc) {
        monitorsCmd("scale '" + name + "' '" + sc + "'");
    }
Timer {
        id: reloadMonsTimer
        interval: 150
        repeat: false
        onTriggered: statusPoller.running = true
    }

    // Contrôles OmaPods (AirPods)
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
Timer {
        id: podsAdaptTimer
        property int targetVal: 50
        interval: 40
        repeat: false
        onTriggered: root.podsCmd("adaptive:" + targetVal)
    }

    function podsSetAdaptive(val) {
        let copy = Object.assign({}, root.podsState);
        copy.adaptiveLevel = val;
        root.podsState = copy;
        podsAdaptTimer.targetVal = val;
        podsAdaptTimer.restart();
    }

    function podsSetEar(earMode) {
        let copy = Object.assign({}, root.podsState);
        copy.ear = earMode;
        root.podsState = copy;
        podsCmd("ear:" + earMode);
    }

    function podsSetProfile(prof) {
        let copy = Object.assign({}, root.podsState);
        copy.audioProfile = prof;
        root.podsState = copy;
        podsCmd("profile:" + prof);
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

    // Contrôles Luminosité & Night Light
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
    }

    function setBrightnessAndApply(val, showOsdPopup) {
        setBrightness(val, showOsdPopup);
        brightApplyTimer.targetVal = Math.max(1, Math.min(100, Math.round(val)));
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
        }
else {
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

    function lockScreen() {
        root.closeAllPopups();
        root.screenLocked = true;
        root.runCmd("touch /tmp/quickshell_locked && swaymsg mode 'locked'");
    }

    function unlockScreen() {
        root.screenLocked = false;
        root.runCmd("rm -f /tmp/quickshell_locked && swaymsg mode 'default'");
    }

    function closeAllPopups() {
        root.launcherOpen = false;
        root.powerMenuOpen = false;
        root.brightnessMenuOpen = false;
        root.podsMenuOpen = false;
        root.calendarMenuOpen = false;
        root.monitorsMenuOpen = false;
        root.audioMenuOpen = false;
        root.batteryMenuOpen = false;
        root.wifiMenuOpen = false;
        root.btMenuOpen = false;
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
                if (cmd === "lock-screen") {
                    root.lockScreen();
                } else if (cmd === "unlock-screen") {
                    root.unlockScreen();
                } else if (cmd === "toggle-launcher") {
                    let next = !root.launcherOpen;
                    root.closeAllPopups();
                    root.launcherOpen = next;
                } else if (cmd === "close-launcher") {
                    root.launcherOpen = false;
                } else if (cmd === "toggle-power") {
                    let next = !root.powerMenuOpen;
                    root.closeAllPopups();
                    root.powerMenuOpen = next;
                } else if (cmd === "toggle-brightness") {
                    let next = !root.brightnessMenuOpen;
                    root.closeAllPopups();
                    root.brightnessMenuOpen = next;
                } else if (cmd === "toggle-pods") {
                    let next = !root.podsMenuOpen;
                    root.closeAllPopups();
                    root.podsMenuOpen = next;
                } else if (cmd === "toggle-wifi") {
                    let next = !root.wifiMenuOpen;
                    root.closeAllPopups();
                    root.wifiMenuOpen = next;
                } else if (cmd === "toggle-bt") {
                    let next = !root.btMenuOpen;
                    root.closeAllPopups();
                    root.btMenuOpen = next;
                } else if (cmd === "toggle-audio") {
                    let next = !root.audioMenuOpen;
                    root.closeAllPopups();
                    root.audioMenuOpen = next;
                } else if (cmd === "toggle-battery") {
                    let next = !root.batteryMenuOpen;
                    root.closeAllPopups();
                    root.batteryMenuOpen = next;
                } else if (cmd === "toggle-monitors") {
                    let next = !root.monitorsMenuOpen;
                    root.closeAllPopups();
                    root.monitorsMenuOpen = next;
                } else if (cmd === "clear-notifs") {
                    root.clearNotificationsRequested();
                } else if (cmd === "toggle-dnd") {
                    root.dndMode = !root.dndMode;
                } else if (cmd.startsWith("osd-audio:")) {
                    let parts = cmd.split(":");
                    let v = parseInt(parts[1]);
                    let muted = parts[2] === "true";
                    if (!isNaN(v)) {
                        root.showAudioOsd(v, muted);
                    }
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
                if (p.length < 16) return;

                let winParts = p[0].split(">>>");
                let formatted = root.formatWindow(winParts[0] || "", winParts[1] || "");
                root.activeWindowTitle = formatted.length > 55 ? formatted.substring(0, 52) + "..." : formatted;

                if (p[1] === "locked" && !root.screenLocked) {
                    root.runCmd("swaymsg mode 'default'");
                }
                root.swayMode = (p[1] !== "default" && p[1] !== "locked" && p[1] !== "") ? p[1] : "";

                // Audio
                let muted = (p[2] === "true");
                let v = parseInt(p[3]);
                if (isNaN(v)) v = 0;
                if (!audioOsdTimer.running && !audioVolTimer.running && !root.audioMenuOpen) {
                    root.audioMuted = muted;
                    let copy = Object.assign({}, root.audioDetailState);
                    copy.vol = v;
                    copy.muted = muted;
                    root.audioDetailState = copy;
                }
                let sinkDesc = (p.length > 16 && p[16]) ? p[16] : "default";
                if (sinkDesc.length > 28) sinkDesc = sinkDesc.substring(0, 25) + "...";
                let micState = (p.length > 17 && p[17]) ? p[17] : "active";
                let aIcon = root.audioMuted ? "󰝟" : (v < 33 ? "󰕿" : (v < 66 ? "󰖀" : "󰕾"));

                root.audioText = root.audioMuted ? "󰝟" : (aIcon + " " + v + "%");
                root.audioTooltipHtml = "<tt>"
                    + "<span style='color:#ff8800;'>" + aIcon + "  " + (root.audioMuted ? "muted (" + v + "%)" : v + "%") + "</span><br>"
                    + "<span style='color:#888888;'>output  </span><span style='color:#e5e5e5;'>" + sinkDesc + "</span><br>"
                    + "<span style='color:#888888;'>mic     </span><span style='color:#e5e5e5;'>" + micState + "</span>"
                    + "</tt>";

                // Luminosité
                if (!brightApplyTimer.running && !osdTimer.running && !root.brightnessMenuOpen) {
                    let b = parseInt(p[4]);
                    if (!isNaN(b)) root.updateBrightLabel(b);
                }

                // Batterie
                let cap = parseInt(p[5]);
                if (isNaN(cap)) cap = 100;
                let st = p[6] || "Discharging";
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
                }
else {
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
                }
else {
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
                }
else {
                    root.wifiIcon = "󰤯";
                    root.wifiSsid = "Disconnected";
                    root.wifiConnected = false;
                    root.wifiTooltipHtml = "<span style='color:#888888;'>󰤯  disconnected</span>";
                }

                // OmaPods
                if (p.length > 15 && p[15]) {
                    try {
                        let ps = JSON.parse(p[15]);
                        if (p[15] !== root.lastPodsJson) {
                            root.lastPodsJson = p[15];
                            root.podsState = ps;
                        }
                        if (!ps.running) {
                            root.podsTooltipHtml = "<span style='color:#888888;'>󱡏  daemon off</span>";
                        } else if (!ps.connected) {
                            root.podsTooltipHtml = "<span style='color:#888888;'>󱡏  disconnected</span>";
                        }
else {
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

                // Monitors
                if (p.length > 18 && p[18]) {
                    try {
                        let ms = JSON.parse(p[18]);
                        if (p[18] !== root.lastMonsJson) {
                            root.lastMonsJson = p[18];
                            root.monitorsState = ms;
                        }
                        let lines = ["<span style='color:#ff8800;'>󰍹  displays (" + ms.activeCount + "/" + ms.count + ")</span>"];
                        for (let i = 0; i < ms.outputs.length; i++) {
                            let o = ms.outputs[i];
                            let stStr = o.active ? (o.width + "×" + o.height + "@" + (o.hz || 60) + "Hz") : "off";
                            lines.push("<span style='color:#888888;'>" + o.name.padEnd(8, " ") + "</span><span style='color:#e5e5e5;'>" + stStr + "</span>");
                        }
                        root.monitorsTooltipHtml = "<tt>" + lines.join("<br>") + "</tt>";
                    } catch (e) {}
                }
            }
        }
    }
Timer {
        interval: 1200
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
        onTriggered: appsPoller.running = true
    }
}
