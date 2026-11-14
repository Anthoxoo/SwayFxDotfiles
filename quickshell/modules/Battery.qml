import QtQuick
import "../core"

Text {
    id: batRoot
    property bool hovered: false

    text: SysState.batText
    color: {
        if (batMouse.containsMouse || SysState.batteryMenuOpen) return Theme.accent;
        if (SysState.batState === "critical") return Theme.urgent;
        if (SysState.batState === "warning" || SysState.batState === "charging") return Theme.accent;
        return Theme.fg;
    }
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: batHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (batMouse.containsMouse && !SysState.batteryMenuOpen) batRoot.hovered = true;
        }
    }

    MouseArea {
        id: batMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: batHoverTimer.restart()
        onExited: {
            batHoverTimer.stop();
            batRoot.hovered = false;
        }
        onPressed: mouse => {
            batHoverTimer.stop();
            batRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                let next = !SysState.batteryMenuOpen;
                SysState.closeAllPopups();
                SysState.batteryMenuOpen = next;
            } else if (mouse.button === Qt.RightButton) {
                SysState.runCmd("python3 " + SysState.scriptsDir + "/battery-ctl.py cycle-profile");
                SysState.refresh();
            }
        }
    }
}
