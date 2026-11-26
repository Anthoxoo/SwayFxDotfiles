import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

// Global theme picker (~/.config/themes) — $mod+Shift+t / `qs ipc call shell toggle theme`
// ↑/↓ (or j/k) to choose, Enter to apply, Escape to close.
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

    property int selectedIndex: 0
    readonly property var themes: Theme.available

    function selectCurrent() {
        selectedIndex = Math.max(0, themes.findIndex(t => t.id === Theme.themeId));
    }
    // The list is re-read on every opening (new themes): reselect the active theme
    onThemesChanged: if (visible) selectCurrent()

    onVisibleChanged: {
        if (!visible) return;
        Theme.refreshList();
        selectCurrent();
        keyCatcher.forceActiveFocus();
        focusRetry.restart();
    }

    Timer {
        id: focusRetry
        interval: 25
        onTriggered: if (themeWin.visible) keyCatcher.forceActiveFocus()
    }

    function apply(i) {
        if (i < 0 || i >= themes.length) return;
        Theme.set(themes[i].id);
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            let n = themeWin.themes.length;
            if (event.key === Qt.Key_Escape) {
                SysState.themeMenuOpen = false;
            } else if (n > 0 && (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab)) {
                themeWin.selectedIndex = (themeWin.selectedIndex + 1) % n;
            } else if (n > 0 && (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_Backtab)) {
                themeWin.selectedIndex = (themeWin.selectedIndex - 1 + n) % n;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                themeWin.apply(themeWin.selectedIndex);
            } else {
                return;
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
        width: 340
        height: col.implicitHeight + 20
        anchors.centerIn: parent
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1

        Behavior on color { ColorAnimation { duration: 200 } }
        Behavior on border.color { ColorAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onPressed: keyCatcher.forceActiveFocus()
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 10
            spacing: 4

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
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: themeWin.selectedIndex = row.index
                        onPressed: {
                            themeWin.selectedIndex = row.index;
                            themeWin.apply(row.index);
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
    }
}
