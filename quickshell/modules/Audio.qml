import QtQuick
import "../core"

Text {
    id: audioRoot
    property bool hovered: false

    text: SysState.audioText
    color: paMouse.containsMouse ? Theme.accent : (SysState.audioMuted ? Theme.disabled : Theme.fg)
    font.family: Theme.fontMain
    font.pixelSize: 13

    Timer {
        id: audioHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (paMouse.containsMouse) audioRoot.hovered = true;
        }
    }

    MouseArea {
        id: paMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: audioHoverTimer.restart()
        onExited: {
            audioHoverTimer.stop();
            audioRoot.hovered = false;
        }
        onPressed: mouse => {
            audioHoverTimer.stop();
            audioRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                SysState.runCmd(SysState.scriptsDir + "/toggle-audio.sh");
            } else if (mouse.button === Qt.RightButton) {
                SysState.runCmd("pamixer -t || wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle || pactl set-sink-mute @DEFAULT_SINK@ toggle");
                SysState.refresh();
            }
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                SysState.runCmd("pamixer -i 2 || wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+ || pactl set-sink-volume @DEFAULT_SINK@ +2%");
            } else {
                SysState.runCmd("pamixer -d 2 || wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%- || pactl set-sink-volume @DEFAULT_SINK@ -2%");
            }
            SysState.refresh();
        }
    }
}
