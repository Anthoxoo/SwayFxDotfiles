pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Networking

// État global du shell.
// Les données de la barre viennent des services natifs de Quickshell (événements D-Bus /
// Pipewire / Wayland), plus aucun script lancé en boucle toutes les 1,2 s.
// Seuls restent interrogés : OmaPods (librepods : 4 s si connectés, 30 s sinon) et les écrans (sur
// événement "output" de sway). Les menus détaillés appellent toujours leurs scripts *-ctl.py
// à l'ouverture / après une action.
Singleton {
    id: root

    property string swayMode: ""
    property string wifiIcon: "󰤨"
    property string wifiSsid: ""
    property bool wifiConnected: true
    property bool wifiCompact: true
    property string wifiTooltipHtml: ""
    property string btText: "\uf294"
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
    property string podsTooltipHtml: Theme.tipMuted("󱡏  disconnected")

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
    property string batText: "\uf240 100%"
    property string batState: "normal"
    property string batTooltipHtml: ""

    // Menus & État global
    property bool clockAlt: false
    property bool calendarMenuOpen: false
    property bool powerMenuOpen: false
    property bool launcherOpen: false
    property bool reminderOpen: false
    property bool themeMenuOpen: false
    property bool dndMode: false
    property bool screenLocked: false
    property bool lockSecure: false          // vrai quand sway confirme le verrou (ext-session-lock)
    property var appList: []
    property string lastPodsJson: ""
    property string lastMonsJson: ""

    signal clearNotificationsRequested()

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/scripts"
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string lockMarker: runtimeDir + "/quickshell-locked"
    readonly property string batAlertFile: runtimeDir + "/quickshell-bat-alert"

    Process {
        id: cmdRunner
    }

    function runCmd(cmd) {
        cmdRunner.command = ["sh", "-c", cmd];
        cmdRunner.startDetached();
    }

    // =====================================================================
    // IPC : `qs ipc call shell <fonction> [args]`  /  `qs ipc call lock lock`
    // (remplace le FIFO /tmp/quickshell-ipc.fifo ; volontairement aucun "unlock")
    // =====================================================================
    function togglePanel(name) {
        let prop = ({
            launcher: "launcherOpen", power: "powerMenuOpen", brightness: "brightnessMenuOpen",
            pods: "podsMenuOpen", wifi: "wifiMenuOpen", bt: "btMenuOpen", audio: "audioMenuOpen",
            battery: "batteryMenuOpen", monitors: "monitorsMenuOpen", calendar: "calendarMenuOpen",
            reminder: "reminderOpen", theme: "themeMenuOpen"
        })[name];
        if (!prop) return false;
        let next = !root[prop];
        root.closeAllPopups();
        root[prop] = next;
        return true;
    }

    IpcHandler {
        target: "shell"

        function toggle(panel: string): bool { return root.togglePanel(panel); }
        function closeAll(): void { root.closeAllPopups(); }
        function clearNotifs(): void { root.clearNotificationsRequested(); }
        function toggleDnd(): void { root.dndMode = !root.dndMode; }
        function osdAudio(value: int, muted: bool): void { root.showAudioOsd(value, muted); }
        function osdBright(value: int): void {
            root.updateBrightLabel(value);
            root.triggerOsd();
        }
        function refresh(): void { root.refresh(); }
    }

    IpcHandler {
        target: "lock"

        function lock(): void { root.lockScreen(); }
        function isLocked(): bool { return root.lockSecure; }
    }

    // =====================================================================
    // Verrouillage
    // =====================================================================
    function lockScreen() {
        root.closeAllPopups();
        root.screenLocked = true;
        root.runCmd("touch '" + root.lockMarker + "'");
    }

    // Appelé uniquement par LockScreen.qml après succès PAM
    function unlockScreen() {
        root.screenLocked = false;
        root.runCmd("rm -f '" + root.lockMarker + "'");
    }

    // Au démarrage (ou après un crash/redémarrage de Quickshell) : re-verrouiller si besoin
    Process {
        running: true
        command: ["test", "-e", root.lockMarker]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) root.lockScreen();
        }
    }

    // =====================================================================
    // Fenêtre active (wlr-foreign-toplevel) & mode sway
    // =====================================================================
    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property string activeWindowTitle: {
        let t = root.activeToplevel;
        if (!t) return "";
        let formatted = root.formatWindow(t.appId || "", t.title || "");
        return formatted.length > 55 ? formatted.substring(0, 52) + "..." : formatted;
    }

    // Flux d'événements sway : changements de mode et d'écrans
    Process {
        id: swayEvents
        running: true
        command: ["swaymsg", "-t", "subscribe", "-m", "[\"mode\",\"output\"]"]
        stdout: SplitParser {
            onRead: data => {
                let ev;
                try { ev = JSON.parse(data); } catch (e) { return; }
                if (ev.pango_markup !== undefined) {
                    root.swayMode = (ev.change && ev.change !== "default") ? ev.change : "";
                } else {
                    reloadMonsTimer.restart();
                }
            }
        }
        onExited: swayEventsRestart.start()
    }
    Timer {
        id: swayEventsRestart
        interval: 2000
        onTriggered: swayEvents.running = true
    }

    // =====================================================================
    // Wi-Fi / réseau (NetworkManager via Quickshell.Networking)
    // =====================================================================
    readonly property var wifiDevice: {
        let devs = Networking.devices.values;
        for (let i = 0; i < devs.length; i++) if (devs[i].type === DeviceType.Wifi) return devs[i];
        return null;
    }
    readonly property var wifiNetwork: {
        if (!root.wifiDevice) return null;
        let nets = root.wifiDevice.networks.values;
        for (let i = 0; i < nets.length; i++) if (nets[i].connected) return nets[i];
        return null;
    }
    readonly property bool ethernetUp: {
        let devs = Networking.devices.values;
        for (let i = 0; i < devs.length; i++) if (devs[i].type === DeviceType.Wired && devs[i].connected) return true;
        return false;
    }
    property string ipAddr: "-"

    // Identité de la connexion : quand elle change, on relit l'IP
    readonly property string netIdSig: Networking.wifiEnabled + "|" + (root.wifiNetwork ? root.wifiNetwork.name : "") + "|" + root.ethernetUp
    onNetIdSigChanged: ipTimer.restart()
    // Tout ce qui est affiché
    readonly property string netSig: root.netIdSig + "|" + (root.wifiNetwork ? Math.round(root.wifiNetwork.signalStrength * 100) : -1) + "|" + root.ipAddr
    onNetSigChanged: root.syncNetwork()

    Timer {
        id: ipTimer
        interval: 800
        onTriggered: ipPoller.running = true
    }
    Process {
        id: ipPoller
        command: ["ip", "-4", "route", "get", "1.1.1.1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let m = text.match(/\bsrc\s+(\S+)/);
                root.ipAddr = m ? m[1] : "-";
            }
        }
    }

    function syncNetwork() {
        let net = root.wifiNetwork;
        if (!Networking.wifiEnabled && !root.ethernetUp) {
            root.wifiIcon = "󰤮";
            root.wifiSsid = "";
            root.wifiConnected = false;
            root.wifiTooltipHtml = Theme.tipTitle("󰤮  wifi off");
        } else if (net) {
            let sig = Math.round(net.signalStrength * 100);
            let wIcons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"];
            root.wifiIcon = wIcons[Math.min(4, Math.max(0, Math.floor(sig / 22)))];
            root.wifiSsid = net.name || "Wi-Fi";
            root.wifiConnected = true;
            root.wifiTooltipHtml = Theme.tipBlock([
                Theme.tipTitle(root.wifiIcon + "  " + root.wifiSsid),
                Theme.tipRow("signal", sig + "%"),
                Theme.tipRow("ip", root.ipAddr),
                Theme.tipRow("sec", WifiSecurityType.toString(net.security))
            ]);
        } else if (root.ethernetUp) {
            root.wifiIcon = "󰈀";
            root.wifiSsid = "Ethernet";
            root.wifiConnected = true;
            root.wifiTooltipHtml = Theme.tipBlock([
                Theme.tipTitle("󰈀  ethernet"),
                Theme.tipRow("ip", root.ipAddr, 4)
            ]);
        } else {
            root.wifiIcon = "󰤯";
            root.wifiSsid = "Disconnected";
            root.wifiConnected = false;
            root.wifiTooltipHtml = Theme.tipMuted("󰤯  disconnected");
        }
    }

    // =====================================================================
    // Bluetooth (BlueZ via Quickshell.Bluetooth)
    // =====================================================================
    readonly property bool btPowered: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property string btConnectedName: {
        let devs = Bluetooth.devices.values;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected) return devs[i].name || devs[i].deviceName || devs[i].address;
        }
        return "";
    }
    readonly property string btSig: root.btPowered + "|" + root.btConnectedName + "|" + root.btCompact
    onBtSigChanged: root.syncBluetooth()

    function syncBluetooth() {
        if (!root.btPowered) {
            root.btText = "󰂲";
            root.btTooltipHtml = Theme.tipMuted("󰂲  bluetooth off");
        } else if (root.btConnectedName !== "") {
            root.btText = root.btCompact ? "\uf294" : ("\uf294 " + root.btConnectedName);
            root.btTooltipHtml = Theme.tipBlock([
                Theme.tipTitle("\uf294  connected"),
                Theme.tipSpan(Theme.fg, root.btConnectedName)
            ]);
        } else {
            root.btText = "\uf294";
            root.btTooltipHtml = Theme.tipMuted("\uf294  disconnected");
        }
    }

    // Détails (menus) : toujours via scripts, à la demande
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
        let escSsid = ssid.replace(/'/g, "'\\''");
        if (pwd) {
            // Natif (NetworkManager par D-Bus) : le mot de passe n'apparaît plus sur une ligne de
            // commande, lisible par tous dans /proc pendant l'exécution de nmcli
            let net = root.wifiNetworkByName(ssid);
            if (net) {
                root.wifiPendingNet = net;
                net.connectWithPsk(pwd);
            } else {
                let escPwd = pwd.replace(/'/g, "'\\''");
                root.runCmd("python3 " + root.scriptsDir + "/wifi-ctl.py connect '" + escSsid + "' '" + escPwd + "'");
            }
        } else {
            root.runCmd("python3 " + root.scriptsDir + "/wifi-ctl.py connect '" + escSsid + "'");
        }
        reloadNetTimer.interval = 1800;
        reloadNetTimer.restart();
    }

    // Native connections (password over D-Bus) report failures like wifi-ctl.py does
    property var wifiPendingNet: null
    Connections {
        target: root.wifiPendingNet
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            let why = "connection failed";
            if (reason === ConnectionFailReason.NoSecrets) why = "wrong password";
            else if (reason === ConnectionFailReason.WifiAuthTimeout) why = "authentication timed out";
            else if (reason === ConnectionFailReason.WifiNetworkLost) why = "network lost";
            else if (reason === ConnectionFailReason.WifiClientFailed) why = "authentication failed";
            let name = (root.wifiPendingNet ? root.wifiPendingNet.name : "").trim().replace(/'/g, "'\\''");
            root.runCmd("notify-send -a Wi-Fi -i network-wireless 'Can'\\''t connect to " + name + "' '" + why + "'");
        }
    }

    function wifiNetworkByName(ssid) {
        if (!root.wifiDevice) return null;
        let nets = root.wifiDevice.networks.values;
        for (let i = 0; i < nets.length; i++) if (nets[i].name === ssid) return nets[i];
        return null;
    }

    function wifiForget(ssid) {
        let escSsid = ssid.replace(/'/g, "'\\''");
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
            if (root.wifiMenuOpen) root.refreshWifiDetails(false);
            if (root.btMenuOpen) root.refreshBtDetails(false);
        }
    }

    // =====================================================================
    // Audio (Pipewire natif)
    // =====================================================================
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property var audioSource: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: [root.audioSink, root.audioSource]
    }

    readonly property int pwVol: (root.audioSink && root.audioSink.audio) ? Math.round(root.audioSink.audio.volume * 100) : 0
    readonly property bool pwMuted: (root.audioSink && root.audioSink.audio) ? root.audioSink.audio.muted : false
    readonly property bool pwMicMuted: (root.audioSource && root.audioSource.audio) ? root.audioSource.audio.muted : false
    readonly property string pwSinkDesc: root.audioSink ? (root.audioSink.description || root.audioSink.nickname || root.audioSink.name || "default") : "default"
    readonly property string audioSig: root.pwVol + "|" + root.pwMuted + "|" + root.pwMicMuted + "|" + root.pwSinkDesc
    onAudioSigChanged: root.syncAudio()

    function audioIcon(v, muted) {
        return muted ? "󰝟" : (v < 33 ? "󰕿" : (v < 66 ? "󰖀" : "󰕾"));
    }

    function syncAudio() {
        // Une écriture est en attente (glissement du curseur) : ne pas écraser la valeur optimiste
        if (audioVolTimer.running) return;
        let v = root.pwVol;
        root.audioMuted = root.pwMuted;
        let copy = Object.assign({}, root.audioDetailState);
        copy.vol = v;
        copy.muted = root.pwMuted;
        copy.micMuted = root.pwMicMuted;
        root.audioDetailState = copy;

        let sinkDesc = root.pwSinkDesc;
        if (sinkDesc.length > 28) sinkDesc = sinkDesc.substring(0, 25) + "...";
        let aIcon = root.audioIcon(v, root.audioMuted);
        root.audioText = root.audioMuted ? "󰝟" : (aIcon + " " + v + "%");
        root.audioTooltipHtml = Theme.tipBlock([
            Theme.tipTitle(aIcon + "  " + (root.audioMuted ? "muted (" + v + "%)" : v + "%")),
            Theme.tipRow("output", sinkDesc),
            Theme.tipRow("mic", root.pwMicMuted ? "muted" : "active")
        ]);
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
            if (root.audioSink && root.audioSink.audio) {
                root.audioSink.audio.volume = targetVol / 100;
            } else {
                root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py set-vol " + targetVol);
            }
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
            if (root.audioSource && root.audioSource.audio) {
                root.audioSource.audio.volume = targetVol / 100;
            } else {
                root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py set-mic-vol " + targetVol);
            }
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
        let aIcon = root.audioIcon(clamped, root.audioMuted);
        root.audioText = root.audioMuted ? "󰝟" : (aIcon + " " + clamped + "%");
        root.showAudioOsd(clamped, root.audioMuted);
        audioVolTimer.targetVol = clamped;
        audioVolTimer.restart();
    }

    function audioToggleMute() {
        if (root.audioSink && root.audioSink.audio) {
            root.audioSink.audio.muted = !root.audioSink.audio.muted;
        } else {
            root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py toggle-mute");
        }
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
        if (root.audioSource && root.audioSource.audio) {
            root.audioSource.audio.muted = !root.audioSource.audio.muted;
        } else {
            root.runCmd("python3 " + root.scriptsDir + "/audio-ctl.py toggle-mic");
        }
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

    // Rafraîchit les états détaillés des menus ouverts après une action
    Timer {
        id: reloadAudioTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.audioMenuOpen) audioDetailPoller.running = true;
            if (root.batteryMenuOpen) batteryDetailPoller.running = true;
        }
    }

    // =====================================================================
    // Batterie (UPower + power-profiles-daemon natifs)
    // =====================================================================
    readonly property var batDevice: UPower.displayDevice
    readonly property bool batReady: root.batDevice ? root.batDevice.ready : false
    // False on a desktop: the battery module and its alerts stay hidden
    readonly property bool hasBattery: root.batReady && root.batDevice.isLaptopBattery
    readonly property int upPct: root.batReady ? Math.round(root.batDevice.percentage * 100) : 100
    readonly property int upState: root.batReady ? root.batDevice.state : UPowerDeviceState.Unknown
    readonly property real upRate: root.batReady ? root.batDevice.changeRate : 0
    readonly property string upProfile: {
        let p = PowerProfiles.profile;
        if (p === PowerProfile.PowerSaver) return "power-saver";
        if (p === PowerProfile.Performance) return "performance";
        return "balanced";
    }
    readonly property string batSig: root.batReady + "|" + root.upPct + "|" + root.upState + "|" + root.upRate.toFixed(1) + "|" + root.upProfile
    onBatSigChanged: root.syncBattery()

    // Seuil de la dernière alerte (persisté dans $XDG_RUNTIME_DIR pour ne pas re-notifier à chaque redémarrage)
    property int lastBatAlert: 100
    FileView {
        id: batAlertView
        path: root.batAlertFile
        printErrors: false
        onLoaded: {
            let v = parseInt(text());
            if (!isNaN(v)) root.lastBatAlert = v;
        }
    }

    function setBatAlert(level) {
        if (root.lastBatAlert === level) return;
        root.lastBatAlert = level;
        root.runCmd("echo " + level + " > '" + root.batAlertFile + "'");
    }

    function syncBattery() {
        if (!root.hasBattery) return;
        let cap = root.upPct;
        let stEnum = root.upState;
        let st = "Discharging";
        if (stEnum === UPowerDeviceState.Charging) st = "Charging";
        else if (stEnum === UPowerDeviceState.FullyCharged) st = "Full";
        else if (stEnum === UPowerDeviceState.PendingCharge) st = "Not charging";

        let batIcons = ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"];
        let batIdx = Math.min(4, Math.max(0, Math.floor(cap / 22)));
        if (st === "Charging") {
            root.batText = "󰂄 " + cap + "%";
            root.batState = "charging";
        } else if (st === "Full" || st === "Not charging") {
            root.batText = "\uf1e6 " + cap + "%";
            root.batState = "charging";
        } else {
            root.batText = batIcons[batIdx] + " " + cap + "%";
            root.batState = cap <= 15 ? "critical" : (cap <= 30 ? "warning" : "normal");
        }
        root.batTooltipHtml = Theme.tipBlock([
            Theme.tipTitle(root.batText + " · " + st.toLowerCase()),
            Theme.tipRow("power", root.upRate.toFixed(1) + " W"),
            Theme.tipRow("profile", root.upProfile)
        ]);

        // Alertes batterie faible
        if (st === "Discharging") {
            if (cap <= 10 && root.lastBatAlert > 10) {
                root.runCmd("notify-send -u critical 'battery critical (" + cap + "%)' 'connect power adapter immediately'");
                root.setBatAlert(10);
            } else if (cap <= 20 && root.lastBatAlert > 20) {
                root.runCmd("notify-send -u normal 'battery low (" + cap + "%)' 'connect charger or enable power-saver'");
                root.setBatAlert(20);
            }
        } else {
            root.setBatAlert(100);
        }
    }

    // =====================================================================
    // Écrans
    // =====================================================================
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
        interval: 300
        repeat: false
        onTriggered: monitorsPoller.running = true
    }

    Process {
        id: monitorsPoller
        running: true
        command: ["python3", root.scriptsDir + "/monitors-ctl.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = text.trim();
                if (raw === "") return;
                try {
                    let ms = JSON.parse(raw);
                    if (raw !== root.lastMonsJson) {
                        root.lastMonsJson = raw;
                        root.monitorsState = ms;
                    }
                    let lines = [Theme.tipTitle("󰍹  displays (" + ms.activeCount + "/" + ms.count + ")")];
                    for (let i = 0; i < ms.outputs.length; i++) {
                        let o = ms.outputs[i];
                        let stStr = o.active ? (o.width + "×" + o.height + "@" + (o.hz || 60) + "Hz") : "off";
                        lines.push(Theme.tipRow(o.name, stStr));
                    }
                    root.monitorsTooltipHtml = Theme.tipBlock(lines);
                } catch (e) {}
            }
        }
    }

    // =====================================================================
    // OmaPods (AirPods via librepods)
    // Le démon réécrit $XDG_STATE_HOME/librepods/status.json à chaque changement (écriture
    // atomique) et le supprime quand il s'arrête : on surveille ce fichier, rien n'est interrogé.
    // =====================================================================
    readonly property string podsStatusPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/librepods/status.json"
    readonly property string podsCtlBin: Quickshell.env("HOME") + "/.local/bin/librepods-ctl"
    property var podsRaw: null                // dernier status.json lu (null : démon arrêté)
    property string podsAudioProfile: "a2dp"  // profil PipeWire (absent de status.json), relu à l'ouverture du menu
    property var podsPending: ({})            // valeurs affichées d'avance, en attente de confirmation par le démon

    FileView {
        id: podsFile
        path: root.podsStatusPath
        watchChanges: true
        printErrors: false
        // text() est périmé dans le signal de changement : on passe par reload()
        onFileChanged: reload()
        onLoaded: {
            try {
                root.podsRaw = JSON.parse(text());
            } catch (e) {
                return;
            }
            root.rebuildPods();
        }
        onLoadFailed: {
            root.podsRaw = null;
            root.rebuildPods();
        }
    }

    // AirPods connectés en Bluetooth ? (natif) — le lien audio peut précéder le lien AAP du démon
    readonly property bool airpodsBtConnected: {
        let devs = Bluetooth.devices.values;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].connected && /airpods/i.test(devs[i].name || "")) return true;
        }
        return false;
    }
    onAirpodsBtConnectedChanged: root.rebuildPods()
    onPodsMenuOpenChanged: {
        if (root.podsMenuOpen) {
            podsFile.reload();
            podsProfilePoller.running = true;
        }
    }

    function podsPod(o) {
        if (!o || !o.available) return { level: -1, charging: false, inEar: false };
        let chg = o.charging === true;
        let lvl = typeof o.level === "number" ? Math.round(o.level) : -1;
        if (lvl <= 0 && !chg) lvl = -1;
        return { level: lvl, charging: chg, inEar: o.in_ear === true };
    }

    // Traduit status.json (schéma v1 de librepods) vers l'état attendu par la barre et le menu
    function rebuildPods() {
        let running = root.podsRaw !== null && typeof root.podsRaw === "object";
        let r = running ? root.podsRaw : ({});
        let aap = r.connected === true;
        let modes = ["anc"];
        if (r.supports_adaptive !== false) modes.push("adaptive");
        modes.push("transparency");
        if (r.supports_noise_off !== false) modes.push("off");

        let st = {
            running: running,
            connected: aap || root.airpodsBtConnected,
            aapReady: aap,
            name: r.device_name || "airpods",
            model: r.model_name || "",
            isMax: r.is_headset === true,
            left: root.podsPod(r.left),
            right: root.podsPod(r.right),
            case: root.podsPod(r.case),
            single: root.podsPod(r.headset),
            mode: ({ 0: "off", 1: "anc", 2: "transparency", 3: "adaptive" })[r.noise_mode] || "",
            modes: modes,
            ca: r.conversational_awareness === true,
            oneBud: r.one_bud_anc_mode === true,
            adaptiveLevel: typeof r.adaptive_noise_level === "number" ? r.adaptive_noise_level : 50,
            ear: ["one", "both", "off"][r.ear_detection_behavior] || "one",
            audioProfile: root.podsAudioProfile,
            barPct: -1
        };
        let levels = [st.left.level, st.right.level, st.single.level].filter(l => l > 0);
        if (levels.length > 0) st.barPct = Math.min.apply(null, levels);

        // Valeurs envoyées mais pas encore confirmées : on les garde jusqu'à ce que le démon soit d'accord
        let pending = root.podsPending;
        let still = {};
        let confirmed = false;
        for (let k in pending) {
            if (st[k] === pending[k]) {
                confirmed = true;
            } else {
                st[k] = pending[k];
                still[k] = pending[k];
            }
        }
        if (confirmed) root.podsPending = still;

        let js = JSON.stringify(st);
        if (js === root.lastPodsJson) return;
        root.lastPodsJson = js;
        root.podsState = st;

        if (!running) {
            root.podsTooltipHtml = Theme.tipMuted("󱡏  daemon off");
        } else if (!st.connected) {
            root.podsTooltipHtml = Theme.tipMuted("󱡏  disconnected");
        } else {
            let pct = p => p.level > 0 ? (p.level + "%") : "-";
            let rows = [Theme.tipTitle("󱡏  " + st.name.toLowerCase())];
            if (st.isMax) {
                rows.push(Theme.tipRow("battery", pct(st.single)));
            } else {
                rows.push(Theme.tipRow("left", pct(st.left)), Theme.tipRow("right", pct(st.right)), Theme.tipRow("case", pct(st.case)));
            }
            rows.push(Theme.tipRow("mode", st.mode || "-"));
            root.podsTooltipHtml = Theme.tipBlock(rows);
        }
    }

    // Actions : les verbes du démon partent directement vers librepods-ctl ; le profil audio et
    // la connexion Bluetooth passent par omapods-ctl.py
    function podsCtl(verb) {
        root.runCmd("'" + root.podsCtlBin + "' " + verb);
    }

    function podsCmd(arg) {
        root.runCmd("python3 " + root.scriptsDir + "/omapods-ctl.py '" + arg + "'");
    }

    // Affiche la valeur tout de suite ; si le démon ne la confirme pas, l'état réel revient après 4 s
    function podsHold(field, value) {
        let p = Object.assign({}, root.podsPending);
        p[field] = value;
        root.podsPending = p;
        podsSettleTimer.restart();
        root.rebuildPods();
    }

    Timer {
        id: podsSettleTimer
        interval: 4000
        repeat: false
        onTriggered: {
            root.podsPending = ({});
            root.rebuildPods();
        }
    }

    function podsSetMode(m) {
        root.podsHold("mode", m);
        root.podsCtl("noise:" + m);
    }

    // Clic droit sur la barre : mode suivant parmi ceux que le modèle prend en charge
    function podsCycleMode() {
        let st = root.podsState;
        if (!st || !st.connected) return;
        let order = (st.modes && st.modes.length > 0) ? st.modes : ["anc", "adaptive", "transparency", "off"];
        root.podsSetMode(order[(order.indexOf(st.mode) + 1) % order.length]);
    }

    function podsToggleCa() {
        let v = !(root.podsState && root.podsState.ca);
        root.podsHold("ca", v);
        root.podsCtl("ca:" + (v ? "on" : "off"));
    }

    function podsToggleOneBud() {
        let v = !(root.podsState && root.podsState.oneBud);
        root.podsHold("oneBud", v);
        root.podsCtl("onebud:" + (v ? "on" : "off"));
    }

    Timer {
        id: podsAdaptTimer
        property int targetVal: 50
        interval: 40
        repeat: false
        onTriggered: root.podsCtl("adaptive:" + targetVal)
    }

    function podsSetAdaptive(val) {
        root.podsHold("adaptiveLevel", val);
        podsAdaptTimer.targetVal = val;
        podsAdaptTimer.restart();
    }

    function podsSetEar(earMode) {
        root.podsHold("ear", earMode);
        root.podsCtl("ear:" + earMode);
    }

    function podsCycleEar() {
        let order = ["one", "both", "off"];
        let cur = (root.podsState && root.podsState.ear) ? root.podsState.ear : "one";
        root.podsSetEar(order[(order.indexOf(cur) + 1) % order.length]);
    }

    function podsSetProfile(prof) {
        root.podsAudioProfile = prof;
        root.rebuildPods();
        root.podsCmd("profile:" + prof);
        podsProfileTimer.restart();
    }

    // Profil audio réel (pactl), relu à l'ouverture du menu et après un changement
    Timer {
        id: podsProfileTimer
        interval: 2000
        repeat: false
        onTriggered: podsProfilePoller.running = true
    }
    Process {
        id: podsProfilePoller
        command: ["python3", root.scriptsDir + "/omapods-ctl.py", "profile"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim();
                if (p !== "a2dp" && p !== "hfp") return;
                root.podsAudioProfile = p;
                root.rebuildPods();
            }
        }
    }

    // =====================================================================
    // Luminosité (sysfs lu directement) & Night Light
    // =====================================================================
    property string backlightDev: ""
    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.backlightDev = text.trim()
        }
    }
    FileView {
        id: blMaxView
        path: root.backlightDev !== "" ? "/sys/class/backlight/" + root.backlightDev + "/max_brightness" : ""
        printErrors: false
        onLoaded: root.syncBrightness()
    }
    FileView {
        id: blCurView
        path: root.backlightDev !== "" ? "/sys/class/backlight/" + root.backlightDev + "/actual_brightness" : ""
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.syncBrightness()
    }
    // Filet de sécurité si le noyau ne notifie pas les changements (lecture sysfs, aucun processus)
    Timer {
        interval: 5000
        running: root.backlightDev !== ""
        repeat: true
        onTriggered: blCurView.reload()
    }

    function syncBrightness() {
        if (brightApplyTimer.running || osdTimer.running || root.brightnessMenuOpen) return;
        let cur = parseInt(blCurView.text());
        let max = parseInt(blMaxView.text());
        if (isNaN(cur) || isNaN(max) || max <= 0) return;
        root.updateBrightLabel(Math.round(cur * 100 / max));
    }

    function updateBrightLabel(val) {
        let b = Math.max(1, Math.min(100, val));
        root.brightValue = b;
        let bIcons = ["󰄰", "󰪞", "󰪟", "󰪠", "󰪡", "󰪢", "󰪣", "󰪤", "󰪥"];
        let bIdx = Math.min(8, Math.max(0, Math.floor(b / 12)));
        let icon = root.nightLightOn ? "󰖔" : bIcons[bIdx];
        root.backlightText = icon;
        let nlStr = root.nightLightOn ? (root.nightLightTemp + "K") : "off";
        root.brightTooltipHtml = Theme.tipBlock([
            Theme.tipTitle(icon + "  display"),
            Theme.tipRow("brightness", b + "%", 11),
            Theme.tipRow("night", nlStr, 11)
        ]);
    }

    // Affiche la valeur tout de suite et l'applique au plus toutes les 50 ms pendant un glissement :
    // quand le minuteur expire, c'est toujours la dernière valeur demandée qui part.
    function setBrightness(val, showOsdPopup) {
        let clamped = Math.max(1, Math.min(100, Math.round(val)));
        updateBrightLabel(clamped);
        brightApplyTimer.targetVal = clamped;
        if (!brightApplyTimer.running) brightApplyTimer.start();
        if (showOsdPopup) triggerOsd();
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
        interval: 50
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

    // =====================================================================
    // Menus, lanceur, divers
    // =====================================================================
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
        root.reminderOpen = false;
        root.themeMenuOpen = false;
    }

    function launchApp(appId, execCmd, isTerm) {
        cmdRunner.command = ["python3", root.scriptsDir + "/launch-app.py", appId, execCmd, isTerm ? "true" : "false"];
        cmdRunner.startDetached();
        reloadAppsTimer.restart();
    }

    // Force la relecture des états non natifs (écouteurs, écrans, IP, luminosité)
    function refresh() {
        podsFile.reload();
        monitorsPoller.running = true;
        ipPoller.running = true;
        blCurView.reload();
    }

    function refreshApps() {
        appsPoller.running = true;
    }

    // À l'ouverture du lanceur : relit la liste si elle a plus d'une minute (applis installées ou
    // supprimées entre-temps). apps.py coûte ~1 s : on ne le relance plus en boucle en arrière-plan.
    property double appsLoadedAt: 0
    property string lastAppsJson: ""
    function refreshAppsIfStale() {
        if (!root.appList || root.appList.length === 0 || Date.now() - root.appsLoadedAt > 60000) root.refreshApps();
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
                let raw = data.trim();
                root.appsLoadedAt = Date.now();
                if (raw === root.lastAppsJson) return;  // inchangée : le lanceur ouvert n'est pas réinitialisé
                try {
                    root.appList = JSON.parse(raw);
                    root.lastAppsJson = raw;
                } catch (e) {}
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

        if ((m = raw.match(/.*>>>n?vim .*\/([^\/]+)$/))) return "\uf36f  Neovim — " + m[1];
        if ((m = raw.match(/.*>>>n?vim ([^\/]+)$/))) return "\uf36f  Neovim — " + m[1];
        if ((m = raw.match(/.*>>>(.*) [—-] N[Vv]im$/))) return "\uf36f  Neovim — " + m[1];

        if ((m = raw.match(/.*>>>(.*) [—-] Deezer/))) return "󰎆  Deezer — " + m[1];
        if (/.*>>>Deezer.*/.test(raw)) return "󰎆  Deezer";
        if ((m = raw.match(/.*[Dd]eezer.*>>>(.*)/))) return "󰎆  Deezer — " + m[1];

        if ((m = raw.match(/.*>>>antoine@[^:]*:.*\/([^\/]+)$/))) return "\uf489  Alacritty (" + m[1] + ")";
        if ((m = raw.match(/.*>>>antoine@[^:]*:(.*)/))) return "\uf489  Alacritty (" + m[1] + ")";

        if ((m = raw.match(/.*>>>(.*) [—-] (Discord|Vesktop)/))) return "󰙯  Discord — " + m[1];

        let fallback = title || appId || "";
        return fallback.length > 55 ? fallback.substring(0, 52) + "..." : fallback;
    }

    Component.onCompleted: {
        root.syncNetwork();
        root.syncBluetooth();
        root.syncAudio();
        root.syncBattery();
        ipPoller.running = true;
    }
}
