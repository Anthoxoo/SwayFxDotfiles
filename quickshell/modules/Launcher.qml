import QtQuick
import "../core"

Text {
    text: ""
    color: Theme.accent
    font.family: Theme.fontMain
    font.pixelSize: 16
    rightPadding: 6

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            SysState.powerMenuOpen = false;
            SysState.launcherOpen = !SysState.launcherOpen;
        }
    }
}
