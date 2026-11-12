import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: notifWindow

    visible: notifRepeater.count > 0
    focusable: false
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        right: true
    }
    margins {
        top: 34
        right: 12
    }

    implicitWidth: 340
    implicitHeight: notifCol.implicitHeight

    NotificationServer {
        id: notifServer
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notif => {
            if (SysState.dndMode && notif.urgency !== NotificationUrgency.Critical) {
                notif.expire();
                return;
            }
            notif.tracked = true;
        }
    }

    Connections {
        target: SysState
        function onClearNotificationsRequested() {
            let list = notifServer.trackedNotifications.values;
            for (let i = list.length - 1; i >= 0; i--) {
                list[i].dismiss();
            }
        }
    }

    ColumnLayout {
        id: notifCol
        width: 340
        spacing: 8

        Repeater {
            id: notifRepeater
            model: notifServer.trackedNotifications

            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index

                visible: index < 5
                Layout.fillWidth: true
                implicitHeight: innerCol.implicitHeight + 22
                radius: 0
                color: cardMouse.containsMouse ? "#18181b" : Theme.bgSolid
                border.width: 1
                border.color: isCritical ? Theme.urgent : Theme.accent

                property bool isCritical: modelData.urgency === NotificationUrgency.Critical
                property int totalMs: {
                    let t = modelData.expireTimeout;
                    if (t > 0) return t < 100 ? t * 1000 : t;
                    return isCritical ? 10000 : 5000;
                }
                property int remainingMs: totalMs

                // Liseré vertical gauche 2px
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 2
                    color: card.isCritical ? Theme.urgent : Theme.accent
                }

                // Jauge fine de temps restant en bas (1px)
                Rectangle {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    height: 2
                    width: Math.max(0, Math.round((card.remainingMs / card.totalMs) * parent.width))
                    color: card.isCritical ? Theme.urgent : Theme.accent
                }

                Timer {
                    interval: 50
                    running: card.visible && !cardMouse.containsMouse
                    repeat: true
                    onTriggered: {
                        card.remainingMs -= 50;
                        if (card.remainingMs <= 0) {
                            card.modelData.expire();
                        }
                    }
                }

                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            card.modelData.dismiss();
                        } else if (mouse.button === Qt.LeftButton) {
                            let acts = card.modelData.actions;
                            for (let i = 0; i < acts.length; i++) {
                                if (acts[i].identifier === "default") {
                                    acts[i].invoke();
                                    break;
                                }
                            }
                            card.modelData.dismiss();
                        }
                    }
                }

                ColumnLayout {
                    id: innerCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    anchors.topMargin: 10
                    spacing: 6

                    // En-tête : nom de l'application + croix de fermeture
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: (card.modelData.appName || "system").toLowerCase()
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "×"
                            color: closeMouse.containsMouse ? Theme.accent : Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 14

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: card.modelData.dismiss()
                            }
                        }
                    }

                    // Titre (Summary)
                    Text {
                        visible: (card.modelData.summary || "") !== ""
                        text: card.modelData.summary || ""
                        color: card.isCritical ? Theme.urgent : Theme.accent
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }

                    // Corps du message (Body)
                    Text {
                        visible: (card.modelData.body || "") !== ""
                        text: card.modelData.body || ""
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        textFormat: Text.StyledText
                        Layout.fillWidth: true
                    }

                    // Boutons d'actions D-Bus (si présents hors "default")
                    RowLayout {
                        visible: card.modelData.actions && card.modelData.actions.length > 0
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: card.modelData.actions
                            delegate: Rectangle {
                                required property var modelData
                                visible: modelData.identifier !== "default" && (modelData.text || "") !== ""
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                radius: 0
                                color: actMouse.containsMouse ? Theme.hoverBg : "transparent"
                                border.color: actMouse.containsMouse ? Theme.accent : Theme.sep
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.text || "").toLowerCase()
                                    color: actMouse.containsMouse ? Theme.accent : Theme.fg
                                    font.family: Theme.fontMain
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: actMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: {
                                        modelData.invoke();
                                        card.modelData.dismiss();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
