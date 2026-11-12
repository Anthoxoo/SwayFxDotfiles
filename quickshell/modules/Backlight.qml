import QtQuick
import "../core"

Text {
    id: blRoot
    property bool hovered: false

    text: SysState.backlightText
    color: (blMouse.containsMouse || SysState.brightnessMenuOpen || SysState.nightLightOn) ? Theme.accent : Theme.fg
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: blHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (blMouse.containsMouse && !SysState.brightnessMenuOpen) blRoot.hovered = true;
        }
    }

    MouseArea {
        id: blMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: blHoverTimer.restart()
        onExited: {
            blHoverTimer.stop();
            blRoot.hovered = false;
        }
        onPressed: mouse => {
            blHoverTimer.stop();
            blRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                SysState.powerMenuOpen = false;
                SysState.launcherOpen = false;
                SysState.podsMenuOpen = false;
                SysState.brightnessMenuOpen = !SysState.brightnessMenuOpen;
            } else if (mouse.button === Qt.RightButton) {
                SysState.toggleNightLight();
            }
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) SysState.stepBrightness(5);
            else SysState.stepBrightness(-5);
        }
    }
}
