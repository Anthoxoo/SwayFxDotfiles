import QtQuick
import "../core"

Text {
    id: wifiRoot
    property bool hovered: false

    text: (!SysState.wifiCompact && SysState.wifiSsid !== "")
          ? (SysState.wifiIcon + " " + SysState.wifiSsid)
          : SysState.wifiIcon
    color: (wifiMouse.containsMouse || SysState.wifiMenuOpen)
           ? Theme.accent
           : (SysState.wifiConnected ? Theme.fg : Theme.disabled)
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: wifiHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (wifiMouse.containsMouse && !SysState.wifiMenuOpen) wifiRoot.hovered = true;
        }
    }

    MouseArea {
        id: wifiMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: wifiHoverTimer.restart()
        onExited: {
            wifiHoverTimer.stop();
            wifiRoot.hovered = false;
        }
        onPressed: mouse => {
            wifiHoverTimer.stop();
            wifiRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                let next = !SysState.wifiMenuOpen;
                SysState.closeAllPopups();
                SysState.wifiMenuOpen = next;
            } else if (mouse.button === Qt.RightButton) {
                SysState.wifiCompact = !SysState.wifiCompact;
            }
        }
    }
}
