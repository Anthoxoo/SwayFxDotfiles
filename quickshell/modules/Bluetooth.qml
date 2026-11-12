import QtQuick
import "../core"

Text {
    id: btRoot
    property bool hovered: false

    text: SysState.btText
    color: btMouse.containsMouse ? Theme.accent : Theme.fg
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: btHoverTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (btMouse.containsMouse) btRoot.hovered = true;
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
                SysState.runCmd(SysState.scriptsDir + "/toggle-bt.sh");
            } else if (mouse.button === Qt.RightButton) {
                SysState.btCompact = !SysState.btCompact;
                SysState.refresh();
            }
        }
    }
}
