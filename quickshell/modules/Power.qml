import QtQuick
import "../core"

Text {
    text: "⏻"
    color: Theme.accent
    font.family: Theme.fontMain
    font.pixelSize: 14
    leftPadding: 4

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: SysState.powerMenuOpen = !SysState.powerMenuOpen
    }
}
