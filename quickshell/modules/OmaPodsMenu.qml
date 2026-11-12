import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: podsWin

    visible: SysState.podsMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: SysState.podsMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property var st: SysState.podsState || ({ running: false, connected: false })

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
            if (podsWin.visible) keyCatcher.forceActiveFocus();
        }
    }

    // Raccourcis clavier officiels d'OmaPods
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SysState.podsMenuOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_N) {
                SysState.podsSetMode("anc");
                event.accepted = true;
            } else if (event.key === Qt.Key_A) {
                SysState.podsSetMode("adaptive");
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                SysState.podsSetMode("transparency");
                event.accepted = true;
            } else if (event.key === Qt.Key_O) {
                SysState.podsSetMode("off");
                event.accepted = true;
            } else if (event.key === Qt.Key_C) {
                SysState.podsToggleCa();
                event.accepted = true;
            } else if (event.key === Qt.Key_B) {
                SysState.podsToggleOneBud();
                event.accepted = true;
            } else if (event.key === Qt.Key_E) {
                SysState.podsCycleEar();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                SysState.podsCmd("reopen");
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                if (podsWin.st.mode === "adaptive") {
                    SysState.podsSetAdaptive(Math.max(0, (podsWin.st.adaptiveLevel || 50) - 5));
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                if (podsWin.st.mode === "adaptive") {
                    SysState.podsSetAdaptive(Math.min(100, (podsWin.st.adaptiveLevel || 50) + 5));
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                SysState.podsMenuOpen = false;
                SysState.runCmd(SysState.scriptsDir + "/toggle-audio.sh");
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: SysState.podsMenuOpen = false
    }

    Rectangle {
        width: 300
        height: mainCol.implicitHeight + 24
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 95
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

            // En-tête : Nom du modèle + état du boîtier
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: podsWin.st.connected ? ("󱡏  " + (podsWin.st.name || "airpods").toLowerCase()) : "󱡏  airpods"
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: {
                        if (!podsWin.st.running) return "daemon off";
                        if (!podsWin.st.connected) return "disconnected";
                        if (podsWin.st.lid) return "lid " + podsWin.st.lid;
                        return "connected";
                    }
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            // Message d'état si déconnecté ou démon arrêté
            Text {
                visible: !podsWin.st.running || !podsWin.st.connected
                text: !podsWin.st.running
                      ? "librepods daemon is not running"
                      : "no airpods connected"
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 12
            }

            // Section Batteries (Left, Right, Case ou Single pour Max)
            ColumnLayout {
                visible: podsWin.st.connected
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: {
                        if (!podsWin.st || !podsWin.st.connected) return [];
                        if (podsWin.st.isMax) {
                            return [{ label: "headphone", data: podsWin.st.single }];
                        }
                        let rows = [
                            { label: "left",  data: podsWin.st.left },
                            { label: "right", data: podsWin.st.right }
                        ];
                        if (podsWin.st.case && podsWin.st.case.level >= 0) {
                            rows.push({ label: "case", data: podsWin.st.case });
                        }
                        return rows;
                    }

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        property int lvl: modelData.data ? modelData.data.level : -1
                        property bool chg: modelData.data ? modelData.data.charging : false
                        property bool ear: modelData.data ? modelData.data.inEar : false

                        Text {
                            text: modelData.label
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            Layout.preferredWidth: 46
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            color: Theme.sep
                            radius: 0

                            Rectangle {
                                width: parent.parent.lvl >= 0 ? Math.round((parent.parent.lvl / 100.0) * parent.width) : 0
                                height: parent.height
                                color: parent.parent.lvl <= 15 && parent.parent.lvl >= 0 ? Theme.urgent : Theme.accent
                                radius: 0
                            }
                        }

                        Text {
                            text: {
                                if (parent.lvl <= 0) return "-";
                                let suffix = parent.chg ? " 󰂄" : (parent.ear ? " ·" : "");
                                return parent.lvl + "%" + suffix;
                            }
                            color: Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            Layout.preferredWidth: 52
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // Séparateur Modes d'écoute
            Rectangle {
                visible: podsWin.st.connected && podsWin.st.modes && podsWin.st.modes.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            Text {
                visible: podsWin.st.connected && podsWin.st.modes && podsWin.st.modes.length > 0
                text: "listening mode"
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 12
            }

            // Boutons de modes (ANC, Adaptive, Transparency, Off)
            ColumnLayout {
                visible: podsWin.st.connected && podsWin.st.modes && podsWin.st.modes.length > 0
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: (podsWin.st && podsWin.st.modes) ? podsWin.st.modes : []
                    delegate: Rectangle {
                        required property string modelData
                        property bool isAct: podsWin.st.mode === modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 0
                        color: isAct ? Theme.hoverBg : (modeMouse.containsMouse ? "#1b1b1e" : "transparent")
                        border.color: isAct ? Theme.accent : Theme.sep
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Text {
                                text: {
                                    if (modelData === "anc") return "●  noise cancellation";
                                    if (modelData === "adaptive") return "◐  adaptive";
                                    if (modelData === "transparency") return "○  transparency";
                                    return "·  off";
                                }
                                color: parent.parent.isAct ? Theme.accent : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "[" + modelData.charAt(0) + "]"
                                color: Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: modeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                keyCatcher.forceActiveFocus();
                                SysState.podsSetMode(modelData);
                            }
                        }
                    }
                }
            }

            // Slider Adaptive Noise Level (affiché uniquement si Adaptive est actif)
            ColumnLayout {
                visible: podsWin.st.connected && podsWin.st.mode === "adaptive"
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "adaptive noise"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (podsWin.st.adaptiveLevel || 50) + "%"
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    id: adaptTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    color: Theme.sep
                    radius: 0

                    Rectangle {
                        width: Math.round(((podsWin.st.adaptiveLevel || 50) / 100.0) * parent.width)
                        height: parent.height
                        color: Theme.accent
                        radius: 0
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function applyMouse(mx) {
                            let pct = Math.round(Math.max(0, Math.min(1, mx / adaptTrack.width)) * 100);
                            SysState.podsSetAdaptive(pct);
                        }
                        onPressed: mouse => applyMouse(mouse.x)
                        onPositionChanged: mouse => { if (pressed) applyMouse(mouse.x); }
                    }
                }
            }

            // Séparateur Options (Conversation Awareness, One-Bud ANC, Ear Detection)
            Rectangle {
                visible: podsWin.st.connected
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            // Conversation Awareness [c]
            RowLayout {
                visible: podsWin.st.connected && podsWin.st.hasCa
                Layout.fillWidth: true

                Text {
                    text: "conversation awareness [c]"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 48
                    height: 22
                    radius: 0
                    color: podsWin.st.ca ? Theme.accent : (caMouse.containsMouse ? Theme.hoverBg : "transparent")
                    border.color: podsWin.st.ca ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: podsWin.st.ca ? "on" : "off"
                        color: podsWin.st.ca ? Theme.bgSolid : Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: caMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: SysState.podsToggleCa()
                    }
                }
            }

            // One-Bud ANC [b]
            RowLayout {
                visible: podsWin.st.connected && podsWin.st.hasOneBud
                Layout.fillWidth: true

                Text {
                    text: "one-bud anc [b]"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 48
                    height: 22
                    radius: 0
                    color: podsWin.st.oneBud ? Theme.accent : (obMouse.containsMouse ? Theme.hoverBg : "transparent")
                    border.color: podsWin.st.oneBud ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: podsWin.st.oneBud ? "on" : "off"
                        color: podsWin.st.oneBud ? Theme.bgSolid : Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: obMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: SysState.podsToggleOneBud()
                    }
                }
            }

            // Ear Detection [e]
            RowLayout {
                visible: podsWin.st.connected
                Layout.fillWidth: true

                Text {
                    text: "ear detection [e]"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 68
                    height: 22
                    radius: 0
                    color: earMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: podsWin.st.ear || "one"
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    MouseArea {
                        id: earMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: SysState.podsCycleEar()
                    }
                }
            }
        }
    }
}
