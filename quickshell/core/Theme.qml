pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Global theme colors (~/.config/themes): `theme set <id>` rewrites
// ~/.config/themes/current/palette.json, hot-reloaded here. The defaults
// (Orange Black) apply while the file is missing or unreadable.
//   qs ipc call theme set <id> | next | prev | get
Singleton {
    id: root

    readonly property string themesDir: Quickshell.env("HOME") + "/.config/themes"
    readonly property string themeBin: themesDir + "/theme"

    property var p: ({})
    property bool ready: false
    // Emitted when the user switches theme (not at startup) — see Wallpapers.qml
    signal switched()

    readonly property string themeId: p.id || "orange-black"
    readonly property string name: p.name || "Orange Black"
    readonly property string backgrounds: p.backgrounds || ""

    // Surfaces
    readonly property color bgSolid: p.background || "#141416"
    readonly property color bg: alpha(bgSolid, p.panel_alpha ?? 0.95)
    // Translucent bar: swayfx blurs what's underneath (layer_effects "qs-bar")
    readonly property color barBg: alpha(bgSolid, p.bar_alpha ?? 0.72)
    readonly property color bgInset: p.inset || "#0e0e10"
    readonly property color bgCard: p.surface || "#18181b"
    readonly property color rowHover: p.row_hover || "#1b1b1e"
    readonly property color hoverBg: p.hover || "#242428"
    readonly property color border: p.border || "#2a2a2c"
    readonly property color sep: p.separator || "#2e2e32"

    // Text
    readonly property color fg: p.foreground || "#e5e5e5"
    readonly property color subtle: p.subtle || "#b8b8bc"
    readonly property color win: p.dim || "#9a9a9e"
    readonly property color muted: p.muted || "#888888"
    readonly property color disabled: p.disabled || "#777777"
    readonly property color placeholder: p.placeholder || "#6e6e70"

    // Accents
    readonly property color accent: p.accent || "#ff8800"
    readonly property color onAccent: p.accent_fg || "#141416"
    readonly property color urgent: p.urgent || "#e05252"

    readonly property string fontMain: "JetBrainsMono Nerd Font"

    // --- Theme switching ------------------------------------------------------
    property var available: []   // [{id, name, accent, background, foreground, surface, border, colors[]}]
    property bool busy: false

    function set(tid) {
        if (!tid || busy) return;
        busy = true;
        setter.command = [root.themeBin, "set", tid];
        setter.running = true;
    }
    function refreshList() { lister.running = true; }

    Process {
        id: setter
        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0) console.warn("theme: `theme set` failed (code " + code + ")");
        }
    }

    Process {
        id: lister
        running: true
        command: [root.themeBin, "list", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.available = JSON.parse(text);
                } catch (e) {
                    console.warn("theme: unreadable theme list");
                }
            }
        }
    }

    FileView {
        id: paletteFile
        path: root.themesDir + "/current/palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let next;
            try {
                next = JSON.parse(text());
            } catch (e) {
                return; // file being written or invalid: keep the previous palette
            }
            let changed = root.ready && next.id !== root.p.id;
            root.p = next;
            root.ready = true;
            if (changed) root.switched();
        }
        onLoadFailed: err => root.ready = true
    }

    IpcHandler {
        target: "theme"

        function set(theme: string): void { root.set(theme); }
        function get(): string { return root.themeId; }
        function next(): void { root.step(1); }
        function prev(): void { root.step(-1); }
    }

    function step(delta) {
        let ids = available.map(t => t.id);
        if (ids.length === 0) return;
        let i = ids.indexOf(root.themeId);
        set(ids[(i + delta + ids.length) % ids.length]);
    }

    // Color with opacity (0..1), for veils and translucent backgrounds
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // --- HTML tooltips (Text.RichText): every color goes through the theme ---
    function hex(c) {
        return c.toString();
    }
    function tipSpan(c, text) {
        return "<span style='color:" + hex(c) + ";'>" + text + "</span>";
    }
    // Title line (accent)
    function tipTitle(text) {
        return tipSpan(accent, text);
    }
    // Greyed-out line (inactive state)
    function tipMuted(text) {
        return tipSpan(muted, text);
    }
    // "label   value" line (label padded to `width` characters)
    function tipRow(label, value, width) {
        return tipSpan(muted, String(label).padEnd(width || 8, " ")) + tipSpan(fg, value);
    }
    // Multi-line monospace block
    function tipBlock(lines) {
        return "<tt>" + lines.join("<br>") + "</tt>";
    }
}
