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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property var st: SysState.podsState || ({
        running: false,
        connected: false,
        mode: "anc",
        modes: ["anc", "adaptive", "transparency", "off"],
        adaptiveLevel: 50,
        ca: false,
        oneBud: true,
        ear: "one",
        audioProfile: "a2dp"
    })

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
            } else if (event.key === Qt.Key_M) {
                let nextProf = (podsWin.st.audioProfile === "hfp") ? "a2dp" : "hfp";
                SysState.podsSetProfile(nextProf);
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                SysState.podsCmd("reopen");
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                SysState.podsSetAdaptive(Math.max(0, (podsWin.st.adaptiveLevel || 50) - 5));
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                SysState.podsSetAdaptive(Math.min(100, (podsWin.st.adaptiveLevel || 50) + 5));
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
        width: 334
        height: Math.max(80, mainCol.implicitHeight + 24)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 85
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

            // --- EN-TÊTE : Modèle + Boutons Resync [r] & Connect/Disconnect ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󱡏  " + (podsWin.st.name || "airpods").toLowerCase()
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Bouton Resync AAP [r]
                Rectangle {
                    visible: Boolean(podsWin.st.connected)
                    width: 24
                    height: 20
                    radius: 0
                    color: resyncMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: resyncMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰑐"
                        color: resyncMouse.containsMouse ? Theme.accent : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: resyncMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.podsCmd("reopen"))
                    }
                }

                // Bouton Connect / Disconnect Bluetooth
                Rectangle {
                    width: connTxt.implicitWidth + 14
                    height: 20
                    radius: 0
                    color: connMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: podsWin.st.connected ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        id: connTxt
                        anchors.centerIn: parent
                        text: podsWin.st.connected ? "connected" : "connect"
                        color: podsWin.st.connected ? Theme.accent : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: connMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.podsCmd("bt-toggle"))
                    }
                }
            }

            // --- SECTION BATTERIES (Left, Right, Case + indicateurs in-ear / charge) ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: ["left", "right", "case"]
                    delegate: RowLayout {
                        required property string modelData
                        property var podObj: (podsWin.st && podsWin.st[modelData]) ? podsWin.st[modelData] : ({ level: -1, charging: false, inEar: false })
                        property int lvl: podObj.level !== undefined ? podObj.level : -1
                        property bool chg: Boolean(podObj.charging)
                        property bool ear: Boolean(podObj.inEar)

                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: modelData
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            Layout.preferredWidth: 38
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 8
                            color: Theme.sep
                            radius: 0

                            Rectangle {
                                width: parent.parent.lvl > 0 ? Math.round((parent.parent.lvl / 100.0) * parent.width) : 0
                                height: parent.height
                                color: (parent.parent.lvl <= 15 && parent.parent.lvl > 0) ? Theme.urgent : Theme.accent
                                radius: 0
                            }
                        }

                        Text {
                            text: {
                                if (parent.lvl <= 0) return "-";
                                let stTag = parent.chg ? " 󰂄" : (parent.ear ? " in" : "");
                                return parent.lvl + "%" + stTag;
                            }
                            color: parent.ear ? Theme.accent : Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            // --- SECTION 1 : NOISE CONTROL (Grille 2x2) ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "noise control"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "[n / a / t / o]"
                    color: Theme.disabled
                    font.family: Theme.fontMain
                    font.pixelSize: 10
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 4
                columnSpacing: 4

                Repeater {
                    model: [
                        { id: "anc",          label: "󰍬  noise cancel", key: "n" },
                        { id: "adaptive",     label: "◐  adaptive",     key: "a" },
                        { id: "transparency", label: "󰍭  transparency", key: "t" },
                        { id: "off",          label: "·  off",          key: "o" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        property bool isAct: podsWin.st.mode === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 0
                        color: isAct ? Theme.accent : (mMouse.containsMouse ? Theme.hoverBg : "transparent")
                        border.color: isAct ? Theme.accent : (mMouse.containsMouse ? Theme.accent : Theme.sep)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8

                            Text {
                                text: modelData.label
                                color: parent.parent.isAct ? Theme.bgSolid : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: modelData.key
                                color: parent.parent.isAct ? Theme.bgSolid : Theme.disabled
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                            }
                        }

                        MouseArea {
                            id: mMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                keyCatcher.forceActiveFocus();
                                Qt.callLater(() => SysState.podsSetMode(modelData.id));
                            }
                        }
                    }
                }
            }

            // --- SECTION 2 : ADAPTIVE NOISE LEVEL (Curseur + 3 Préréglages) ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                opacity: podsWin.st.mode === "adaptive" ? 1.0 : 0.55

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "adaptive noise level"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (podsWin.st.adaptiveLevel !== undefined ? podsWin.st.adaptiveLevel : 50) + "%"
                        color: podsWin.st.mode === "adaptive" ? Theme.accent : Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }

                // Curseur 0-100%
                Rectangle {
                    id: adaptTrack
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    color: Theme.sep
                    radius: 0

                    Rectangle {
                        width: Math.round(((podsWin.st.adaptiveLevel !== undefined ? podsWin.st.adaptiveLevel : 50) / 100.0) * parent.width)
                        height: parent.height
                        color: Theme.accent
                        radius: 0
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function applyMouse(mx) {
                            let pct = Math.round(Math.max(0, Math.min(1, mx / adaptTrack.width)) * 100);
                            if (podsWin.st.mode !== "adaptive") {
                                SysState.podsSetMode("adaptive");
                            }
                            SysState.podsSetAdaptive(pct);
                        }
                        onPressed: mouse => applyMouse(mouse.x)
                        onPositionChanged: mouse => { if (pressed) applyMouse(mouse.x); }
                        onWheel: wheel => {
                            let step = wheel.angleDelta.y > 0 ? 5 : -5;
                            let next = Math.max(0, Math.min(100, (podsWin.st.adaptiveLevel || 50) + step));
                            SysState.podsSetAdaptive(next);
                        }
                    }
                }

                // 3 Préréglages rapides (Quiet 20% / Balanced 50% / Ambient 80%)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "quiet 20%",    val: 20 },
                            { label: "balanced 50%", val: 50 },
                            { label: "ambient 80%",  val: 80 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            property bool isCur: Math.abs((podsWin.st.adaptiveLevel || 50) - modelData.val) <= 5 && podsWin.st.mode === "adaptive"

                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            radius: 0
                            color: isCur ? Theme.hoverBg : (preMouse.containsMouse ? "#1b1b1e" : "transparent")
                            border.color: isCur ? Theme.accent : Theme.sep
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: isCur ? Theme.accent : Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: preMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    if (podsWin.st.mode !== "adaptive") {
                                        SysState.podsSetMode("adaptive");
                                    }
                                    Qt.callLater(() => SysState.podsSetAdaptive(modelData.val));
                                }
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

            // --- SECTION 3 : AWARENESS & ANC OPTIONS ---
            // Conversation Awareness [c]
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "conversation awareness [c]"
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                    }
                    Text {
                        text: "lowers media volume when you speak"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    width: 52
                    height: 24
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
                        onPressed: Qt.callLater(() => SysState.podsToggleCa())
                    }
                }
            }

            // One-Bud ANC [b]
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: "one-bud anc [b]"
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                    }
                    Text {
                        text: "allow noise cancellation with 1 pod"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    width: 52
                    height: 24
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
                        onPressed: Qt.callLater(() => SysState.podsToggleOneBud())
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            // --- SECTION 4 : EAR DETECTION (Sélecteur 3 boutons) ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "ear detection (auto-pause) [e]"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { id: "one",  label: "1 pod out" },
                        { id: "both", label: "both out" },
                        { id: "off",  label: "never" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        property bool isCur: (podsWin.st.ear || "one") === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 0
                        color: isCur ? Theme.accent : (earBtnMouse.containsMouse ? Theme.hoverBg : "transparent")
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
                            id: earBtnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: Qt.callLater(() => SysState.podsSetEar(modelData.id))
                        }
                    }
                }
            }

            // --- SECTION 5 : PROFIL AUDIO PIPEWIRE (A2DP High-Res vs Headset Mic) ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "audio profile [m]"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { id: "a2dp", label: "󰎆  a2dp high-res" },
                        { id: "hfp",  label: "󰍬  headset + mic" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        property bool isCur: (podsWin.st.audioProfile || "a2dp") === modelData.id

                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 0
                        color: isCur ? Theme.hoverBg : (profMouse.containsMouse ? "#1b1b1e" : "transparent")
                        border.color: isCur ? Theme.accent : Theme.sep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: isCur ? Theme.accent : Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: profMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: Qt.callLater(() => SysState.podsSetProfile(modelData.id))
                        }
                    }
                }
            }
        }
    }
}
