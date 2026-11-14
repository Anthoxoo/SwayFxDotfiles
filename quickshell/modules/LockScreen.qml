import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import "../core"

// Verrouillage via ext-session-lock : c'est sway qui tient le verrou.
// - si Quickshell plante, l'écran reste verrouillé (sway n'affiche rien d'autre)
// - au redémarrage, SysState relit le marqueur et re-verrouille
// - l'authentification passe par PAM en mémoire (le mot de passe n'apparaît dans aucun processus)
Scope {
    id: lockRoot

    // État partagé entre les surfaces (une par écran)
    property string currentText: ""
    property bool isChecking: false
    property bool hasFailed: false
    property int failAttempts: 0
    property string timeStr: "00:00"
    property string dateStr: ""

    readonly property string currentUser: Quickshell.env("USER") || "user"

    property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    property string mediaText: {
        if (!player) return "";
        let art = player.trackArtist || "";
        let tit = player.trackTitle || "";
        if (!tit && !art) return "";
        return "󰎆  " + ((art && tit) ? (art + " — " + tit) : (tit || art));
    }

    function updateClock() {
        let now = new Date();
        timeStr = String(now.getHours()).padStart(2, "0") + ":" + String(now.getMinutes()).padStart(2, "0");
        let days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
        let months = ["january", "february", "march", "april", "may", "june",
                      "july", "august", "september", "october", "november", "december"];
        dateStr = days[now.getDay()] + " " + String(now.getDate()).padStart(2, "0") + " " + months[now.getMonth()] + " " + now.getFullYear();
    }

    function resetState() {
        currentText = "";
        isChecking = false;
        hasFailed = false;
        failAttempts = 0;
        updateClock();
    }

    function submitPassword() {
        if (isChecking || currentText.length === 0) return;
        isChecking = true;
        hasFailed = false;
        if (!pam.start()) {
            isChecking = false;
            hasFailed = true;
            failAttempts += 1;
            currentText = "";
        }
    }

    Connections {
        target: SysState
        function onScreenLockedChanged() {
            if (SysState.screenLocked) lockRoot.resetState();
        }
    }

    Timer {
        interval: 1000
        running: SysState.screenLocked
        repeat: true
        triggeredOnStart: true
        onTriggered: lockRoot.updateClock()
    }

    PamContext {
        id: pam
        // Pile PAM minimale (pam_unix) : voir ~/.config/quickshell/pam/password.conf
        configDirectory: Quickshell.shellDir + "/pam"
        config: "password.conf"

        onPamMessage: {
            if (responseRequired) respond(lockRoot.currentText);
        }

        onCompleted: result => {
            lockRoot.isChecking = false;
            lockRoot.currentText = "";
            if (result === PamResult.Success) {
                lockRoot.hasFailed = false;
                lockRoot.failAttempts = 0;
                SysState.unlockScreen();
            } else {
                lockRoot.hasFailed = true;
                lockRoot.failAttempts += 1;
            }
        }

        onError: err => {
            lockRoot.isChecking = false;
            lockRoot.currentText = "";
            lockRoot.hasFailed = true;
            lockRoot.failAttempts += 1;
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: SysState.screenLocked
        onSecureChanged: SysState.lockSecure = secure

        WlSessionLockSurface {
            id: surface
            color: Theme.bgSolid

            // Fond d'écran courant, flouté en direct
            Image {
                id: wallImg
                anchors.fill: parent
                source: Wallpapers.currentUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(surface.width / 2, surface.height / 2)
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: wallImg
                visible: wallImg.status === Image.Ready
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                autoPaddingEnabled: false
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.alpha(Theme.bgSolid, 0.35)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.BlankCursor
                onPressed: pwdInput.forceActiveFocus()
            }

            // Horloge
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -150
                text: lockRoot.timeStr
                color: Theme.fg
                font.family: "Inter"
                font.pixelSize: 116
                font.weight: Font.Bold
                font.letterSpacing: 2
            }

            // Date
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -50
                text: lockRoot.dateStr
                color: Theme.accent
                font.family: Theme.fontMain
                font.pixelSize: 17
            }

            // Utilisateur
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 28
                text: "󰌾  " + lockRoot.currentUser
                color: Theme.subtle
                font.family: Theme.fontMain
                font.pixelSize: 18
            }

            // Champ mot de passe
            Rectangle {
                width: 280
                height: 48
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 86
                radius: 0
                color: Theme.alpha(Theme.bgSolid, 0.9)
                border.width: 2
                border.color: {
                    if (lockRoot.isChecking) return Theme.fg;
                    if (lockRoot.hasFailed && lockRoot.currentText.length === 0) return Theme.urgent;
                    return Theme.accent;
                }

                TextInput {
                    id: pwdInput
                    anchors.fill: parent
                    opacity: 0
                    focus: true
                    enabled: !lockRoot.isChecking
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhSensitiveData

                    // Synchronisé entre les écrans
                    Connections {
                        target: lockRoot
                        function onCurrentTextChanged() {
                            if (pwdInput.text !== lockRoot.currentText) pwdInput.text = lockRoot.currentText;
                        }
                    }
                    onTextChanged: {
                        if (text !== lockRoot.currentText) lockRoot.currentText = text;
                        if (text.length > 0 && lockRoot.hasFailed) lockRoot.hasFailed = false;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            lockRoot.submitPassword();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            lockRoot.currentText = "";
                            event.accepted = true;
                        }
                    }

                    Component.onCompleted: forceActiveFocus()
                }

                Text {
                    anchors.centerIn: parent
                    visible: lockRoot.currentText.length === 0
                    text: {
                        if (lockRoot.isChecking) return "verifying...";
                        if (lockRoot.hasFailed) return "authentication failed (" + lockRoot.failAttempts + ")";
                        return "password...";
                    }
                    color: {
                        if (lockRoot.isChecking) return Theme.fg;
                        if (lockRoot.hasFailed) return Theme.urgent;
                        return Theme.placeholder;
                    }
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                    font.italic: true
                }

                // 24 points statiques : aucun clignotement à la frappe
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: lockRoot.currentText.length > 0 && !lockRoot.isChecking

                    Repeater {
                        model: 24
                        delegate: Rectangle {
                            required property int index
                            visible: index < lockRoot.currentText.length
                            width: 10
                            height: 10
                            radius: 5
                            antialiasing: true
                            color: Theme.fg
                        }
                    }
                }
            }

            // Lecture en cours
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                visible: lockRoot.mediaText !== ""
                text: lockRoot.mediaText
                color: Theme.alpha(Theme.accent, 0.8)
                font.family: Theme.fontMain
                font.pixelSize: 12
            }
        }
    }
}
