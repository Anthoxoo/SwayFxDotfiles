import QtQuick
import "../core"

Text {
    id: batRoot
    property bool hovered: false

    text: SysState.batText
    color: {
        if (batMouse.containsMouse) return Theme.accent;
        if (SysState.batState === "critical") return Theme.urgent;
        if (SysState.batState === "charging" || SysState.batState === "warning") return Theme.accent;
        return Theme.fg;
    }
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: batHoverTimer
        interval: 450
        repeat: false
        onTriggered: {
            if (batMouse.containsMouse) batRoot.hovered = true;
        }
    }

    MouseArea {
        id: batMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: batHoverTimer.restart()
        onExited: {
            batHoverTimer.stop();
            batRoot.hovered = false;
        }
        onPressed: {
            batHoverTimer.stop();
            batRoot.hovered = false;
            SysState.runCmd(SysState.scriptsDir + "/toggle-battery.sh");
        }
    }
}
