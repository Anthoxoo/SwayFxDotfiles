import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

// Global theme and wallpaper picker (~/.config/themes, ~/.config/walls), in two steps:
//  1. themes: ↑/↓ (or j/k) to choose, Enter applies the theme and moves on to its wallpapers
//  2. wallpapers: arrows (or h/j/k/l) to choose, Enter applies, Backspace goes back to the themes
// Escape closes, from either step.
//   $mod+Shift+t / `qs ipc call shell toggle theme`       opens on the themes
//   $mod+Ctrl+w  / `qs ipc call shell toggle wallpaper`   opens on the current theme's wallpapers
// Thumbnails: scripts/wall-thumbs.py (cached in ~/.cache/quickshell/wallthumbs).
PanelWindow {
    id: themeWin

    visible: SysState.themeMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-theme-menu"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property var themes: Theme.available
    property string view: "themes"   // "themes" | "walls"
    property int selectedIndex: 0    // in the theme list

    // Wallpaper step: the theme whose wallpapers are shown, and the selection in its grid
    property string wallTheme: ""
    readonly property string wallThemeName: (themes.find(t => t.id === wallTheme) || { name: wallTheme }).name
    property int wallIndex: 0
    property int wallTotal: 0        // images in the theme's folder (the grid fills in up to it)
    property bool wallPicked: false  // the selection was set from the current wallpaper

    readonly property int cellW: 210  // a 200×125 thumbnail and its gap
    readonly property int cellH: 135
    readonly property int wallCols: Math.max(2, Math.min(4, wallTotal))
    readonly property int wallRows: Math.ceil(Math.max(1, wallTotal) / wallCols)

    // Hover selects only once the pointer has really moved: Qt also sends hover events when the
    // panel opens (or changes step) under a pointer that stays still, which would override the
    // keyboard selection with whatever happens to be under it.
    property var hoverOrigin: null
    property bool hoverLive: false
    function hovered(item, x, y) {
        if (hoverLive) return true;
        let p = item.mapToItem(null, x, y);
        if (hoverOrigin === null) {
            hoverOrigin = p;
            return false;
        }
        if (Math.abs(p.x - hoverOrigin.x) + Math.abs(p.y - hoverOrigin.y) < 3) return false;
        hoverLive = true;
        return true;
    }
    function resetHover() {
        hoverOrigin = null;
        hoverLive = false;
    }
    onViewChanged: resetHover()

    function selectCurrent() {
        selectedIndex = Math.max(0, themes.findIndex(t => t.id === Theme.themeId));
    }
    // The list is re-read on every opening (new themes): reselect the active theme
    onThemesChanged: if (visible && view === "themes") selectCurrent()

    onVisibleChanged: {
        if (!visible) return;
        resetHover();
        Theme.refreshList();
        selectCurrent();
        if (SysState.themeMenuWalls) showWalls(Theme.themeId);
        else view = "themes";
        keyCatcher.forceActiveFocus();
        focusRetry.restart();
    }

    Timer {
        id: focusRetry
        interval: 25
        onTriggered: if (themeWin.visible) keyCatcher.forceActiveFocus()
    }

    // Step 1 -> 2: apply the theme (unless it is the current one), then show its wallpapers
    function pickTheme(i) {
        if (i < 0 || i >= themes.length || Theme.busy) return;
        let tid = themes[i].id;
        if (tid !== Theme.themeId) Theme.set(tid);
        showWalls(tid);
    }

    function showWalls(tid) {
        wallTheme = tid;
        wallIndex = 0;
        wallTotal = 0;
        wallPicked = false;
        walls.clear();
        let cmd = ["python3", Wallpapers.thumbsScript, "list", Theme.themesDir + "/" + tid + "/backgrounds"];
        if (wallLister.running) {
            // Still listing another theme (thumbnails being made): stop it, then start (onExited)
            wallLister.pendingCommand = cmd;
            wallLister.running = false;
        } else {
            wallLister.command = cmd;
            wallLister.running = true;
        }
        view = "walls";
    }

    function back() {
        view = "themes";
        selectedIndex = Math.max(0, themes.findIndex(t => t.id === wallTheme));
    }

    function applyWall(i) {
        if (i < 0 || i >= walls.count) return;
        Wallpapers.set(walls.get(i).path, wallTheme);
    }

    // ←/→ go round the whole grid; ↑/↓ stop at the edges (↓ from a full row above a shorter
    // last row lands on its last thumbnail)
    function moveWall(dx, dy) {
        let n = walls.count;
        if (n === 0) return;
        let i = wallIndex;
        if (dx !== 0) {
            i = (i + dx + n) % n;
        } else {
            let to = i + dy * wallCols;
            if (to >= n && Math.floor(i / wallCols) < Math.floor((n - 1) / wallCols)) to = n - 1;
            if (to >= 0 && to < n) i = to;
        }
        wallIndex = i;
    }

    onWallIndexChanged: grid.positionViewAtIndex(wallIndex, GridView.Contain)

    ListModel {
        id: walls   // {path, thumb}
    }

    // First line: how many images; then "<image>\t<thumbnail>" per image, as thumbnails are ready
    Process {
        id: wallLister
        property var pendingCommand: null
        onExited: {
            if (!pendingCommand) return;
            command = pendingCommand;
            pendingCommand = null;
            running = true;
        }
        stdout: SplitParser {
            onRead: line => {
                if (wallLister.pendingCommand) return;  // the previous theme's last lines
                let tab = line.indexOf("\t");
                if (tab < 0) {
                    themeWin.wallTotal = parseInt(line) || 0;
                    return;
                }
                let path = line.slice(0, tab);
                walls.append({ path: path, thumb: line.slice(tab + 1) });
                // Start on the current wallpaper, else the one this theme had last time
                if (path === Wallpapers.current) {
                    themeWin.wallIndex = walls.count - 1;
                    themeWin.wallPicked = true;
                } else if (!themeWin.wallPicked && path === Wallpapers.byTheme[themeWin.wallTheme]) {
                    themeWin.wallIndex = walls.count - 1;
                }
            }
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            let k = event.key;
            if (k === Qt.Key_Escape) {
                SysState.themeMenuOpen = false;
            } else if (themeWin.view === "walls") {
                if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) themeWin.moveWall(-1, 0);
                else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab) themeWin.moveWall(1, 0);
                else if (k === Qt.Key_Up || k === Qt.Key_K) themeWin.moveWall(0, -1);
                else if (k === Qt.Key_Down || k === Qt.Key_J) themeWin.moveWall(0, 1);
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) themeWin.applyWall(themeWin.wallIndex);
                else if (k === Qt.Key_Backspace) themeWin.back();
                else return;
            } else {
                let n = themeWin.themes.length;
                if (n > 0 && (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab))
                    themeWin.selectedIndex = (themeWin.selectedIndex + 1) % n;
                else if (n > 0 && (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab))
                    themeWin.selectedIndex = (themeWin.selectedIndex - 1 + n) % n;
                else if (k === Qt.Key_Return || k === Qt.Key_Enter) themeWin.pickTheme(themeWin.selectedIndex);
                else return;
            }
            event.accepted = true;
        }
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onPressed: SysState.themeMenuOpen = false
    }

    Rectangle {
        id: panel
        readonly property bool walled: themeWin.view === "walls"
        width: walled ? themeWin.wallCols * themeWin.cellW + 10 : 340
        height: (walled ? wallCol.implicitHeight : themeCol.implicitHeight) + 20
        anchors.centerIn: parent
        clip: true
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1

        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onPressed: keyCatcher.forceActiveFocus()
        }

        // --- Step 1: themes ---------------------------------------------------
        ColumnLayout {
            id: themeCol
            x: 10
            y: 10
            width: 320
            spacing: 4
            opacity: panel.walled ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                text: "󰏘   theme" + (Theme.busy ? "  …" : "")
                font.family: Theme.fontMain
                font.pixelSize: 15
                color: Theme.accent
            }

            Text {
                visible: themeWin.themes.length === 0
                text: "no theme in ~/.config/themes"
                font.family: Theme.fontMain
                font.pixelSize: 13
                color: Theme.muted
            }

            Repeater {
                model: themeWin.themes
                delegate: Rectangle {
                    id: row
                    required property int index
                    required property var modelData
                    readonly property bool isSelected: index === themeWin.selectedIndex
                    readonly property bool isCurrent: modelData.id === Theme.themeId

                    Layout.fillWidth: true
                    implicitHeight: 44
                    color: isSelected ? Theme.hoverBg : "transparent"

                    Rectangle {
                        visible: row.isSelected
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width: 2
                        color: Theme.accent
                    }

                    // Preview: background, accent, then the theme's red/green/yellow/blue/magenta/cyan
                    Rectangle {
                        id: preview
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 92
                        height: 26
                        color: row.modelData.background
                        border.color: row.modelData.border
                        border.width: 1

                        Row {
                            anchors.centerIn: parent
                            spacing: 3
                            Rectangle {
                                width: 14; height: 14
                                color: row.modelData.accent
                            }
                            Repeater {
                                model: row.modelData.colors
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 8; height: 14
                                    color: modelData
                                }
                            }
                        }
                    }

                    Text {
                        anchors.left: preview.right
                        anchors.leftMargin: 12
                        anchors.right: check.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        color: row.isSelected ? Theme.accent : Theme.fg
                    }

                    Text {
                        id: check
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.isCurrent ? "󰄬" : ""
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        color: Theme.accent
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => {
                            if (themeWin.hovered(rowMouse, mouse.x, mouse.y)) themeWin.selectedIndex = row.index;
                        }
                        onPressed: {
                            themeWin.selectedIndex = row.index;
                            themeWin.pickTheme(row.index);
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 6
                text: "↑↓ choose · ⏎ apply · esc close"
                font.family: Theme.fontMain
                font.pixelSize: 11
                color: Theme.placeholder
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // --- Step 2: the chosen theme's wallpapers --------------------------------
        ColumnLayout {
            id: wallCol
            x: 5
            y: 10
            width: themeWin.wallCols * themeWin.cellW
            spacing: 4
            opacity: panel.walled ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 5
                Layout.rightMargin: 5
                Layout.bottomMargin: 2
                spacing: 10

                Text {
                    text: "󰁍"
                    font.family: Theme.fontMain
                    font.pixelSize: 15
                    color: backArea.containsMouse ? Theme.accent : Theme.muted
                    MouseArea {
                        id: backArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: themeWin.back()
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "󰸉   " + themeWin.wallThemeName + (Theme.busy ? "  …" : "")
                    elide: Text.ElideRight
                    font.family: Theme.fontMain
                    font.pixelSize: 15
                    color: Theme.accent
                }

                Text {
                    text: themeWin.wallTotal === 1 ? "1 wallpaper" : themeWin.wallTotal + " wallpapers"
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    color: Theme.muted
                }
            }

            Text {
                visible: !wallLister.running && themeWin.wallTotal === 0
                Layout.leftMargin: 5
                Layout.preferredHeight: themeWin.cellH
                text: "no wallpaper in walls/" + themeWin.wallTheme
                verticalAlignment: Text.AlignVCenter
                font.family: Theme.fontMain
                font.pixelSize: 13
                color: Theme.muted
            }

            GridView {
                id: grid
                visible: themeWin.wallTotal > 0
                Layout.preferredWidth: themeWin.wallCols * themeWin.cellW
                Layout.preferredHeight: Math.min(themeWin.wallRows, 3) * themeWin.cellH
                cellWidth: themeWin.cellW
                cellHeight: themeWin.cellH
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: walls

                delegate: Item {
                    id: cell
                    required property int index
                    required property string path
                    required property string thumb
                    readonly property bool isSelected: index === themeWin.wallIndex
                    readonly property bool isCurrent: path === Wallpapers.current

                    width: themeWin.cellW
                    height: themeWin.cellH

                    Rectangle {
                        id: frame
                        x: 5
                        y: 5
                        width: themeWin.cellW - 10
                        height: themeWin.cellH - 10
                        color: Theme.bgInset
                        border.color: cell.isSelected ? Theme.accent : Theme.border
                        border.width: cell.isSelected ? 2 : 1

                        Image {
                            anchors.fill: parent
                            anchors.margins: cell.isSelected ? 3 : 1
                            source: Wallpapers.toUrl(cell.thumb)
                            // The thumbnail is the image itself when it couldn't be made: decode it small
                            sourceSize: Qt.size(400, 250)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            smooth: true
                            opacity: status === Image.Ready ? (cell.isSelected ? 1 : 0.8) : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        // Current wallpaper
                        Rectangle {
                            visible: cell.isCurrent
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: 22
                            height: 22
                            color: Theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: "󰄬"
                                font.family: Theme.fontMain
                                font.pixelSize: 13
                                color: Theme.onAccent
                            }
                        }
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: frame
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => {
                            if (themeWin.hovered(cellMouse, mouse.x, mouse.y)) themeWin.wallIndex = cell.index;
                        }
                        onPressed: {
                            themeWin.wallIndex = cell.index;
                            themeWin.applyWall(cell.index);
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 4
                text: "←↑↓→ choose · ⏎ apply · ⌫ themes · esc close"
                font.family: Theme.fontMain
                font.pixelSize: 11
                color: Theme.placeholder
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
