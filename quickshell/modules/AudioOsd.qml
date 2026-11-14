import Quickshell
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    visible: SysState.audioOsdVisible
    focusable: false
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        bottom: true
    }
    margins.bottom: 48

    implicitWidth: 260
    implicitHeight: 42

    Rectangle {
        anchors.fill: parent
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Text {
                text: SysState.audioOsdMuted ? "󰝟" : (SysState.audioOsdValue < 33 ? "󰕿" : (SysState.audioOsdValue < 66 ? "󰖀" : "󰕾"))
                color: SysState.audioOsdMuted ? Theme.muted : Theme.accent
                font.family: Theme.fontMain
                font.pixelSize: 15
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                color: Theme.sep
                radius: 0

                Rectangle {
                    width: Math.round((SysState.audioOsdValue / 100.0) * parent.width)
                    height: parent.height
                    color: SysState.audioOsdMuted ? Theme.muted : Theme.accent
                    radius: 0
                }
            }

            Text {
                text: SysState.audioOsdMuted ? "muted" : (SysState.audioOsdValue + "%")
                color: SysState.audioOsdMuted ? Theme.muted : Theme.fg
                font.family: Theme.fontMain
                font.pixelSize: 13
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
