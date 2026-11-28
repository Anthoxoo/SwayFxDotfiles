pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper drawn by Quickshell (replaces swaybg) — see modules/Wallpaper.qml; picked in the
// theme menu (modules/ThemeMenu.qml: Super+Shift+T, then a theme; Super+Ctrl+W goes straight
// to the current theme's wallpapers).
//   qs ipc call wallpaper next | prev | set <path> | get
// next/prev cycle through the current theme's wallpapers (Theme.backgrounds, else all of wallsDir).
// Each theme remembers its last wallpaper: switching theme brings it back (the theme's first
// wallpaper the first time).
// State: ~/.local/state/quickshell/wallpaper (current) and wallpaper-by-theme.json (per theme).
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallsDir: home + "/.config/walls"
    readonly property string thumbsScript: home + "/.config/quickshell/scripts/wall-thumbs.py"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/quickshell"
    readonly property string defaultWall: wallsDir + "/gruvbox/wall_secondary.png"
    readonly property string dir: Theme.backgrounds !== "" ? Theme.backgrounds : wallsDir

    property string current: ""
    property var list: []
    property var byTheme: ({})   // theme id -> last wallpaper picked with that theme
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

    // Safe file:// URL (spaces, # and ? in file names)
    function toUrl(path) {
        if (!path) return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    readonly property string currentUrl: toUrl(current)

    // tid: the theme this wallpaper is picked for (the picker can pick one for a theme that is
    // still being applied); by default the current theme, if the wallpaper is one of its own.
    function set(path, tid) {
        if (!path) return;
        if (!tid && root.list.indexOf(path) >= 0) tid = Theme.themeId;
        if (tid && root.byTheme[tid] !== path) {
            let m = Object.assign({}, root.byTheme);
            m[tid] = path;
            root.byTheme = m;
            memoryView.setText(JSON.stringify(m, null, 1) + "\n");
        }
        if (path === root.current) return;
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

    // Image list (re-read on every change, to see new files). Paths are always
    // ~/.config/walls/<id>/<file>, whatever links lead there (see scripts/wall-thumbs.py).
    Process {
        id: lister
        running: true
        command: ["python3", root.thumbsScript, "paths", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.list = text.split("\n").filter(l => l.trim() !== "");
                if (root.themeSwitchPending && !root.relistPending) {
                    root.themeSwitchPending = false;
                    // Already one of the new theme's (picked in the menu during the switch): keep it
                    if (root.list.length > 0 && root.list.indexOf(root.current) < 0) {
                        let saved = root.byTheme[Theme.themeId];
                        root.set(root.list.indexOf(saved) >= 0 ? saved : root.list[0]);
                    }
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

    // Thumbnails for the picker, made in the background at startup (instant when cached)
    Process {
        running: true
        command: ["nice", "-n", "19", "python3", root.thumbsScript, "warm",
            root.wallsDir, root.home + "/.config/themes"]
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

    FileView {
        id: memoryView
        path: root.stateDir + "/wallpaper-by-theme.json"
        printErrors: false
        watchChanges: true   // can be edited by hand (e.g. to forget a theme's wallpaper)
        onFileChanged: reload()
        onLoaded: {
            try {
                root.byTheme = JSON.parse(text()) || {};
            } catch (e) {
                root.byTheme = {};
            }
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
