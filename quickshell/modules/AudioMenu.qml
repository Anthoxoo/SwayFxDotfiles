import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: audioWin

    visible: SysState.audioMenuOpen
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

    property var st: SysState.audioDetailState || ({
        vol: 0,
        muted: false,
        micVol: 100,
        micMuted: false,
        sinks: [],
        sources: [],
        apps: []
    })

    onVisibleChanged: {
        if (visible) {
            SysState.refreshAudioDetails();
            keyCatcher.forceActiveFocus();
            focusRetry.restart();
        }
    }

    Timer {
        id: focusRetry
        interval: 25
        repeat: false
        onTriggered: {
            if (audioWin.visible) keyCatcher.forceActiveFocus();
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SysState.audioMenuOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_M) {
                SysState.audioToggleMute();
                event.accepted = true;
            } else if (event.key === Qt.Key_I) {
                SysState.audioToggleMic();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                SysState.audioSetVolume(Math.max(0, (audioWin.st.vol || 0) - 5));
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                SysState.audioSetVolume(Math.min(100, (audioWin.st.vol || 0) + 5));
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                SysState.audioMenuOpen = false;
                SysState.batteryMenuOpen = true;
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: SysState.audioMenuOpen = false
    }

    Rectangle {
        width: 330
        height: Math.max(80, mainCol.implicitHeight + 24)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 36
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

            // --- EN-TÊTE : Output Volume + Bouton Mute [m] ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: (audioWin.st.muted ? "󰝟  muted" : ("󰕾  output · " + (audioWin.st.vol || 0) + "%"))
                    color: audioWin.st.muted ? Theme.muted : Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 58
                    height: 20
                    radius: 0
                    color: audioWin.st.muted ? Theme.accent : (muteMouse.containsMouse ? Theme.hoverBg : "transparent")
                    border.color: audioWin.st.muted ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: audioWin.st.muted ? "unmute" : "mute [m]"
                        color: audioWin.st.muted ? Theme.bgSolid : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: muteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.audioToggleMute())
                    }
                }
            }

            // Curseur de volume principal (0 - 100%)
            Rectangle {
                id: outSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                color: Theme.sep
                radius: 0

                Rectangle {
                    width: Math.round((Math.min(100, audioWin.st.vol || 0) / 100.0) * parent.width)
                    height: parent.height
                    color: audioWin.st.muted ? Theme.disabled : Theme.accent
                    radius: 0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function applyVol(mx) {
                        let pct = Math.round(Math.max(0, Math.min(1, mx / outSlider.width)) * 100);
                        SysState.audioSetVolume(pct);
                    }
                    onPressed: mouse => applyVol(mouse.x)
                    onPositionChanged: mouse => { if (pressed) applyVol(mouse.x); }
                    onWheel: wheel => {
                        let d = wheel.angleDelta.y > 0 ? 2 : -2;
                        SysState.audioSetVolume(Math.max(0, Math.min(100, (audioWin.st.vol || 0) + d)));
                    }
                }
            }

            // --- MICROPHONE : Input Volume + Mute [i] ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: (audioWin.st.micMuted ? "󰍭  mic muted" : ("󰍬  input · " + (audioWin.st.micVol || 0) + "%"))
                    color: audioWin.st.micMuted ? Theme.muted : Theme.fg
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 58
                    height: 20
                    radius: 0
                    color: audioWin.st.micMuted ? Theme.urgent : (micMuteMouse.containsMouse ? Theme.hoverBg : "transparent")
                    border.color: audioWin.st.micMuted ? Theme.urgent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: audioWin.st.micMuted ? "muted" : "mic [i]"
                        color: audioWin.st.micMuted ? Theme.bgSolid : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: micMuteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.audioToggleMic())
                    }
                }
            }

            Rectangle {
                id: micSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                color: Theme.sep
                radius: 0

                Rectangle {
                    width: Math.round((Math.min(100, audioWin.st.micVol || 0) / 100.0) * parent.width)
                    height: parent.height
                    color: audioWin.st.micMuted ? Theme.disabled : Theme.fg
                    radius: 0
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function applyMic(mx) {
                        let pct = Math.round(Math.max(0, Math.min(1, mx / micSlider.width)) * 100);
                        SysState.audioSetMicVolume(pct);
                    }
                    onPressed: mouse => applyMic(mouse.x)
                    onPositionChanged: mouse => { if (pressed) applyMic(mouse.x); }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            // --- PÉRIPHÉRIQUES DE SORTIE (Output Devices) ---
            Text {
                text: "output devices"
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 11
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: (audioWin.st && audioWin.st.sinks) ? audioWin.st.sinks : []
                    delegate: Rectangle {
                        required property var modelData
                        property bool isAct: Boolean(modelData.active)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: 0
                        color: isAct ? Theme.hoverBg : (sinkMouse.containsMouse ? "#1b1b1e" : "transparent")
                        border.color: isAct ? Theme.accent : Theme.sep
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: parent.parent.isAct ? "●" : "·"
                                color: parent.parent.isAct ? Theme.accent : Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                            }

                            Text {
                                text: modelData.desc || modelData.name
                                color: parent.parent.isAct ? Theme.accent : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: sinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: Qt.callLater(() => SysState.audioSetSink(modelData.name))
                        }
                    }
                }
            }

            // --- PÉRIPHÉRIQUES D'ENTRÉE (Input Devices) ---
            Text {
                visible: Boolean(audioWin.st.sources && audioWin.st.sources.length > 0)
                text: "input devices"
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 11
            }

            ColumnLayout {
                visible: Boolean(audioWin.st.sources && audioWin.st.sources.length > 0)
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: (audioWin.st && audioWin.st.sources) ? audioWin.st.sources : []
                    delegate: Rectangle {
                        required property var modelData
                        property bool isAct: Boolean(modelData.active)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 0
                        color: isAct ? Theme.hoverBg : (srcMouse.containsMouse ? "#1b1b1e" : "transparent")
                        border.color: isAct ? Theme.accent : Theme.sep
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            Text {
                                text: parent.parent.isAct ? "●" : "·"
                                color: parent.parent.isAct ? Theme.accent : Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                            }

                            Text {
                                text: modelData.desc || modelData.name
                                color: parent.parent.isAct ? Theme.accent : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: srcMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: Qt.callLater(() => SysState.audioSetSource(modelData.name))
                        }
                    }
                }
            }

            // --- MIXEUR PAR APPLICATION (Applications) ---
            Rectangle {
                visible: Boolean(audioWin.st.apps && audioWin.st.apps.length > 0)
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            Text {
                visible: Boolean(audioWin.st.apps && audioWin.st.apps.length > 0)
                text: "applications"
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 11
            }

            ColumnLayout {
                visible: Boolean(audioWin.st.apps && audioWin.st.apps.length > 0)
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: (audioWin.st && audioWin.st.apps) ? audioWin.st.apps : []
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.name
                                color: Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.vol + "%"
                                color: Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            id: appTrack
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            color: Theme.sep
                            radius: 0

                            Rectangle {
                                width: Math.round((Math.min(100, modelData.vol || 0) / 100.0) * parent.width)
                                height: parent.height
                                color: Theme.accent
                                radius: 0
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => {
                                    let pct = Math.round(Math.max(0, Math.min(1, mouse.x / appTrack.width)) * 100);
                                    Qt.callLater(() => SysState.audioSetAppVol(modelData.id, pct));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
