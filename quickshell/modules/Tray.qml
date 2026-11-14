import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

RowLayout {
    spacing: 10

    Repeater {
        model: SystemTray.items
        delegate: Image {
            required property var modelData
            source: modelData.icon
            sourceSize.width: 15
            sourceSize.height: 15

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) modelData.activate();
                    else modelData.secondaryActivate();
                }
            }
        }
    }
}
