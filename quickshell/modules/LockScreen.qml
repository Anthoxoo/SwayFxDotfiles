import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: lockWin

    visible: SysState.screenLocked
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: Theme.bgSolid

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property string timeStr: "00:00"
    property string dateStr: ""
    property string currentUser: Quickshell.env("USER") || "user"
    property string blurredWall: "file://" + Quickshell.env("HOME") + "/.cache/quickshell_lock_bg.png"
    property string rawWall: "file://" + Quickshell.env("HOME") + "/.config/walls/yellow-orange-ish/wall_secondary.png"

    property bool isChecking: false
    property bool hasFailed: false
    property int failAttempts: 0

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
        let hh = String(now.getHours()).padStart(2, "0");
        let mm = String(now.getMinutes()).padStart(2, "0");
        timeStr = hh + ":" + mm;

        let days = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
        let months = [
            "january", "february", "march", "april", "may", "june",
            "july", "august", "september", "october", "november", "december"
        ];
        dateStr = days[now.getDay()] + " " + String(now.getDate()).padStart(2, "0") + " " + months[now.getMonth()] + " " + now.getFullYear();
    }

    Timer {
        interval: 1000
        running: lockWin.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: lockWin.updateClock()
    }

    onVisibleChanged: {
        if (visible) {
            SysState.runCmd("swaymsg mode 'locked'");
            updateClock();
            pwdInput.text = "";
            isChecking = false;
            hasFailed = false;
            failAttempts = 0;
            pwdInput.forceActiveFocus();
            focusTimer.restart();
        } else {
            SysState.runCmd("swaymsg mode 'default'");
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: {
            if (lockWin.visible) pwdInput.forceActiveFocus();
        }
    }

    Process {
        id: authProc
        stdout: SplitParser {
            onRead: data => {
                let res = data.trim();
                lockWin.isChecking = false;
                if (res === "OK") {
                    pwdInput.text = "";
                    lockWin.hasFailed = false;
                    lockWin.failAttempts = 0;
                    SysState.unlockScreen();
                } else {
                    pwdInput.text = "";
                    lockWin.hasFailed = true;
                    lockWin.failAttempts += 1;
                    pwdInput.forceActiveFocus();
                }
            }
        }
    }

    function submitPassword() {
        if (isChecking || pwdInput.text.length === 0) return;
        isChecking = true;
        hasFailed = false;
        authProc.command = ["python3", SysState.scriptsDir + "/auth.py", pwdInput.text];
        authProc.running = true;
    }

    // Fond d'écran flouté
    Image {
        id: bgBlur
        anchors.fill: parent
        source: lockWin.blurredWall
        fillMode: Image.PreserveAspectCrop
        visible: status === Image.Ready
    }

    Image {
        id: bgRaw
        anchors.fill: parent
        source: bgBlur.status === Image.Ready ? "" : lockWin.rawWall
        fillMode: Image.PreserveAspectCrop
        visible: bgBlur.status !== Image.Ready && status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        color: bgBlur.status === Image.Ready ? "#33141416" : "#B3141416"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.BlankCursor
        onPressed: pwdInput.forceActiveFocus()
    }

    // --- MAIN CLOCK (Police Inter, 116px, centrée à -150px) ---
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -150
        text: lockWin.timeStr
        color: Theme.fg
        font.family: "Inter"
        font.pixelSize: 116
        font.weight: Font.Bold
        font.letterSpacing: 2
    }

    // --- DATE IN ENGLISH (position: -50px) ---
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -50
        text: lockWin.dateStr
        color: Theme.accent
        font.family: Theme.fontMain
        font.pixelSize: 17
    }

    // --- USER (plus lisible à 18px, compact au-dessus du champ) ---
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 28
        text: "󰌾  " + lockWin.currentUser
        color: "#b8b8bc"
        font.family: Theme.fontMain
        font.pixelSize: 18
    }

    // --- PASSWORD INPUT FIELD (280x48, position: +86px) ---
    Rectangle {
        width: 280
        height: 48
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 86
        radius: 0
        color: "#E6141416"
        border.width: 2
        border.color: {
            if (lockWin.isChecking) return Theme.fg;
            if (lockWin.hasFailed && pwdInput.text.length === 0) return Theme.urgent;
            return Theme.accent;
        }

        TextInput {
            id: pwdInput
            anchors.fill: parent
            opacity: 0
            focus: true
            echoMode: TextInput.Password
            onTextChanged: {
                if (text.length > 0 && lockWin.hasFailed) {
                    lockWin.hasFailed = false;
                }
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    lockWin.submitPassword();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    pwdInput.text = "";
                    event.accepted = true;
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: pwdInput.text.length === 0
            text: {
                if (lockWin.isChecking) return "verifying...";
                if (lockWin.hasFailed) return "authentication failed (" + lockWin.failAttempts + ")";
                return "password...";
            }
            color: {
                if (lockWin.isChecking) return Theme.fg;
                if (lockWin.hasFailed) return Theme.urgent;
                return "#6e6e70";
            }
            font.family: Theme.fontMain
            font.pixelSize: 13
            font.italic: true
        }

        // Modèle statique de 24 points : aucun clignotement à la frappe
        Row {
            anchors.centerIn: parent
            spacing: 6
            visible: pwdInput.text.length > 0 && !lockWin.isChecking

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

    // --- MEDIA PLAYER (bottom, offset 40px) ---
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        visible: lockWin.mediaText !== ""
        text: lockWin.mediaText
        color: "#CCff8800"
        font.family: Theme.fontMain
        font.pixelSize: 12
    }
}
