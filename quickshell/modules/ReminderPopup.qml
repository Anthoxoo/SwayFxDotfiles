import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

// Rappels (Super+Ctrl+R) : quoi + quand, Entrée pour valider. Liste des rappels en attente
// en dessous (clic sur × pour supprimer). Tab pour passer d'un champ à l'autre, Échap pour fermer.
PanelWindow {
    id: remWin

    visible: SysState.reminderOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-reminder"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property string errorText: ""

    // Aperçu de l'échéance pendant la saisie
    readonly property string preview: {
        let due = Reminders.parseWhen(whenInput.text);
        if (whenInput.text.trim() === "") return "";
        return due < 0 ? "?" : ("at " + Reminders.clockOf(due));
    }

    function submit() {
        let err = Reminders.add(whatInput.text, whenInput.text);
        if (err !== "") {
            errorText = err;
            if (whatInput.text.trim() === "") whatInput.forceActiveFocus();
            else whenInput.forceActiveFocus();
            return;
        }
        SysState.reminderOpen = false;
    }

    onVisibleChanged: {
        if (visible) {
            whatInput.text = "";
            whenInput.text = "";
            errorText = "";
            whatInput.forceActiveFocus();
            focusTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: 25
        onTriggered: if (remWin.visible) whatInput.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        onPressed: SysState.reminderOpen = false
    }

    Rectangle {
        width: 460
        height: col.implicitHeight + 2
        anchors.centerIn: parent
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        MouseArea {
            anchors.fill: parent
            onPressed: {}
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            spacing: 0

            // Titre
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                spacing: 8

                Text {
                    text: "\u{F009A}  reminder"
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "tab · enter · esc"
                    color: Theme.disabled
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.sep }

            // Champ "quoi"
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                spacing: 10

                Text {
                    text: "❯"
                    color: whatInput.activeFocus ? Theme.accent : Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 15
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "what? (e.g. call the bank)"
                        color: Theme.placeholder
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        visible: whatInput.text.length === 0
                    }

                    TextInput {
                        id: whatInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bgSolid
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        clip: true
                        KeyNavigation.tab: whenInput
                        onTextChanged: remWin.errorText = ""
                        Keys.onReturnPressed: whenInput.text.trim() === "" ? whenInput.forceActiveFocus() : remWin.submit()
                        Keys.onEnterPressed: whenInput.text.trim() === "" ? whenInput.forceActiveFocus() : remWin.submit()
                        Keys.onEscapePressed: SysState.reminderOpen = false
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.sep }

            // Champ "quand"
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                spacing: 10

                Text {
                    text: "\u{F0150}"
                    color: whenInput.activeFocus ? Theme.accent : Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 15
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "when? 10m · 1h30 · 17:45"
                        color: Theme.placeholder
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        visible: whenInput.text.length === 0
                    }

                    TextInput {
                        id: whenInput
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.bgSolid
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        clip: true
                        KeyNavigation.tab: whatInput
                        KeyNavigation.backtab: whatInput
                        onTextChanged: remWin.errorText = ""
                        Keys.onReturnPressed: remWin.submit()
                        Keys.onEnterPressed: remWin.submit()
                        Keys.onEscapePressed: SysState.reminderOpen = false
                    }
                }

                Text {
                    text: remWin.preview
                    color: remWin.preview === "?" ? Theme.urgent : Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                }
            }

            // Erreur
            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.bottomMargin: 6
                visible: remWin.errorText !== ""
                text: remWin.errorText
                color: Theme.urgent
                font.family: Theme.fontMain
                font.pixelSize: 11
            }

            // Rappels en attente
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
                visible: Reminders.count > 0
            }

            Repeater {
                model: Reminders.items

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    color: rowMouse.containsMouse ? Theme.rowHover : "transparent"

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: Reminders.clockOf(modelData.due)
                            color: Theme.accent
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            Layout.preferredWidth: 78
                        }
                        Text {
                            text: modelData.text
                            color: Theme.fg
                            elide: Text.ElideRight
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "in " + Reminders.remaining(modelData.due)
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }
                        Text {
                            text: "×"
                            color: delMouse.containsMouse ? Theme.urgent : Theme.disabled
                            font.family: Theme.fontMain
                            font.pixelSize: 15

                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: Reminders.remove(modelData.id)
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: Reminders.count > 0 ? 4 : 0 }
        }
    }
}
