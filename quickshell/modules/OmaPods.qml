import QtQuick
import "../core"

Text {
    id: podsRoot
    property bool hovered: false

    visible: !SysState.podsHideWhenDisconnected || (SysState.podsState && SysState.podsState.connected)
    text: {
        let st = SysState.podsState;
        if (!st || !st.connected || st.barPct <= 0) return "󱡏";
        return "󱡏 " + st.barPct + "%";
    }
    color: (podsMouse.containsMouse || SysState.podsMenuOpen)
           ? Theme.accent
           : ((SysState.podsState && SysState.podsState.connected) ? Theme.fg : Theme.disabled)
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: podsHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (podsMouse.containsMouse && !SysState.podsMenuOpen) podsRoot.hovered = true;
        }
    }

    MouseArea {
        id: podsMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: podsHoverTimer.restart()
        onExited: {
            podsHoverTimer.stop();
            podsRoot.hovered = false;
        }
        onPressed: mouse => {
            podsHoverTimer.stop();
            podsRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                SysState.powerMenuOpen = false;
                SysState.brightnessMenuOpen = false;
                SysState.launcherOpen = false;
                SysState.podsMenuOpen = !SysState.podsMenuOpen;
            } else if (mouse.button === Qt.RightButton) {
                if (SysState.podsState && SysState.podsState.connected) {
                    SysState.podsCmd("cycle-mode");
                }
            }
        }
    }
}
