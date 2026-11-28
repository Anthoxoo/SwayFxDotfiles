import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Layouts
import "../core"

// Polkit authentication agent (replaces polkit-kde-agent): the password dialog shown when an
// app needs admin rights (pkexec, Nautilus, NetworkManager, systemctl, software updates...).
// Enter authenticates, Escape cancels, Tab switches identity when there is a choice.
// The request's message and prompt come from polkit/PAM, in the system language.
// A session has a single agent: if Quickshell can't register (another agent already runs, e.g.
// one started by hand), sway/scripts/polkit-agent.sh starts a desktop agent instead (if none runs).
Scope {
    id: root

    readonly property var flow: agent.flow
    property bool checking: false   // a password was sent, waiting for polkit's answer
    property int failures: 0

    PolkitAgent {
        id: agent
        // Other menus hold the keyboard (exclusive focus): close them first
        onAuthenticationRequestStarted: {
            SysState.closeAllPopups();
            root.checking = false;
            root.failures = 0;
        }
    }

    Timer {
        interval: 3000
        running: true
        onTriggered: {
            if (agent.isRegistered) return;
            console.warn("polkit: Quickshell is not the session's agent, starting polkit-agent.sh");
            fallback.startDetached();
        }
    }
    Process {
        id: fallback
        command: [Quickshell.env("HOME") + "/.config/sway/scripts/polkit-agent.sh"]
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() {
            root.checking = false;
            root.failures++;
            shake.restart();
        }
        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired) {
                root.checking = false;
                pwdInput.forceActiveFocus();
            }
        }
    }

    function submit() {
        if (!flow || !flow.isResponseRequired || checking) return;
        checking = true;
        flow.submit(pwdInput.text);
        pwdInput.text = "";
    }

    function cancel() {
        pwdInput.text = "";
        if (flow) flow.cancelAuthenticationRequest();
    }

    // "unix-user:antoine" -> "antoine" (displayName is the account's full name, often stale)
    function identityName(identity) {
        if (!identity) return "";
        let name = identity.string.replace(/^unix-(user|group):/, "");
        return identity.isGroup ? "group " + name : name;
    }

    function nextIdentity() {
        if (!flow || flow.identities.length < 2) return;
        let ids = Array.from(flow.identities);
        flow.selectedIdentity = ids[(ids.indexOf(flow.selectedIdentity) + 1) % ids.length];
    }

    PanelWindow {
        id: win

        visible: agent.isActive && root.flow !== null
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "qs-polkit"
        exclusionMode: ExclusionMode.Ignore
        color: Theme.alpha(Theme.bgSolid, 0.5)

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onVisibleChanged: {
            pwdInput.text = "";
            if (!visible) return;
            pwdInput.forceActiveFocus();
            focusRetry.restart();
        }

        Timer {
            id: focusRetry
            interval: 25
            onTriggered: if (win.visible) pwdInput.forceActiveFocus()
        }

        // Clicks outside the card do nothing (the request stays until answered or cancelled)
        MouseArea {
            anchors.fill: parent
            onPressed: pwdInput.forceActiveFocus()
        }

        Rectangle {
            id: card
            width: 440
            height: col.implicitHeight + 36
            anchors.centerIn: parent
            color: Theme.bgSolid
            border.color: Theme.accent
            border.width: 1

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -10; duration: 40 }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 10; duration: 80 }
                NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
            }

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 18
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: "󰌾   authentication required"
                    font.family: Theme.fontMain
                    font.pixelSize: 15
                    color: Theme.accent
                }

                Text {
                    Layout.fillWidth: true
                    text: root.flow ? root.flow.message : ""
                    wrapMode: Text.Wrap
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    color: Theme.fg
                }

                // What is being asked for, for the curious: the polkit action
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow ? root.flow.actionId : ""
                    elide: Text.ElideMiddle
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    color: Theme.placeholder
                }

                // Who authenticates: a line, or a choice when polkit offers several identities
                Text {
                    visible: !!root.flow && root.flow.identities.length === 1
                    text: "as " + root.identityName(root.flow ? root.flow.selectedIdentity : null)
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    color: Theme.muted
                }
                Flow {
                    Layout.fillWidth: true
                    visible: !!root.flow && root.flow.identities.length > 1
                    spacing: 6
                    Repeater {
                        model: root.flow ? root.flow.identities : []
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool isSelected: !!root.flow && modelData === root.flow.selectedIdentity
                            width: chipText.implicitWidth + 20
                            height: 26
                            color: isSelected ? Theme.hoverBg : "transparent"
                            border.color: isSelected ? Theme.accent : Theme.border
                            border.width: 1
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: root.identityName(chip.modelData)
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                                color: chip.isSelected ? Theme.accent : Theme.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: {
                                    root.flow.selectedIdentity = chip.modelData;
                                    pwdInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // Password field (same look as the lock screen)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 44
                    color: Theme.bgInset
                    border.width: 2
                    border.color: {
                        if (root.checking) return Theme.fg;
                        if (root.failures > 0 && pwdInput.text.length === 0) return Theme.urgent;
                        return Theme.accent;
                    }

                    TextInput {
                        id: pwdInput
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        // Hidden input under the dots, unless polkit asks for something visible (a user name...)
                        readonly property bool shown: root.flow ? root.flow.responseVisible : false
                        opacity: shown ? 1 : 0
                        enabled: !root.checking
                        echoMode: shown ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        color: Theme.fg

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.submit();
                            else if (event.key === Qt.Key_Escape) root.cancel();
                            else if (event.key === Qt.Key_Tab) root.nextIdentity();
                            else return;
                            event.accepted = true;
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: pwdInput.text.length === 0
                        text: {
                            if (root.checking) return "verifying...";
                            if (root.failures > 0) return "wrong password, try again";
                            // PAM's own prompt when it isn't a password ("Password:" in any language otherwise)
                            if (pwdInput.shown && root.flow && root.flow.inputPrompt) return root.flow.inputPrompt.trim();
                            return "password...";
                        }
                        color: root.checking ? Theme.fg : (root.failures > 0 ? Theme.urgent : Theme.placeholder)
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                        font.italic: true
                    }

                    // Static dots: nothing blinks while typing (as on the lock screen)
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        visible: !pwdInput.shown && pwdInput.text.length > 0 && !root.checking
                        Repeater {
                            model: 24
                            delegate: Rectangle {
                                required property int index
                                visible: index < pwdInput.text.length
                                width: 10
                                height: 10
                                radius: 5
                                antialiasing: true
                                color: Theme.fg
                            }
                        }
                    }
                }

                // PAM / polkit extra message (e.g. an account problem)
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow ? root.flow.supplementaryMessage.trim() : ""
                    wrapMode: Text.Wrap
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    color: !!root.flow && root.flow.supplementaryIsError ? Theme.urgent : Theme.muted
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: "⏎ authenticate · esc cancel"
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        color: Theme.placeholder
                    }

                    Repeater {
                        model: [
                            { label: "cancel", primary: false },
                            { label: "authenticate", primary: true }
                        ]
                        delegate: Rectangle {
                            id: btn
                            required property var modelData
                            implicitWidth: btnText.implicitWidth + 24
                            implicitHeight: 30
                            color: btn.modelData.primary ? (btnMouse.containsMouse ? Theme.fg : Theme.accent)
                                                         : (btnMouse.containsMouse ? Theme.hoverBg : "transparent")
                            border.color: btn.modelData.primary ? "transparent" : Theme.border
                            border.width: 1
                            opacity: btn.modelData.primary && root.checking ? 0.5 : 1
                            Text {
                                id: btnText
                                anchors.centerIn: parent
                                text: btn.modelData.label
                                font.family: Theme.fontMain
                                font.pixelSize: 13
                                color: btn.modelData.primary ? Theme.onAccent : Theme.fg
                            }
                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: btn.modelData.primary ? root.submit() : root.cancel()
                            }
                        }
                    }
                }
            }
        }
    }
}
