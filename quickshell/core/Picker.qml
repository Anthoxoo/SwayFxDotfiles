pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Color picker: the bar's eyedropper (modules/ColorPickerButton.qml) or
// `qs ipc call colorpicker pick` freezes the screens (grim), modules/ColorPicker.qml shows a loupe,
// a click copies the pixel's color (#rrggbb, or rgb(r, g, b) with Shift) and notifies.
// The last colors are kept in ~/.local/state/quickshell/colors (newest first).
Singleton {
    id: root

    property bool active: false   // freezing or picking
    property bool shown: false    // frozen screens ready: overlays visible
    property int stamp: 0         // in the frozen files' names: a new pick never shows an old one
    property var history: []      // "#rrggbb", newest first

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string dir: runtimeDir + "/qs-colorpicker"
    readonly property string stateFile: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell/colors"
    readonly property int historySize: 8

    function frozen(screenName) {
        return dir + "/" + screenName + "-" + stamp + ".ppm";
    }

    function start() {
        if (active || SysState.screenLocked) return;
        SysState.closeAllPopups();
        active = true;
        shown = false;
        stamp++;
        freezer.command = ["sh", "-c",
            'd=$1; s=$2; shift 2; rm -rf "$d"; mkdir -p -m 700 "$d"; for o; do grim -t ppm -o "$o" "$d/$o-$s.ppm" & done; wait',
            "sh", dir, String(stamp)].concat(Quickshell.screens.map(s => s.name));
        freezer.running = true;
    }

    function cancel() {
        active = false;
        shown = false;
        cleaner.startDetached();
    }

    // r, g, b: 0-255
    function hexOf(r, g, b) {
        return "#" + [r, g, b].map(v => (v < 16 ? "0" : "") + v.toString(16)).join("");
    }
    function rgbOf(r, g, b) {
        return "rgb(" + r + ", " + g + ", " + b + ")";
    }

    function picked(r, g, b, asRgb) {
        let hex = hexOf(r, g, b);
        cancel();
        remember(hex);
        let rgb = rgbOf(r, g, b);
        copy(asRgb ? rgb : hex, hex, asRgb ? hex : rgb);
    }

    // The last color, copied again (the bar button's right click)
    function recopy() {
        if (history.length === 0) return;
        let hex = history[0], n = parseInt(hex.slice(1), 16);
        copy(hex, hex, rgbOf((n >> 16) & 255, (n >> 8) & 255, n & 255));
    }

    function remember(hex) {
        let h = [hex].concat(history.filter(c => c !== hex)).slice(0, historySize);
        history = h;
        historyFile.setText(h.join("\n") + "\n");
    }

    // Copies text, then notifies with a swatch of the color (ImageMagick; no swatch without it)
    // and the other notation in the body
    function copy(text, hex, other) {
        notifier.command = ["sh", "-c",
            'printf %s "$1" | wl-copy; sw="$3/qs-colorpicker-swatch.png"; ' +
            'command -v magick >/dev/null && magick -size 64x64 "xc:$2" "$sw" 2>/dev/null || sw=color-select; ' +
            'notify-send -a "color picker" -i "$sw" "$1 copied" "$4"',
            "sh", text, hex, runtimeDir, other];
        notifier.startDetached();
    }

    Process {
        id: freezer
        onExited: code => {
            if (!root.active) return;
            if (code === 0) {
                root.shown = true;
            } else {
                root.active = false;
                failNotifier.startDetached();
            }
        }
    }
    Process {
        id: failNotifier
        command: ["notify-send", "-a", "color picker", "color picker failed", "grim couldn't capture the screens"]
    }
    Process {
        id: cleaner
        command: ["rm", "-rf", root.dir]
    }
    Process {
        id: notifier
    }

    FileView {
        id: historyFile
        path: root.stateFile
        printErrors: false
        onLoaded: root.history = text().split("\n").filter(l => /^#[0-9a-f]{6}$/.test(l)).slice(0, root.historySize)
    }

    IpcHandler {
        target: "colorpicker"
        function pick(): void { root.start(); }
        function cancel(): void { if (root.active) root.cancel(); }
        function last(): string { return root.history.length > 0 ? root.history[0] : ""; }
    }
}
