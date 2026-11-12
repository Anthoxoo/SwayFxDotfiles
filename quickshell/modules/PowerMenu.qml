import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: powerWin

    visible: SysState.powerMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: SysState.powerMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property int selectedIndex: 0

    ListModel {
        id: powerActions
        ListElement { label: "   lock";     cmd: "pidof hyprlock || hyprlock" }
        ListElement { label: "󰤄   suspend";  cmd: "systemctl suspend" }
        ListElement { label: "󰍃   logout";   cmd: "swaymsg exit" }
        ListElement { label: "󰜉   reboot";   cmd: "systemctl reboot" }
        ListElement { label: "⏻   shutdown"; cmd: "systemctl poweroff" }
    }

    onVisibleChanged: {
        if (visible) {
            selectedIndex = 0;
            keyCatcher.forceActiveFocus();
            focusRetry.restart();
        }
    }

    Timer {
        id: focusRetry
        interval: 25
        repeat: false
        onTriggered: {
            if (powerWin.visible) keyCatcher.forceActiveFocus();
        }
    }

    function triggerCurrent() {
        if (selectedIndex >= 0 && selectedIndex < powerActions.count) {
            let cmd = powerActions.get(selectedIndex).cmd;
            SysState.powerMenuOpen = false;
            SysState.runCmd(cmd);
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SysState.powerMenuOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
                powerWin.selectedIndex = (powerWin.selectedIndex + 1) % powerActions.count;
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_Backtab) {
                powerWin.selectedIndex = (powerWin.selectedIndex - 1 + powerActions.count) % powerActions.count;
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                powerWin.triggerCurrent();
                event.accepted = true;
            }
        }
    }

    // Clic en dehors pour fermer
    MouseArea {
        anchors.fill: parent
        onPressed: SysState.powerMenuOpen = false
    }

    Rectangle {
        width: 210
        height: menuCol.implicitHeight + 16
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 6
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        MouseArea {
            anchors.fill: parent
            onPressed: keyCatcher.forceActiveFocus()
        }

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4

            Repeater {
                model: powerActions
                delegate: Rectangle {
                    required property int index
                    required property string label
                    required property string cmd
                    property bool isSelected: index === powerWin.selectedIndex

                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 0
                    color: isSelected ? Theme.hoverBg : "transparent"

                    Rectangle {
                        visible: parent.isSelected
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: Theme.accent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        text: parent.label
                        font.family: Theme.fontMain
                        font.pixelSize: 15
                        color: parent.isSelected ? Theme.accent : Theme.fg
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: powerWin.selectedIndex = parent.index
                        onPressed: {
                            powerWin.selectedIndex = parent.index;
                            powerWin.triggerCurrent();
                        }
                    }
                }
            }
        }
    }
}
