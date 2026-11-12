import QtQuick
import "../core"

Text {
    id: wifiRoot
    property bool hovered: false

    text: (SysState.wifiCompact || !SysState.wifiConnected || SysState.wifiSsid === "")
          ? SysState.wifiIcon
          : (SysState.wifiIcon + " " + SysState.wifiSsid)
    color: wifiMouse.containsMouse
           ? Theme.accent
           : (SysState.wifiConnected ? Theme.fg : Theme.disabled)
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: hoverTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (wifiMouse.containsMouse) wifiRoot.hovered = true;
        }
    }

    MouseArea {
        id: wifiMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: hoverTimer.restart()
        onExited: {
            hoverTimer.stop();
            wifiRoot.hovered = false;
        }
        onPressed: mouse => {
            hoverTimer.stop();
            wifiRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                SysState.runCmd(SysState.scriptsDir + "/toggle-wifi.sh");
            } else if (mouse.button === Qt.RightButton) {
                SysState.wifiCompact = !SysState.wifiCompact;
            }
        }
    }
}
