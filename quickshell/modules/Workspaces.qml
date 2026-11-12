import QtQuick
import QtQuick.Layouts
import Quickshell.I3
import "../core"

RowLayout {
    spacing: 4

    Repeater {
        model: I3.workspaces
        delegate: Rectangle {
            required property var modelData
            property bool isFocused: modelData.focused
            property bool isUrgent: modelData.urgent
            property bool isHovered: wsMouse.containsMouse

            implicitHeight: 22
            implicitWidth: wsLabel.implicitWidth + 16
            color: isFocused ? Theme.accent : (isUrgent ? Theme.urgent : (isHovered ? Theme.hoverBg : "transparent"))

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: modelData.name
                font.family: Theme.fontMain
                font.pixelSize: 13
                font.bold: isFocused
                color: (isFocused || isUrgent) ? Theme.bgSolid : (isHovered ? Theme.fg : Theme.muted)
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: SysState.runCmd("swaymsg workspace '" + modelData.name + "'")
            }
        }
    }

    Rectangle {
        visible: SysState.swayMode !== ""
        color: Theme.accent
        implicitHeight: 22
        implicitWidth: modeText.implicitWidth + 16

        Text {
            id: modeText
            anchors.centerIn: parent
            text: SysState.swayMode
            color: Theme.bgSolid
            font.family: Theme.fontMain
            font.pixelSize: 13
            font.bold: true
            font.italic: true
        }
    }
}
