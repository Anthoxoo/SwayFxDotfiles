import QtQuick
import "../core"

// Bar eyedropper (core/Picker.qml): click picks a color on screen, right click copies the last
// one again. The dot is the last color; the tooltip lists the recent ones.
Item {
    id: pickRoot
    property bool hovered: false

    implicitWidth: icon.implicitWidth + 8
    implicitHeight: 28

    readonly property string tooltipHtml: {
        let lines = [Theme.tipTitle("󰈊  color picker")];
        if (Picker.history.length === 0) lines.push(Theme.tipMuted("no color picked yet"));
        for (let c of Picker.history.slice(0, 5))
            lines.push(Theme.tipSpan(c, "██") + " " + Theme.tipSpan(Theme.fg, c));
        lines.push(Theme.tipMuted("click pick · right click copy last"));
        return Theme.tipBlock(lines);
    }

    Timer {
        id: hoverTimer
        interval: 400
        onTriggered: if (pickMouse.containsMouse) pickRoot.hovered = true
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "󰈊"
        font.family: Theme.fontMain
        font.pixelSize: 14
        color: pickMouse.containsMouse || Picker.active ? Theme.accent : Theme.fg
    }

    // Last color picked
    Rectangle {
        visible: Picker.history.length > 0
        anchors.left: icon.right
        anchors.bottom: icon.bottom
        anchors.leftMargin: -2
        width: 6
        height: 6
        color: Picker.history.length > 0 ? Picker.history[0] : "transparent"
        border.color: Theme.border
        border.width: 1
    }

    MouseArea {
        id: pickMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: hoverTimer.restart()
        onExited: {
            hoverTimer.stop();
            pickRoot.hovered = false;
        }
        onPressed: mouse => {
            hoverTimer.stop();
            pickRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) Picker.start();
            else Picker.recopy();
        }
    }
}
