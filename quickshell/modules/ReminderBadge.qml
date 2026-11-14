import QtQuick
import "../core"

// Indicateur de rappels en attente (cloche + nombre) ; clic = ouvrir les rappels
Text {
    id: remRoot
    property bool hovered: false

    visible: Reminders.count > 0
    text: "\u{F009A} " + Reminders.count
    color: (remMouse.containsMouse || SysState.reminderOpen) ? Theme.accent : Theme.fg
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: remHoverTimer
        interval: 400
        onTriggered: if (remMouse.containsMouse && !SysState.reminderOpen) remRoot.hovered = true
    }

    MouseArea {
        id: remMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: remHoverTimer.restart()
        onExited: {
            remHoverTimer.stop();
            remRoot.hovered = false;
        }
        onPressed: {
            remHoverTimer.stop();
            remRoot.hovered = false;
            SysState.togglePanel("reminder");
        }
    }
}
