import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

// Tailscale menu (core/Tailnet.qml): on/off, this device and the tailnet's devices.
// Click a device copies its IP, right click its MagicDNS name.
// Keys: t on/off (or log in) · c copy this device's IP · r refresh · Tab next menu · Esc close.
PanelWindow {
    id: tsWin

    visible: SysState.tailscaleMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-tailscale"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property string suffix: Tailnet.self ? Tailnet.self.dns.split(".").slice(1).join(".") : ""

    onVisibleChanged: {
        if (!visible) return;
        Tailnet.error = "";
        keyCatcher.forceActiveFocus();
        focusRetry.restart();
    }
    Timer {
        id: focusRetry
        interval: 25
        onTriggered: if (tsWin.visible) keyCatcher.forceActiveFocus()
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            let k = event.key;
            if (k === Qt.Key_Escape) SysState.tailscaleMenuOpen = false;
            else if (k === Qt.Key_T) Tailnet.toggle();
            else if (k === Qt.Key_R) Tailnet.refresh();
            else if (k === Qt.Key_C && Tailnet.self) Tailnet.copy(Tailnet.self.ipv4);
            else if (k === Qt.Key_Tab) {
                SysState.tailscaleMenuOpen = false;
                SysState.btMenuOpen = true;
            } else return;
            event.accepted = true;
        }
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onPressed: SysState.tailscaleMenuOpen = false
    }

    // One device: dot, name, last seen (offline), IP; click copies the IP, right click the name
    component DeviceRow: Rectangle {
        id: row
        required property var device
        property bool isSelf: false
        readonly property bool justCopied: Tailnet.copied !== "" && (Tailnet.copied === device.ipv4 || Tailnet.copied === device.dns)

        Layout.fillWidth: true
        Layout.preferredHeight: 28
        color: isSelf ? Theme.hoverBg : (rowMouse.containsMouse ? Theme.rowHover : "transparent")
        border.color: isSelf || rowMouse.containsMouse ? Theme.accent : Theme.sep
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: row.device.online ? "●" : "◦"
                color: row.device.online ? Theme.accent : Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 11
            }
            Text {
                text: row.device.name + (row.device.exitNode ? "  󰁔 exit node" : "")
                color: row.isSelf ? Theme.accent : (row.device.online ? Theme.fg : Theme.muted)
                font.family: Theme.fontMain
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: !row.device.online && !row.justCopied && text !== ""
                text: Tailnet.ago(row.device.lastSeen)
                color: Theme.disabled
                font.family: Theme.fontMain
                font.pixelSize: 10
            }
            Text {
                text: row.justCopied ? "copied" : (row.device.ipv4 || "-")
                color: row.justCopied ? Theme.accent : Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 10
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => {
                keyCatcher.forceActiveFocus();
                Tailnet.copy(mouse.button === Qt.RightButton ? row.device.dns : row.device.ipv4);
            }
        }
    }

    Rectangle {
        id: card
        width: 330
        height: col.implicitHeight + 24
        // Under the bar module (centered on it), else near the right edge
        x: Tailnet.anchorX >= 0 ? Math.max(12, Math.min(parent.width - width - 12, Math.round(Tailnet.anchorX - width / 2)))
                                : parent.width - width - 140
        y: 32
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onPressed: keyCatcher.forceActiveFocus()
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // --- Header: name, state, on/off [t] ---
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰖂  tailscale"
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                Rectangle {
                    visible: Tailnet.backend !== ""
                    width: Tailnet.loggedOut ? 64 : 48
                    height: 20
                    readonly property bool on: Tailnet.running && !Tailnet.busy
                    color: on ? Theme.accent : (pwrMouse.containsMouse ? Theme.hoverBg : "transparent")
                    border.color: on || pwrMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Tailnet.loggedOut ? "log in" : (Tailnet.busy ? "…" : (parent.on ? "on" : "off"))
                        color: parent.on ? Theme.onAccent : (pwrMouse.containsMouse ? Theme.accent : Theme.muted)
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }
                    MouseArea {
                        id: pwrMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            keyCatcher.forceActiveFocus();
                            Tailnet.toggle();
                        }
                    }
                }
            }

            Text {
                text: Tailnet.stateText + (Tailnet.running && tsWin.suffix ? "  ·  " + tsWin.suffix : "")
                color: Theme.muted
                font.family: Theme.fontMain
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            // --- Not allowed to turn it on/off ---
            ColumnLayout {
                visible: Tailnet.error !== ""
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: Tailnet.error === "denied" ? "not allowed to change tailscale; once, in a terminal:" : Tailnet.error
                    color: Theme.urgent
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                Rectangle {
                    visible: Tailnet.error === "denied"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    color: Theme.bgInset
                    border.color: hintMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 8
                        width: parent.width - 16
                        text: Tailnet.copied === Tailnet.deniedHint ? "copied" : Tailnet.deniedHint
                        color: Tailnet.copied === Tailnet.deniedHint ? Theme.accent : Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: hintMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: {
                            keyCatcher.forceActiveFocus();
                            Tailnet.copy(Tailnet.deniedHint);
                        }
                    }
                }
            }

            // --- Devices (when connected) ---
            ColumnLayout {
                visible: Tailnet.running && Tailnet.self !== null
                Layout.fillWidth: true
                spacing: 3

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.bottomMargin: 5
                    color: Theme.sep
                }
                DeviceRow {
                    device: Tailnet.self || ({})
                    isSelf: true
                }
                Text {
                    Layout.topMargin: 5
                    text: Tailnet.peers.length === 0 ? "no other devices" : "devices · " + Tailnet.onlineCount + "/" + Tailnet.peers.length + " online"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 10
                }
                ListView {
                    id: list
                    Layout.fillWidth: true
                    // 8 rows at most, then it scrolls
                    Layout.preferredHeight: Math.min(count, 8) * 31 - (count > 0 ? 3 : 0)
                    visible: count > 0
                    clip: true
                    spacing: 3
                    interactive: count > 8
                    boundsBehavior: Flickable.StopAtBounds
                    model: Tailnet.peers
                    delegate: DeviceRow {
                        required property var modelData
                        device: modelData
                        width: ListView.view.width
                        height: 28
                    }
                }
            }

            // --- tailscaled's warnings ---
            Repeater {
                model: Tailnet.health
                delegate: Text {
                    required property string modelData
                    text: "⚠ " + modelData
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }

            Text {
                text: Tailnet.running ? "click copy ip · right click copy name" : (Tailnet.loggedOut ? "[t] log in" : "[t] connect")
                color: Theme.disabled
                font.family: Theme.fontMain
                font.pixelSize: 10
            }
        }
    }
}
