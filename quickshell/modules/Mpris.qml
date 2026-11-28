import QtQuick
import Quickshell.Services.Mpris
import "../core"

// Media module of the bar: what plays (core/Media.qml picks the player).
// Left click: media popup (modules/MediaMenu.qml) · middle click: play/pause · right click: next
// · wheel: previous / next.
Item {
    id: mprisRoot
    readonly property var player: Media.player
    property bool hovered: false

    visible: player !== null
    implicitHeight: 28
    implicitWidth: mprisLabel.implicitWidth + 20

    property bool isPlaying: player ? (player.playbackState === MprisPlaybackState.Playing) : false
    property string trackStr: {
        if (!player) return "";
        let art = player.trackArtist || "";
        let tit = player.trackTitle || "";
        let full = (art && tit) ? (art + " — " + tit) : (tit || art);
        return full.length > 38 ? full.substring(0, 35) + "..." : full;
    }
    property string iconStr: {
        if (!player) return "󰎆";
        if (!isPlaying) return "󰏤";
        let id = (player.identity || "").toLowerCase();
        if (id.includes("firefox")) return "󰗃";
        return "󰎆";
    }
    property string tooltipHtml: {
        if (!player) return "";
        let st = isPlaying ? "playing" : "paused";
        let tit = player.trackTitle || "-";
        let art = player.trackArtist || "-";
        return Theme.tipBlock([
            Theme.tipTitle(iconStr + "  " + st + " (" + Media.playerName(player) + ")"),
            Theme.tipRow("title", tit),
            Theme.tipRow("artist", art)
        ]);
    }

    Timer {
        id: mprisHoverTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (mprisMouse.containsMouse) mprisRoot.hovered = true;
        }
    }

    Text {
        id: mprisLabel
        anchors.centerIn: parent
        text: parent.iconStr + "  " + parent.trackStr
        font.family: Theme.fontMain
        font.pixelSize: 12
        font.italic: !parent.isPlaying
        color: mprisMouse.containsMouse || SysState.mediaMenuOpen ? Theme.accent : (parent.isPlaying ? Theme.fg : Theme.muted)
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: parent.isPlaying ? Theme.accent : Theme.sep
    }

    MouseArea {
        id: mprisMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: mprisHoverTimer.restart()
        onExited: {
            mprisHoverTimer.stop();
            mprisRoot.hovered = false;
        }
        onPressed: mouse => {
            mprisHoverTimer.stop();
            mprisRoot.hovered = false;
            let p = mprisRoot.player;
            if (!p) return;
            if (mouse.button === Qt.LeftButton) {
                let next = !SysState.mediaMenuOpen;
                SysState.closeAllPopups();
                // The popup centers itself under this module
                SysState.mediaMenuX = mprisRoot.mapToItem(null, mprisRoot.width / 2, 0).x;
                SysState.mediaMenuOpen = next;
            } else if (mouse.button === Qt.MiddleButton) {
                p.togglePlaying();
            } else if (p.canGoNext) {
                p.next();
            }
        }
        onWheel: wheel => {
            let p = mprisRoot.player;
            if (!p) return;
            if (wheel.angleDelta.y > 0 && p.canGoPrevious) p.previous();
            else if (wheel.angleDelta.y < 0 && p.canGoNext) p.next();
        }
    }
}
