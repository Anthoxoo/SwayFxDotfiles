pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Fond d'écran dessiné par Quickshell (remplace swaybg) — voir modules/Wallpaper.qml
//   qs ipc call wallpaper next | prev | set <chemin> | get
// Le choix est mémorisé dans ~/.local/state/quickshell/wallpaper
// next/prev cycle through the current theme's wallpapers (Theme.backgrounds, else all of wallsDir);
// switching theme jumps to the new theme's first wallpaper.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallsDir: home + "/.config/walls"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/quickshell"
    readonly property string defaultWall: wallsDir + "/yellow-orange-ish/wall_secondary.png"
    readonly property string dir: Theme.backgrounds !== "" ? Theme.backgrounds : wallsDir

    property string current: ""
    property var list: []
    property bool relistPending: false
    property bool themeSwitchPending: false

    function relist() {
        if (lister.running) root.relistPending = true;
        else lister.running = true;
    }

    onDirChanged: relist()

    Connections {
        target: Theme
        function onSwitched() {
            root.themeSwitchPending = true;
            root.relist();
        }
    }

    // URL file:// sûre (espaces, #, ? dans les noms de fichiers)
    function toUrl(path) {
        if (!path) return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    readonly property string currentUrl: toUrl(current)

    function set(path) {
        if (!path || path === root.current) return;
        root.current = path;
        stateView.setText(path + "\n");
    }

    function step(delta) {
        if (root.list.length === 0) return;
        let idx = root.list.indexOf(root.current);
        let next = idx < 0 ? 0 : (idx + delta + root.list.length) % root.list.length;
        root.set(root.list[next]);
    }

    function next() { step(1); }
    function prev() { step(-1); }

    // Liste des images (rafraîchie à chaque changement, pour voir les nouveaux fichiers)
    Process {
        id: lister
        running: true
        command: ["sh", "-c", "find -L \"$1\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort", "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.split("\n").filter(l => l.trim() !== "");
                if (root.themeSwitchPending && !root.relistPending) {
                    root.themeSwitchPending = false;
                    if (root.list.length > 0 && root.list.indexOf(root.current) < 0)
                        root.set(root.list[0]);
                }
            }
        }
        onExited: {
            if (root.relistPending) {
                root.relistPending = false;
                running = true;
            }
        }
    }

    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
    }

    FileView {
        id: stateView
        path: root.stateDir + "/wallpaper"
        printErrors: false
        onLoaded: {
            let p = text().trim();
            root.current = p !== "" ? p : root.defaultWall;
        }
        onLoadFailed: err => {
            if (root.current === "") root.current = root.defaultWall;
        }
    }

    IpcHandler {
        target: "wallpaper"

        function next(): void { root.relist(); root.next(); }
        function prev(): void { root.relist(); root.prev(); }
        function set(path: string): void { root.set(path); }
        function get(): string { return root.current; }
    }
}
