import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: brightWin

    visible: SysState.brightnessMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: SysState.brightnessMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onVisibleChanged: {
        if (visible) {
            keyCatcher.forceActiveFocus();
            focusRetry.restart();
        }
    }

    Timer {
        id: focusRetry
        interval: 25
        repeat: false
        onTriggered: {
            if (brightWin.visible) keyCatcher.forceActiveFocus();
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SysState.brightnessMenuOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                SysState.setBrightness(SysState.brightValue - 5, false);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                SysState.setBrightness(SysState.brightValue + 5, false);
                event.accepted = true;
            }
        }
    }

    // Clic en dehors du menu pour fermer
    MouseArea {
        anchors.fill: parent
        onPressed: SysState.brightnessMenuOpen = false
    }

    Rectangle {
        width: 270
        height: contentCol.implicitHeight + 24
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 70
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        MouseArea {
            anchors.fill: parent
            onPressed: keyCatcher.forceActiveFocus()
        }

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "display"
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: SysState.brightValue + "%"
                    color: Theme.fg
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }
            }

            Rectangle {
                id: sliderTrack
                Layout.fillWidth: true
                Layout.preferredHeight: 14
                color: Theme.sep
                radius: 0

                Rectangle {
                    width: Math.round((SysState.brightValue / 100.0) * parent.width)
                    height: parent.height
                    color: Theme.accent
                    radius: 0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function updateFromMouse(mx) {
                        let ratio = Math.max(0.01, Math.min(1.0, mx / sliderTrack.width));
                        SysState.setBrightness(Math.round(ratio * 100), false);
                    }
                    onPressed: mouse => {
                        keyCatcher.forceActiveFocus();
                        updateFromMouse(mouse.x);
                    }
                    onPositionChanged: mouse => {
                        if (pressed) updateFromMouse(mouse.x);
                    }
                    onWheel: wheel => {
                        if (wheel.angleDelta.y > 0) SysState.setBrightness(SysState.brightValue + 5, false);
                        else SysState.setBrightness(SysState.brightValue - 5, false);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [10, 25, 50, 75, 100]
                    delegate: Rectangle {
                        required property int modelData
                        property bool isCurrent: Math.abs(SysState.brightValue - modelData) <= 2

                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: 0
                        color: isCurrent ? Theme.accent : (presetMouse.containsMouse ? Theme.hoverBg : "transparent")
                        border.color: isCurrent ? Theme.accent : Theme.sep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData + "%"
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            color: isCurrent ? Theme.bgSolid : (presetMouse.containsMouse ? Theme.accent : Theme.muted)
                        }

                        MouseArea {
                            id: presetMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                keyCatcher.forceActiveFocus();
                                SysState.setBrightness(modelData, false);
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "night light"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 48
                    height: 22
                    radius: 0
                    color: SysState.nightLightOn ? Theme.accent : (nlToggleMouse.containsMouse ? Theme.hoverBg : "transparent")
                    border.color: SysState.nightLightOn ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: SysState.nightLightOn ? "on" : "off"
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        color: SysState.nightLightOn ? Theme.bgSolid : Theme.fg
                    }

                    MouseArea {
                        id: nlToggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            keyCatcher.forceActiveFocus();
                            SysState.toggleNightLight();
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [3500, 4500, 5500]
                    delegate: Rectangle {
                        required property int modelData
                        property bool isCurrent: SysState.nightLightOn && SysState.nightLightTemp === modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: 0
                        color: isCurrent ? Theme.hoverBg : (tempMouse.containsMouse ? Theme.hoverBg : "transparent")
                        border.color: isCurrent ? Theme.accent : Theme.sep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData + "K"
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            color: isCurrent ? Theme.accent : (tempMouse.containsMouse ? Theme.fg : Theme.muted)
                        }

                        MouseArea {
                            id: tempMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                keyCatcher.forceActiveFocus();
                                SysState.setNightTemp(modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
