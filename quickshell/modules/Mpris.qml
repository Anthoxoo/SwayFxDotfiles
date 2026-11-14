import QtQuick
import Quickshell.Services.Mpris
import "../core"

Item {
    id: mprisRoot
    property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
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
        let src = (player.identity || "player").toLowerCase();
        return "<tt>"
            + "<span style='color:#ff8800;'>" + iconStr + "  " + st + " (" + src + ")</span><br>"
            + "<span style='color:#888888;'>title   </span><span style='color:#e5e5e5;'>" + tit + "</span><br>"
            + "<span style='color:#888888;'>artist  </span><span style='color:#e5e5e5;'>" + art + "</span>"
            + "</tt>";
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
        color: mprisMouse.containsMouse ? Theme.accent : (parent.isPlaying ? Theme.fg : Theme.muted)
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
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: mprisHoverTimer.restart()
        onExited: {
            mprisHoverTimer.stop();
            mprisRoot.hovered = false;
        }
        onPressed: mouse => {
            mprisHoverTimer.stop();
            mprisRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) SysState.runCmd("playerctl play-pause");
            else if (mouse.button === Qt.RightButton) SysState.runCmd("playerctl next");
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) SysState.runCmd("playerctl previous");
            else SysState.runCmd("playerctl next");
        }
    }
}
