import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "../core"

// Media popup, opened by a click on the bar's media module (modules/Mpris.qml) or
// `qs ipc call shell toggle media`: artwork, title, progress (click or drag to seek), controls,
// volume and the player choice when several play.
// Keys: Space play/pause, ←/→ seek 5 s, p / n previous / next, s shuffle, r loop, Tab next player,
// Escape closes. A click on the title brings the player's window up.
PanelWindow {
    id: mediaWin

    visible: SysState.mediaMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-media-menu"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Round control button (previous, play/pause, next, shuffle, loop)
    component CtrlButton: Rectangle {
        id: ctrl
        property string icon: ""
        property bool on: false        // shuffle / loop active
        property bool primary: false   // play / pause
        property bool usable: true
        signal activated()
        implicitWidth: primary ? 44 : 34
        implicitHeight: primary ? 36 : 30
        opacity: usable ? 1 : 0.35
        color: primary ? (ctrlMouse.containsMouse && usable ? Theme.fg : Theme.accent)
                       : (ctrlMouse.containsMouse && usable ? Theme.hoverBg : "transparent")
        Text {
            anchors.centerIn: parent
            text: ctrl.icon
            color: ctrl.primary ? Theme.onAccent : (ctrl.on ? Theme.accent : Theme.fg)
            font.family: Theme.fontMain
            font.pixelSize: ctrl.primary ? 20 : 16
        }
        MouseArea {
            id: ctrlMouse
            anchors.fill: parent
            enabled: ctrl.usable
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ctrl.activated()
        }
    }

    readonly property var player: Media.player
    readonly property bool canSeek: !!player && player.canSeek && player.positionSupported && player.lengthSupported && player.length > 0

    // Nothing left to show (the player quit): close
    onPlayerChanged: if (!player) SysState.mediaMenuOpen = false

    onVisibleChanged: {
        if (!visible) return;
        if (player) player.positionChanged();
        keyCatcher.forceActiveFocus();
        focusRetry.restart();
    }

    Timer {
        id: focusRetry
        interval: 25
        onTriggered: if (mediaWin.visible) keyCatcher.forceActiveFocus()
    }

    // MPRIS doesn't stream the position: re-read it every second while playing
    Timer {
        interval: 1000
        repeat: true
        running: mediaWin.visible && !!mediaWin.player && mediaWin.player.isPlaying && mediaWin.player.positionSupported
        onTriggered: mediaWin.player.positionChanged()
    }

    function seekBy(delta) {
        if (!canSeek) return;
        player.position = Math.max(0, Math.min(player.length, player.position + delta));
    }

    function cycleLoop() {
        if (!player || !player.loopSupported) return;
        let next = { [MprisLoopState.None]: MprisLoopState.Playlist, [MprisLoopState.Playlist]: MprisLoopState.Track };
        player.loopState = next[player.loopState] ?? MprisLoopState.None;
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            let p = mediaWin.player, k = event.key;
            if (k === Qt.Key_Escape) SysState.mediaMenuOpen = false;
            else if (!p) return;
            else if (k === Qt.Key_Space || k === Qt.Key_K) p.togglePlaying();
            else if (k === Qt.Key_Left || k === Qt.Key_H) mediaWin.seekBy(-5);
            else if (k === Qt.Key_Right || k === Qt.Key_L) mediaWin.seekBy(5);
            else if (k === Qt.Key_P && p.canGoPrevious) p.previous();
            else if (k === Qt.Key_N && p.canGoNext) p.next();
            else if (k === Qt.Key_S && p.shuffleSupported) p.shuffle = !p.shuffle;
            else if (k === Qt.Key_R) mediaWin.cycleLoop();
            else if (k === Qt.Key_Tab) Media.cycle();
            else return;
            event.accepted = true;
        }
    }

    // Click outside to close
    MouseArea {
        anchors.fill: parent
        onPressed: SysState.mediaMenuOpen = false
    }

    Rectangle {
        id: card
        width: 360
        height: col.implicitHeight + 24
        // Under the bar's media module (centered on it), or at the right edge when opened by IPC
        x: SysState.mediaMenuX >= 0 ? Math.max(12, Math.min(parent.width - width - 12, Math.round(SysState.mediaMenuX - width / 2)))
                                    : parent.width - width - 12
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
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 10

            // --- Header: "media" and the player's name -------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "󰎆  media"
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: Media.playerName(mediaWin.player) + (mediaWin.player && !mediaWin.player.isPlaying ? " · paused" : "")
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            // --- Artwork and track ---------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 96
                    color: Theme.bgInset
                    border.color: Theme.border
                    border.width: 1
                    clip: true

                    Image {
                        id: art
                        anchors.fill: parent
                        anchors.margins: 1
                        source: mediaWin.player ? (mediaWin.player.trackArtUrl || "") : ""
                        sourceSize: Qt.size(192, 192)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "󰝚"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 36
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 4

                    Text {
                        Layout.fillWidth: true
                        text: mediaWin.player ? (mediaWin.player.trackTitle || "unknown title") : ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        color: titleMouse.containsMouse ? Theme.accent : Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        MouseArea {
                            id: titleMouse
                            anchors.fill: parent
                            enabled: !!mediaWin.player && mediaWin.player.canRaise
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                mediaWin.player.raise();
                                SysState.mediaMenuOpen = false;
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: mediaWin.player ? (mediaWin.player.trackArtist || "") : ""
                        elide: Text.ElideRight
                        color: Theme.subtle
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: mediaWin.player ? (mediaWin.player.trackAlbum || "") : ""
                        elide: Text.ElideRight
                        color: Theme.placeholder
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }
            }

            // --- Progress (click or drag to seek) --------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                visible: !!mediaWin.player && mediaWin.player.lengthSupported && mediaWin.player.length > 0
                spacing: 8

                Text {
                    text: Media.time(seekArea.pressed ? seekArea.dragTime : (mediaWin.player ? mediaWin.player.position : 0))
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: 14

                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        color: Theme.sep
                        readonly property real ratio: {
                            let p = mediaWin.player;
                            if (!p || p.length <= 0) return 0;
                            let t = seekArea.pressed ? seekArea.dragTime : p.position;
                            return Math.max(0, Math.min(1, t / p.length));
                        }
                        Rectangle {
                            width: Math.round(track.ratio * parent.width)
                            height: parent.height
                            color: Theme.accent
                        }
                    }
                    Rectangle {
                        visible: mediaWin.canSeek
                        x: Math.round(track.ratio * (parent.width - width))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 4
                        height: seekArea.containsMouse || seekArea.pressed ? 14 : 10
                        color: Theme.fg
                    }

                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        enabled: mediaWin.canSeek
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        property real dragTime: 0
                        function timeAt(x) {
                            return Math.max(0, Math.min(1, x / width)) * mediaWin.player.length;
                        }
                        onPressed: event => dragTime = timeAt(event.x)
                        onPositionChanged: event => { if (pressed) dragTime = timeAt(event.x); }
                        onReleased: mediaWin.player.position = dragTime
                    }
                }

                Text {
                    text: mediaWin.player ? Media.time(mediaWin.player.length) : ""
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            // --- Controls ------------------------------------------------------------------------
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6

                CtrlButton {
                    visible: !!mediaWin.player && mediaWin.player.shuffleSupported
                    icon: mediaWin.player && mediaWin.player.shuffle ? "󰒝" : "󰒞"
                    on: !!mediaWin.player && mediaWin.player.shuffle
                    onActivated: mediaWin.player.shuffle = !mediaWin.player.shuffle
                }
                CtrlButton {
                    icon: "󰒮"
                    usable: !!mediaWin.player && mediaWin.player.canGoPrevious
                    onActivated: mediaWin.player.previous()
                }
                CtrlButton {
                    primary: true
                    icon: mediaWin.player && mediaWin.player.isPlaying ? "󰏤" : "󰐊"
                    usable: !!mediaWin.player && mediaWin.player.canTogglePlaying
                    onActivated: mediaWin.player.togglePlaying()
                }
                CtrlButton {
                    icon: "󰒭"
                    usable: !!mediaWin.player && mediaWin.player.canGoNext
                    onActivated: mediaWin.player.next()
                }
                CtrlButton {
                    visible: !!mediaWin.player && mediaWin.player.loopSupported
                    icon: {
                        let s = mediaWin.player ? mediaWin.player.loopState : MprisLoopState.None;
                        return s === MprisLoopState.Track ? "󰑘" : (s === MprisLoopState.Playlist ? "󰑖" : "󰑗");
                    }
                    on: !!mediaWin.player && mediaWin.player.loopState !== MprisLoopState.None
                    onActivated: mediaWin.cycleLoop()
                }
            }

            // --- Player volume (when the player has one) ----------------------------------------
            RowLayout {
                Layout.fillWidth: true
                visible: !!mediaWin.player && mediaWin.player.volumeSupported
                spacing: 8

                Text {
                    text: mediaWin.player && mediaWin.player.volume <= 0 ? "󰝟" : "󰕾"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 14
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 14
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        color: Theme.sep
                        Rectangle {
                            width: Math.round(Math.max(0, Math.min(1, mediaWin.player ? mediaWin.player.volume : 0)) * parent.width)
                            height: parent.height
                            color: Theme.accent
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setAt(x) { mediaWin.player.volume = Math.max(0, Math.min(1, x / width)); }
                        onPressed: event => setAt(event.x)
                        onPositionChanged: event => { if (pressed) setAt(event.x); }
                        onWheel: event => {
                            let v = mediaWin.player.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05);
                            mediaWin.player.volume = Math.max(0, Math.min(1, v));
                        }
                    }
                }
                Text {
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                    text: Math.round((mediaWin.player ? mediaWin.player.volume : 0) * 100) + "%"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            // --- Player choice (several players) -----------------------------------------------
            Flow {
                Layout.fillWidth: true
                visible: Media.players.length > 1
                spacing: 6
                Repeater {
                    model: Media.players
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool isOn: modelData === mediaWin.player
                        width: chipText.implicitWidth + 20
                        height: 24
                        color: isOn ? Theme.hoverBg : (chipMouse.containsMouse ? Theme.rowHover : "transparent")
                        border.color: isOn ? Theme.accent : Theme.border
                        border.width: 1
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: (chip.modelData.isPlaying ? "󰐊 " : "") + Media.playerName(chip.modelData)
                            color: chip.isOn ? Theme.accent : Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.choose(chip.modelData)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "space play · ←→ seek · p/n prev/next" + (Media.players.length > 1 ? " · tab player" : "") + " · esc"
                horizontalAlignment: Text.AlignHCenter
                color: Theme.placeholder
                font.family: Theme.fontMain
                font.pixelSize: 10
            }
        }
    }
}
