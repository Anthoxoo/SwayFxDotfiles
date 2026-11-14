import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: wifiWin

    visible: SysState.wifiMenuOpen
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

    property var st: SysState.wifiDetailState || ({
        enabled: true,
        connected: false,
        activeSsid: "",
        ip: "-",
        networks: []
    })

    property string pendingSsid: ""

    onVisibleChanged: {
        if (visible) {
            pendingSsid = "";
            pwdInput.text = "";
            SysState.refreshWifiDetails(false);
            keyCatcher.forceActiveFocus();
            focusRetry.restart();
        }
    }

    Timer {
        id: focusRetry
        interval: 25
        repeat: false
        onTriggered: {
            if (wifiWin.visible) {
                if (wifiWin.pendingSsid !== "") pwdInput.forceActiveFocus();
                else keyCatcher.forceActiveFocus();
            }
        }
    }

    function sigIcon(sig) {
        if (sig >= 80) return "󰤨";
        if (sig >= 60) return "󰤥";
        if (sig >= 40) return "󰤢";
        if (sig >= 20) return "󰤟";
        return "󰤯";
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (wifiWin.pendingSsid !== "") {
                    wifiWin.pendingSsid = "";
                    pwdInput.text = "";
                } else {
                    SysState.wifiMenuOpen = false;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                SysState.wifiToggleRadio();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                SysState.refreshWifiDetails(true);
                event.accepted = true;
            } else if (event.key === Qt.Key_D && wifiWin.st.connected) {
                SysState.wifiDisconnect();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                SysState.wifiMenuOpen = false;
                SysState.btMenuOpen = true;
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: SysState.wifiMenuOpen = false
    }

    Rectangle {
        width: 320
        height: Math.max(80, mainCol.implicitHeight + 24)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 120
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        MouseArea {
            anchors.fill: parent
            onPressed: {
                if (wifiWin.pendingSsid !== "") pwdInput.forceActiveFocus();
                else keyCatcher.forceActiveFocus();
            }
        }

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // --- EN-TÊTE : Wi-Fi + IP + Scan [r] + On/Off [t] ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰤨  wi-fi" + (wifiWin.st.ip && wifiWin.st.ip !== "-" ? (" · " + wifiWin.st.ip) : "")
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                // Bouton Scan [r]
                Rectangle {
                    visible: Boolean(wifiWin.st.enabled)
                    width: 24
                    height: 20
                    radius: 0
                    color: scanMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: scanMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: SysState.wifiScanning ? "…" : "󰑐"
                        color: scanMouse.containsMouse ? Theme.accent : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: scanMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.refreshWifiDetails(true))
                    }
                }

                // Bouton Radio On/Off [t]
                Rectangle {
                    width: 48
                    height: 20
                    radius: 0
                    color: wifiWin.st.enabled ? Theme.accent : (radMouse.containsMouse ? Theme.hoverBg : "transparent")
                    border.color: wifiWin.st.enabled ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: wifiWin.st.enabled ? "on" : "off"
                        color: wifiWin.st.enabled ? Theme.bgSolid : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: radMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.wifiToggleRadio())
                    }
                }
            }

            // Message si Wi-Fi désactivé
            Text {
                visible: !wifiWin.st.enabled
                text: "wi-fi radio is disabled [t]"
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 12
            }

            // --- CHAMP MOT DE PASSE (affiché si clic sur un réseau inconnu sécurisé) ---
            ColumnLayout {
                visible: wifiWin.pendingSsid !== ""
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "password for " + wifiWin.pendingSsid.toLowerCase()
                        color: Theme.accent
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "×"
                        color: cancelPwdMouse.containsMouse ? Theme.accent : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                        MouseArea {
                            id: cancelPwdMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                wifiWin.pendingSsid = "";
                                pwdInput.text = "";
                                keyCatcher.forceActiveFocus();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    color: "#0e0e10"
                    border.color: Theme.accent
                    border.width: 1
                    radius: 0

                    TextInput {
                        id: pwdInput
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        echoMode: TextInput.Password
                        clip: true
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (pwdInput.text.length > 0) {
                                    SysState.wifiConnect(wifiWin.pendingSsid, pwdInput.text);
                                    wifiWin.pendingSsid = "";
                                    pwdInput.text = "";
                                    keyCatcher.forceActiveFocus();
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                wifiWin.pendingSsid = "";
                                pwdInput.text = "";
                                keyCatcher.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        visible: pwdInput.text.length === 0
                        text: "enter password + return..."
                        color: Theme.disabled
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }
            }

            Rectangle {
                visible: Boolean(wifiWin.st.enabled)
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            // --- LISTE DES RÉSEAUX WI-FI ---
            ColumnLayout {
                visible: Boolean(wifiWin.st.enabled)
                Layout.fillWidth: true
                spacing: 3

                Repeater {
                    model: (wifiWin.st && wifiWin.st.networks) ? wifiWin.st.networks : []
                    delegate: Rectangle {
                        required property var modelData
                        property bool isAct: Boolean(modelData.active)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: 0
                        color: isAct ? Theme.hoverBg : (netMouse.containsMouse ? "#1b1b1e" : "transparent")
                        border.color: isAct ? Theme.accent : (netMouse.containsMouse ? Theme.accent : Theme.sep)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: wifiWin.sigIcon(modelData.signal || 0)
                                color: parent.parent.isAct ? Theme.accent : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                            }

                            Text {
                                text: (modelData.ssid || "").toLowerCase()
                                color: parent.parent.isAct ? Theme.accent : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: {
                                    if (parent.parent.isAct) return "connected";
                                    if (modelData.saved) return "saved";
                                    if (modelData.secure) return "󰌾 " + (modelData.signal || 0) + "%";
                                    return (modelData.signal || 0) + "%";
                                }
                                color: parent.parent.isAct ? Theme.accent : Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                            }

                            // Bouton oublier (×) pour les réseaux enregistrés non actifs
                            Text {
                                visible: Boolean(modelData.saved && !parent.parent.isAct)
                                text: "×"
                                color: forgetMouse.containsMouse ? Theme.urgent : Theme.disabled
                                font.family: Theme.fontMain
                                font.pixelSize: 13

                                MouseArea {
                                    id: forgetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: Qt.callLater(() => SysState.wifiForget(modelData.ssid))
                                }
                            }
                        }

                        MouseArea {
                            id: netMouse
                            anchors.fill: parent
                            z: -1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                if (modelData.active) {
                                    Qt.callLater(() => SysState.wifiDisconnect());
                                } else if (modelData.saved || !modelData.secure) {
                                    wifiWin.pendingSsid = "";
                                    Qt.callLater(() => SysState.wifiConnect(modelData.ssid, ""));
                                } else {
                                    wifiWin.pendingSsid = modelData.ssid;
                                    pwdInput.text = "";
                                    pwdInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
