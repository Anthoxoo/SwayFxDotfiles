import QtQuick
import "../core"

Text {
    id: audioRoot
    property bool hovered: false

    text: SysState.audioText
    color: (paMouse.containsMouse || SysState.audioMenuOpen) ? Theme.accent : (SysState.audioMuted ? Theme.disabled : Theme.fg)
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: audioHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (paMouse.containsMouse && !SysState.audioMenuOpen) audioRoot.hovered = true;
        }
    }

    MouseArea {
        id: paMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: audioHoverTimer.restart()
        onExited: {
            audioHoverTimer.stop();
            audioRoot.hovered = false;
        }
        onPressed: mouse => {
            audioHoverTimer.stop();
            audioRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                let next = !SysState.audioMenuOpen;
                SysState.closeAllPopups();
                SysState.audioMenuOpen = next;
            } else if (mouse.button === Qt.RightButton) {
                SysState.audioToggleMute();
            }
        }
        onWheel: wheel => {
            let delta = wheel.angleDelta.y > 0 ? 2 : -2;
            SysState.audioSetVolume(Math.max(0, Math.min(100, SysState.audioDetailState.vol + delta)));
        }
    }
}
