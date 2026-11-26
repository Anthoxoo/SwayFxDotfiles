pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Couleurs du thème global (~/.config/themes) : `theme set <id>` réécrit
// ~/.config/themes/current/palette.json, relu ici à chaud. Les valeurs par défaut
// (Orange Black) servent tant que le fichier est absent ou illisible.
//   qs ipc call theme set <id> | next | prev | get
Singleton {
    id: root

    readonly property string themesDir: Quickshell.env("HOME") + "/.config/themes"
    readonly property string themeBin: themesDir + "/theme"

    property var p: ({})
    property bool ready: false
    // Émis quand l'utilisateur change de thème (pas au démarrage) — voir Wallpapers.qml
    signal switched()

    readonly property string themeId: p.id || "orange-black"
    readonly property string name: p.name || "Orange Black"
    readonly property string backgrounds: p.backgrounds || ""

    // Surfaces
    readonly property color bgSolid: p.background || "#141416"
    readonly property color bg: alpha(bgSolid, p.panel_alpha ?? 0.95)
    // Barre translucide : swayfx floute ce qu'il y a dessous (layer_effects "qs-bar")
    readonly property color barBg: alpha(bgSolid, p.bar_alpha ?? 0.72)
    readonly property color bgInset: p.inset || "#0e0e10"
    readonly property color bgCard: p.surface || "#18181b"
    readonly property color rowHover: p.row_hover || "#1b1b1e"
    readonly property color hoverBg: p.hover || "#242428"
    readonly property color border: p.border || "#2a2a2c"
    readonly property color sep: p.separator || "#2e2e32"

    // Texte
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

    // --- Changement de thème -------------------------------------------------
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
            if (code !== 0) console.warn("theme: échec de `theme set` (code " + code + ")");
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
                    console.warn("theme: liste illisible");
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
                return; // fichier en cours d'écriture ou invalide : on garde l'ancien
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

    // Couleur avec opacité (0..1), pour les voiles et fonds translucides
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // --- Infobulles HTML (Text.RichText) : toutes les couleurs passent par le thème ---
    function hex(c) {
        return c.toString();
    }
    function tipSpan(c, text) {
        return "<span style='color:" + hex(c) + ";'>" + text + "</span>";
    }
    // Ligne de titre (accent)
    function tipTitle(text) {
        return tipSpan(accent, text);
    }
    // Ligne grisée (état inactif)
    function tipMuted(text) {
        return tipSpan(muted, text);
    }
    // Ligne "label   valeur" (label aligné sur `width` caractères)
    function tipRow(label, value, width) {
        return tipSpan(muted, String(label).padEnd(width || 8, " ")) + tipSpan(fg, value);
    }
    // Bloc monospace multi-lignes
    function tipBlock(lines) {
        return "<tt>" + lines.join("<br>") + "</tt>";
    }
}
