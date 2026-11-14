import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: batWin

    visible: SysState.batteryMenuOpen
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

    property var st: SysState.batteryDetailState || ({
        capacity: 100,
        status: "discharging",
        watts: 0.0,
        timeStr: "-",
        health: 100,
        cycles: 0,
        profile: "balanced"
    })

    onVisibleChanged: {
        if (visible) {
            SysState.refreshBatteryDetails();
            keyCatcher.forceActiveFocus();
            focusRetry.restart();
        }
    }

    Timer {
        id: focusRetry
        interval: 25
        repeat: false
        onTriggered: {
            if (batWin.visible) keyCatcher.forceActiveFocus();
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SysState.batteryMenuOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_1 || event.key === Qt.Key_S) {
                SysState.batterySetProfile("power-saver");
                event.accepted = true;
            } else if (event.key === Qt.Key_2 || event.key === Qt.Key_B) {
                SysState.batterySetProfile("balanced");
                event.accepted = true;
            } else if (event.key === Qt.Key_3 || event.key === Qt.Key_P) {
                SysState.batterySetProfile("performance");
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                SysState.batteryMenuOpen = false;
                SysState.powerMenuOpen = true;
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: SysState.batteryMenuOpen = false
    }

    Rectangle {
        width: 296
        height: Math.max(80, mainCol.implicitHeight + 24)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 12
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
            spacing: 10

            // --- EN-TÊTE : Batterie % + État ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "  battery · " + (batWin.st.capacity !== undefined ? batWin.st.capacity : 100) + "%"
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: batWin.st.status || "discharging"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            // Barre de niveau de batterie
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 10
                color: Theme.sep
                radius: 0

                Rectangle {
                    property int cap: batWin.st.capacity !== undefined ? batWin.st.capacity : 100
                    width: Math.round((Math.max(0, Math.min(100, cap)) / 100.0) * parent.width)
                    height: parent.height
                    color: cap <= 15 ? Theme.urgent : Theme.accent
                    radius: 0
                }
            }

            // Statistiques détaillées (Time, Power Draw, Health, Cycles)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "estimate"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: batWin.st.timeStr || "-"
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "power draw"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (batWin.st.watts !== undefined ? batWin.st.watts : "0.0") + " W"
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "battery health"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (batWin.st.health !== undefined ? batWin.st.health : 100) + "%"
                              + (batWin.st.cycles > 0 ? (" (" + batWin.st.cycles + " cycles)") : "")
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            // --- SÉLECTEUR DE PROFIL D'ÉNERGIE ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "power profile"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "[1 / 2 / 3]"
                    color: Theme.disabled
                    font.family: Theme.fontMain
                    font.pixelSize: 10
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { id: "power-saver", label: "󰌪 saver" },
                        { id: "balanced",    label: "󰗑 balanced" },
                        { id: "performance", label: "󰓅 perf" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        property bool isCur: (batWin.st.profile || "balanced") === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 0
                        color: isCur ? Theme.accent : (profMouse.containsMouse ? Theme.hoverBg : "transparent")
                        border.color: isCur ? Theme.accent : Theme.sep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: isCur ? Theme.bgSolid : Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: profMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: Qt.callLater(() => SysState.batterySetProfile(modelData.id))
                        }
                    }
                }
            }
        }
    }
}
