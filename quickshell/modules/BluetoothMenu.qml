import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: btWin

    visible: SysState.btMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property var st: SysState.btDetailState || ({
        powered: true,
        connectedCount: 0,
        devices: []
    })

    onVisibleChanged: {
        if (visible) {
            SysState.refreshBtDetails(false);
            keyCatcher.forceActiveFocus();
            focusRetry.restart();
        }
    }

    Timer {
        id: focusRetry
        interval: 25
        repeat: false
        onTriggered: {
            if (btWin.visible) keyCatcher.forceActiveFocus();
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SysState.btMenuOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                SysState.btTogglePower();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                SysState.refreshBtDetails(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                SysState.btMenuOpen = false;
                SysState.podsMenuOpen = true;
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: SysState.btMenuOpen = false
    }

    Rectangle {
        width: 310
        height: Math.max(80, mainCol.implicitHeight + 24)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 100
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        MouseArea {
            anchors.fill: parent
            onPressed: keyCatcher.forceActiveFocus()
        }

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // --- EN-TÊTE : Bluetooth + Scan [r] + Power [t] ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "  bluetooth"
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                // Bouton Scan [r]
                Rectangle {
                    visible: Boolean(btWin.st.powered)
                    width: 24
                    height: 20
                    radius: 0
                    color: scanMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: scanMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: SysState.btScanning ? "…" : "󰑐"
                        color: scanMouse.containsMouse ? Theme.accent : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.refreshBtDetails(true))
                    }
                }

                // Bouton Power On/Off [t]
                Rectangle {
                    width: 48
                    height: 20
                    radius: 0
                    color: btWin.st.powered ? Theme.accent : (pwrMouse.containsMouse ? Theme.hoverBg : "transparent")
                    border.color: btWin.st.powered ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: btWin.st.powered ? "on" : "off"
                        color: btWin.st.powered ? Theme.bgSolid : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: pwrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.btTogglePower())
                    }
                }
            }

            Text {
                visible: !btWin.st.powered
                text: "bluetooth is disabled [t]"
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 12
            }

            Rectangle {
                visible: Boolean(btWin.st.powered)
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            Text {
                visible: Boolean(btWin.st.powered && (!btWin.st.devices || btWin.st.devices.length === 0))
                text: "no devices found — press [r] to scan"
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 11
            }

            // --- LISTE DES APPAREILS BLUETOOTH ---
            ColumnLayout {
                visible: Boolean(btWin.st.powered && btWin.st.devices && btWin.st.devices.length > 0)
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: (btWin.st && btWin.st.devices) ? btWin.st.devices : []
                    delegate: Rectangle {
                        required property var modelData
                        property bool isConn: Boolean(modelData.connected)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 0
                        color: isConn ? Theme.hoverBg : (devMouse.containsMouse ? Theme.rowHover : "transparent")
                        border.color: isConn ? Theme.accent : (devMouse.containsMouse ? Theme.accent : Theme.sep)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: parent.parent.isConn ? "●" : (modelData.paired ? "◦" : "·")
                                color: parent.parent.isConn ? Theme.accent : Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                            }

                            Text {
                                text: modelData.name || modelData.mac
                                color: parent.parent.isConn ? Theme.accent : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    if (parent.parent.isConn) {
                                        return modelData.battery >= 0 ? (modelData.battery + "%") : "connected";
                                    }
                                    return modelData.paired ? "paired" : "pair";
                                }
                                color: parent.parent.isConn ? Theme.accent : Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                            }

                            Text {
                                visible: Boolean(modelData.paired)
                                text: "×"
                                color: rmMouse.containsMouse ? Theme.urgent : Theme.disabled
                                font.family: Theme.fontMain
                                font.pixelSize: 13

                                MouseArea {
                                    id: rmMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: Qt.callLater(() => SysState.btRemoveDevice(modelData.mac))
                                }
                            }
                        }

                        MouseArea {
                            id: devMouse
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: Qt.callLater(() => SysState.btToggleDevice(modelData.mac))
                        }
                    }
                }
            }
        }
    }
}
