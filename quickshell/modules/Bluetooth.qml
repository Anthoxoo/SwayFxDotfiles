import QtQuick
import "../core"

Text {
    id: btRoot
    property bool hovered: false

    text: SysState.btText
    color: (btMouse.containsMouse || SysState.btMenuOpen)
           ? Theme.accent
           : (SysState.btText === "󰂲" ? Theme.disabled : Theme.fg)
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: btHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (btMouse.containsMouse && !SysState.btMenuOpen) btRoot.hovered = true;
        }
    }

    MouseArea {
        id: btMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: btHoverTimer.restart()
        onExited: {
            btHoverTimer.stop();
            btRoot.hovered = false;
        }
        onPressed: mouse => {
            btHoverTimer.stop();
            btRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                let next = !SysState.btMenuOpen;
                SysState.closeAllPopups();
                SysState.btMenuOpen = next;
            } else if (mouse.button === Qt.RightButton) {
                SysState.btCompact = !SysState.btCompact;
                SysState.refresh();
            }
        }
    }
}
