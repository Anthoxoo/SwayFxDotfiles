import QtQuick
import "../core"

Text {
    id: monRoot
    property bool hovered: false

    visible: {
        let st = SysState.monitorsState;
        if (!st) return true;
        if (st.hideWhenSingle && st.count <= 1) return false;
        return true;
    }

    text: {
        let st = SysState.monitorsState;
        if (!st || st.count <= 1) return "󰍹";
        return "󰍹 " + st.activeCount;
    }

    color: (monMouse.containsMouse || SysState.monitorsMenuOpen) ? Theme.accent : Theme.fg
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: monHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (monMouse.containsMouse && !SysState.monitorsMenuOpen) monRoot.hovered = true;
        }
    }

    MouseArea {
        id: monMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: monHoverTimer.restart()
        onExited: {
            monHoverTimer.stop();
            monRoot.hovered = false;
        }
        onPressed: mouse => {
            monHoverTimer.stop();
            monRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                SysState.powerMenuOpen = false;
                SysState.brightnessMenuOpen = false;
                SysState.podsMenuOpen = false;
                SysState.calendarMenuOpen = false;
                SysState.launcherOpen = false;
                SysState.monitorsMenuOpen = !SysState.monitorsMenuOpen;
            } else if (mouse.button === Qt.RightButton) {
                SysState.monitorsCmd("toggle-autohide");
            }
        }
    }
}
