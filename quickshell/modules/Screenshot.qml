import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

// Screenshot tool (replaces slurp): the screens are frozen (grim, before anything shows), then
// pick a region (drag), a window or a whole screen (click). sway/scripts/screenshot.sh crops the
// frozen screen, saves the shot (~/Pictures/Screenshots), copies it and notifies
// (open / edit / delete); with "edit" on, swappy opens first.
//   qs ipc call screenshot open <region|window|screen> <edit: true|false> | cancel
// Print: region + edit, Super+Shift+S: region, Ctrl+Print: window
// (Shift+Print takes the focused screen right away: screenshot.sh output, no overlay).
// In the overlay: r / w / s switch mode, e toggles edit, Enter takes the highlighted window or
// screen, Escape (or a right click) cancels.
Scope {
    id: root

    property bool active: false   // freezing or selecting
    property bool shown: false    // frozen screens ready: overlays visible
    property string mode: "region"
    property bool edit: false
    property var windows: []      // visible windows {x, y, w, h, label}, sway layout coordinates
    property int stamp: 0         // in the frozen files' names: a new capture never shows an old one

    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-screenshot"
    readonly property string script: Quickshell.env("HOME") + "/.config/sway/scripts/screenshot.sh"
    readonly property var modes: [
        { id: "region", icon: "󰆞", key: "r" },
        { id: "window", icon: "󰖯", key: "w" },
        { id: "screen", icon: "󰍹", key: "s" }
    ]

    function frozen(screenName) {
        return dir + "/" + screenName + "-" + stamp + ".ppm";
    }

    function open(m, e) {
        if (SysState.screenLocked) return;
        if (active) {
            setMode(m);
            return;
        }
        mode = modes.some(x => x.id === m) ? m : "region";
        edit = e;
        active = true;
        shown = false;
        stamp++;
        // Every screen at once, before the overlay maps (so it isn't in the shot)
        freezer.command = ["sh", "-c",
            'd=$1; s=$2; shift 2; rm -rf "$d"; mkdir -p -m 700 "$d"; for o; do grim -t ppm -o "$o" "$d/$o-$s.ppm" & done; wait',
            "sh", dir, String(stamp)].concat(Quickshell.screens.map(s => s.name));
        freezer.running = true;
        tree.running = true;
    }

    function setMode(m) {
        if (modes.some(x => x.id === m)) mode = m;
    }

    function cancel() {
        active = false;
        shown = false;
        cleaner.startDetached();
    }

    // geometry: "WxH+X+Y" in the frozen image's pixels, or "full"
    function take(screenName, geometry) {
        let src = frozen(screenName);
        active = false;
        shown = false;
        saver.command = [script, "save", src, geometry, edit ? "edit" : ""];
        saver.startDetached();
    }

    Process {
        id: freezer
        onExited: code => {
            if (!root.active) return;
            if (code === 0) {
                root.shown = true;
            } else {
                root.active = false;
                notifyFail.startDetached();
            }
        }
    }
    Process {
        id: notifyFail
        command: ["notify-send", "-a", "screenshot", "screenshot failed", "grim couldn't capture the screens"]
    }
    Process {
        id: cleaner
        command: ["rm", "-rf", root.dir]
    }
    Process {
        id: saver
    }

    // Visible windows (tiled, then floating: the last match under the pointer is the top one)
    Process {
        id: tree
        command: ["swaymsg", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = [];
                let walk = n => {
                    if (n.pid && n.visible && n.rect)
                        out.push({
                            x: n.rect.x, y: n.rect.y, w: n.rect.width, h: n.rect.height,
                            label: n.name || n.app_id || ""
                        });
                    (n.nodes || []).forEach(walk);
                    (n.floating_nodes || []).forEach(walk);
                };
                try {
                    walk(JSON.parse(text));
                } catch (e) {}
                root.windows = out;
            }
        }
    }

    IpcHandler {
        target: "screenshot"
        function open(mode: string, edit: bool): void { root.open(mode, edit); }
        function cancel(): void { if (root.active) root.cancel(); }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: root.shown
            focusable: true
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "qs-screenshot"
            exclusionMode: ExclusionMode.Ignore
            color: "black"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            onVisibleChanged: {
                dragRect = Qt.rect(0, 0, 0, 0);
                dragging = false;
                if (visible) keys.forceActiveFocus();
            }

            // The frozen screen, under everything
            Image {
                id: frozenImg
                anchors.fill: parent
                source: root.shown ? "file://" + root.frozen(win.modelData.name) : ""
                cache: false
                smooth: false
            }
            // Image pixels per window pixel (output scale)
            readonly property real px: frozenImg.implicitWidth > 0 ? frozenImg.implicitWidth / width : 1

            // --- What would be taken ----------------------------------------------
            property rect dragRect: Qt.rect(0, 0, 0, 0)
            property bool dragging: false
            property point dragFrom: Qt.point(0, 0)

            // Window under the pointer, in this screen's coordinates (clipped to it)
            readonly property var hoverWin: {
                if (root.mode !== "window" || !mouse.containsMouse) return null;
                let gx = mouse.mouseX + modelData.x, gy = mouse.mouseY + modelData.y;
                for (let i = root.windows.length - 1; i >= 0; i--) {
                    let w = root.windows[i];
                    if (gx < w.x || gy < w.y || gx >= w.x + w.w || gy >= w.y + w.h) continue;
                    let x = Math.max(0, w.x - modelData.x), y = Math.max(0, w.y - modelData.y);
                    let r = Math.min(width, w.x - modelData.x + w.w), b = Math.min(height, w.y - modelData.y + w.h);
                    return { rect: Qt.rect(x, y, r - x, b - y), label: w.label };
                }
                return null;
            }

            readonly property rect sel: {
                if (root.mode === "region") return dragRect;
                if (root.mode === "window") return hoverWin ? hoverWin.rect : Qt.rect(0, 0, 0, 0);
                return mouse.containsMouse ? Qt.rect(0, 0, width, height) : Qt.rect(0, 0, 0, 0);
            }
            readonly property bool hasSel: sel.width > 0 && sel.height > 0
            readonly property string selLabel: {
                let size = Math.round(sel.width * px) + " × " + Math.round(sel.height * px);
                if (root.mode === "window" && hoverWin && hoverWin.label) return hoverWin.label + "  ·  " + size;
                if (root.mode === "screen") return modelData.name + "  ·  " + size;
                return size;
            }

            function capture() {
                if (!hasSel) return;
                let x = Math.round(sel.x * px), y = Math.round(sel.y * px);
                let w = Math.round(sel.width * px), h = Math.round(sel.height * px);
                let full = x === 0 && y === 0 && w >= frozenImg.implicitWidth && h >= frozenImg.implicitHeight;
                root.take(modelData.name, full ? "full" : w + "x" + h + "+" + x + "+" + y);
            }

            // --- Veil outside the selection ---------------------------------------
            readonly property color veil: Theme.alpha("#000000", 0.45)
            Rectangle {
                color: win.veil
                width: parent.width
                height: win.hasSel ? win.sel.y : parent.height
            }
            Rectangle {
                visible: win.hasSel
                color: win.veil
                y: win.sel.y + win.sel.height
                width: parent.width
                height: parent.height - y
            }
            Rectangle {
                visible: win.hasSel
                color: win.veil
                y: win.sel.y
                width: win.sel.x
                height: win.sel.height
            }
            Rectangle {
                visible: win.hasSel
                color: win.veil
                x: win.sel.x + win.sel.width
                y: win.sel.y
                width: parent.width - x
                height: win.sel.height
            }
            Rectangle {
                visible: win.hasSel
                x: win.sel.x
                y: win.sel.y
                width: win.sel.width
                height: win.sel.height
                color: "transparent"
                border.color: Theme.accent
                border.width: 2
            }

            // Size (and window / screen name) under the selection, or inside it at the bottom edge
            Rectangle {
                visible: win.hasSel && (root.mode !== "region" || win.sel.width >= 3)
                readonly property bool inside: win.sel.y + win.sel.height + height + 8 > win.height
                x: Math.min(win.sel.x, win.width - width)
                y: inside ? win.sel.y + win.sel.height - height - 6 : win.sel.y + win.sel.height + 6
                width: Math.min(selText.implicitWidth + 16, win.width)
                height: 24
                color: Theme.bgSolid
                border.color: Theme.border
                border.width: 1
                Text {
                    id: selText
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    text: win.selLabel
                    elide: Text.ElideMiddle
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    color: Theme.fg
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: root.mode === "region" ? Qt.CrossCursor : Qt.PointingHandCursor
                onPressed: event => {
                    if (event.button === Qt.RightButton) {
                        root.cancel();
                    } else if (root.mode === "region") {
                        win.dragging = true;
                        win.dragFrom = Qt.point(event.x, event.y);
                        win.dragRect = Qt.rect(event.x, event.y, 0, 0);
                    }
                }
                onPositionChanged: event => {
                    if (!win.dragging) return;
                    let x = Math.max(0, Math.min(event.x, win.width)), y = Math.max(0, Math.min(event.y, win.height));
                    win.dragRect = Qt.rect(Math.min(x, win.dragFrom.x), Math.min(y, win.dragFrom.y),
                        Math.abs(x - win.dragFrom.x), Math.abs(y - win.dragFrom.y));
                }
                onReleased: event => {
                    if (event.button !== Qt.LeftButton) return;
                    if (root.mode === "region") {
                        win.dragging = false;
                        if (win.dragRect.width >= 3 && win.dragRect.height >= 3) win.capture();
                        else win.dragRect = Qt.rect(0, 0, 0, 0);
                    } else {
                        win.capture();
                    }
                }
            }

            Item {
                id: keys
                focus: true
                Keys.onPressed: event => {
                    let k = event.key;
                    if (k === Qt.Key_Escape) root.cancel();
                    else if (k === Qt.Key_R) root.setMode("region");
                    else if (k === Qt.Key_W) root.setMode("window");
                    else if (k === Qt.Key_S) root.setMode("screen");
                    else if (k === Qt.Key_E) root.edit = !root.edit;
                    else if ((k === Qt.Key_Return || k === Qt.Key_Enter) && root.mode !== "region") win.capture();
                    else return;
                    event.accepted = true;
                }
            }

            // --- Toolbar ------------------------------------------------------------
            Rectangle {
                id: toolbar
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 40
                width: bar.implicitWidth + 16
                height: bar.implicitHeight + 12
                color: Theme.bgSolid
                border.color: Theme.accent
                border.width: 1
                opacity: win.dragging ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 120 } }

                // The toolbar's own clicks don't start a selection
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                }

                RowLayout {
                    id: bar
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: root.modes
                        delegate: Rectangle {
                            id: modeBtn
                            required property var modelData
                            readonly property bool isOn: root.mode === modelData.id
                            implicitWidth: modeRow.implicitWidth + 20
                            implicitHeight: 30
                            color: isOn ? Theme.hoverBg : (modeMouse.containsMouse ? Theme.rowHover : "transparent")
                            Rectangle {
                                visible: modeBtn.isOn
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 2
                                color: Theme.accent
                            }
                            Row {
                                id: modeRow
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: modeBtn.modelData.icon
                                    font.family: Theme.fontMain
                                    font.pixelSize: 15
                                    color: modeBtn.isOn ? Theme.accent : Theme.fg
                                }
                                Text {
                                    text: modeBtn.modelData.id
                                    font.family: Theme.fontMain
                                    font.pixelSize: 13
                                    color: modeBtn.isOn ? Theme.accent : Theme.fg
                                }
                                Text {
                                    text: modeBtn.modelData.key
                                    font.family: Theme.fontMain
                                    font.pixelSize: 11
                                    color: Theme.placeholder
                                }
                            }
                            MouseArea {
                                id: modeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setMode(modeBtn.modelData.id)
                            }
                        }
                    }

                    Rectangle {
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        implicitWidth: 1
                        implicitHeight: 20
                        color: Theme.sep
                    }

                    // Open the shot in swappy (annotate) before saving it
                    Rectangle {
                        implicitWidth: editRow.implicitWidth + 20
                        implicitHeight: 30
                        color: root.edit ? Theme.hoverBg : (editMouse.containsMouse ? Theme.rowHover : "transparent")
                        Row {
                            id: editRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: root.edit ? "󰄵" : "󰄱"
                                font.family: Theme.fontMain
                                font.pixelSize: 15
                                color: root.edit ? Theme.accent : Theme.muted
                            }
                            Text {
                                text: "edit"
                                font.family: Theme.fontMain
                                font.pixelSize: 13
                                color: root.edit ? Theme.accent : Theme.fg
                            }
                            Text {
                                text: "e"
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                color: Theme.placeholder
                            }
                        }
                        MouseArea {
                            id: editMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.edit = !root.edit
                        }
                    }

                    Text {
                        Layout.leftMargin: 8
                        Layout.rightMargin: 4
                        text: "esc cancel"
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        color: Theme.placeholder
                    }
                }
            }
        }
    }
}
