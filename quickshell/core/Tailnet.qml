pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale for the bar (modules/Tailscale.qml) and its menu (modules/TailscaleMenu.qml), read from
// `tailscale status --json`: every 20 s, every 3 s while the menu is open.
// Turning it on/off needs the daemon's operator rights, given once with
// `sudo tailscale set --operator=$USER`; without them the menu says so.
Singleton {
    id: root

    property bool installed: true   // false when there is no tailscale CLI
    // BackendState: Running, Stopped, NeedsLogin, NeedsMachineAuth, Starting, NoState;
    // "" while tailscaled doesn't answer
    property string backend: ""
    readonly property bool running: backend === "Running"
    readonly property bool loggedOut: backend === "NeedsLogin" || backend === "NeedsMachineAuth"
    property var self: null         // see node()
    property var peers: []          // online first, then by name
    property var health: []         // tailscaled's warnings
    property string authUrl: ""
    property string exitNode: ""    // name of the exit node in use
    property bool busy: false       // up/down running
    property string error: ""       // why the last up/down failed: "denied" or tailscale's message
    property string copied: ""      // what was just copied (the menu flashes it)
    property real anchorX: -1       // center of the bar module (menu anchor), -1: unknown

    readonly property int onlineCount: peers.filter(p => p.online).length
    readonly property string stateText: {
        if (!installed) return "not installed";
        if (busy) return running ? "disconnecting…" : "connecting…";
        switch (backend) {
        case "Running": return "connected";
        case "Stopped": return "disconnected";
        case "Starting": return "connecting…";
        case "NeedsLogin": return "logged out";
        case "NeedsMachineAuth": return "waiting for approval";
        case "": return "tailscaled not running";
        default: return backend.toLowerCase();
        }
    }
    readonly property string deniedHint: "sudo tailscale set --operator=$USER"

    function refresh() {
        if (!installed) return;
        if (status.running) status.again = true;
        else status.running = true;
    }

    function setRunning(on) {
        if (busy || !installed || backend === "") return;
        busy = true;
        error = "";
        // Exit code on the first line, then what tailscale said (read once the output ends)
        upDown.command = ["sh", "-c", 'out=$(tailscale "$1" 2>&1); c=$?; printf "%s\\n%s" "$c" "$out"', "sh", on ? "up" : "down"];
        upDown.running = true;
    }
    function toggle() {
        if (loggedOut) login();
        else setRunning(!running);
    }

    // The login URL when tailscaled already has one, else `tailscale login` in a terminal
    // (with sudo when this user isn't the operator)
    function login() {
        if (authUrl !== "") {
            opener.command = ["xdg-open", authUrl];
        } else {
            opener.command = ["alacritty", "--title", "tailscale login", "-e", "sh", "-c",
                'tailscale login 2>/dev/null || sudo tailscale login; printf "\\n[enter] close"; read -r _'];
        }
        opener.startDetached();
    }

    function copy(text) {
        if (!text) return;
        copier.command = ["sh", "-c", 'printf %s "$1" | wl-copy', "sh", text];
        copier.startDetached();
        copied = text;
        copiedTimer.restart();
    }

    // "2026-11-27T14:45:30.1Z" → "1d ago"; "" for an unknown time
    function ago(iso) {
        let t = Date.parse(String(iso || "").replace(/\.\d+/, ""));
        if (!(t > 0)) return "";
        let s = Math.max(0, (Date.now() - t) / 1000);
        if (s < 90) return "just now";
        if (s < 5400) return Math.round(s / 60) + "m ago";
        if (s < 129600) return Math.round(s / 3600) + "h ago";
        return Math.round(s / 86400) + "d ago";
    }

    function node(n) {
        let dns = (n.DNSName || "").replace(/\.$/, "");
        let ips = n.TailscaleIPs || [];
        return {
            name: dns.split(".")[0] || n.HostName || "?",
            dns: dns,
            os: n.OS || "",
            ipv4: ips.find(ip => ip.indexOf(":") < 0) || "",
            ipv6: ips.find(ip => ip.indexOf(":") >= 0) || "",
            online: n.Online === true,
            lastSeen: n.LastSeen || "",
            exitNode: n.ExitNode === true
        };
    }

    function apply(json) {
        let d;
        try {
            d = JSON.parse(json);
        } catch (e) {
            return;
        }
        backend = d.BackendState || "NoState";
        authUrl = d.AuthURL || "";
        health = d.Health || [];
        self = d.Self && d.Self.HostName ? node(d.Self) : null;
        let list = Object.values(d.Peer || {}).map(node);
        list.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name));
        peers = list;
        let exit = list.find(p => p.exitNode);
        exitNode = exit ? exit.name : "";
    }

    Timer {
        interval: !root.installed ? 300000 : (SysState.tailscaleMenuOpen ? 3000 : 20000)
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    // Faster when the menu opens
    Connections {
        target: SysState
        function onTailscaleMenuOpenChanged() {
            if (SysState.tailscaleMenuOpen) root.refresh();
        }
    }

    Process {
        id: status
        property bool again: false
        command: ["sh", "-c", 'command -v tailscale >/dev/null || exit 127; exec tailscale status --json']
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
        onExited: code => {
            root.installed = code !== 127;
            if (code !== 0) {
                root.backend = "";
                root.self = null;
                root.peers = [];
                root.health = [];
                root.exitNode = "";
            }
            if (again) {
                again = false;
                running = true;
            }
        }
    }

    Process {
        id: upDown
        stdout: StdioCollector {
            onStreamFinished: root.upDownDone(text)
        }
    }
    function upDownDone(out) {
        busy = false;
        let lines = out.split("\n");
        if (parseInt(lines[0]) !== 0) {
            let msg = lines.slice(1).join("\n").trim();
            error = /access denied|permission denied|operator/i.test(msg) ? "denied" : (msg.split("\n")[0] || "tailscale failed");
            // The menu shows the error; from IPC, a notification does
            if (!SysState.tailscaleMenuOpen) {
                notifier.command = ["notify-send", "-a", "tailscale", "-i", "network-vpn", "tailscale failed",
                    error === "denied" ? "Allow your user once: " + deniedHint : error];
                notifier.startDetached();
            }
        }
        refresh();
    }

    Process {
        id: copier
    }
    Process {
        id: opener
    }
    Process {
        id: notifier
    }
    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: root.copied = ""
    }

    IpcHandler {
        target: "tailscale"
        function up(): void { root.setRunning(true); }
        function down(): void { root.setRunning(false); }
        function toggle(): void { root.toggle(); }
        function status(): string { return root.stateText; }
        function ip(): string { return root.self ? root.self.ipv4 : ""; }
    }
}
