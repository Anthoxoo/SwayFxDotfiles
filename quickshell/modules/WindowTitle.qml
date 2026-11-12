import QtQuick
import QtQuick.Layouts
import "../core"

RowLayout {
    visible: SysState.activeWindowTitle !== ""
    spacing: 12
    Layout.leftMargin: 4

    Rectangle {
        width: 1
        height: 16
        color: Theme.sep
    }

    Text {
        text: SysState.activeWindowTitle
        color: Theme.win
        font.family: Theme.fontMain
        font.pixelSize: 12
    }
}
