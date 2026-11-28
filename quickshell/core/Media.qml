pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Media players (MPRIS) for the bar module (modules/Mpris.qml) and the media popup
// (modules/MediaMenu.qml): which player is shown, and helpers.
Singleton {
    id: root

    // The KDE browser extension (plasma-browser-integration) mirrors what the browser plays, with
    // the video's own title and its artwork: when it is there, the browser's own MPRIS player
    // would be the same media twice, so it is left out.
    readonly property var players: {
        let all = Mpris.players.values;
        let mirrored = all.some(p => p.dbusName.indexOf("plasma-browser-integration") >= 0);
        if (!mirrored) return all;
        return all.filter(p => !/\.(firefox|chromium|chrome|zen|brave|vivaldi)/i.test(p.dbusName));
    }

    // Picked in the popup; otherwise the first one playing, else the first one
    property string chosen: ""
    readonly property var player: {
        if (players.length === 0) return null;
        return players.find(p => p.dbusName === chosen) || players.find(p => p.isPlaying) || players[0];
    }

    function choose(p) {
        if (p) chosen = p.dbusName;
    }

    function cycle() {
        if (players.length < 2) return;
        choose(players[(players.indexOf(player) + 1) % players.length]);
    }

    // "Mozilla Firefox" -> "firefox", "Spotify" -> "spotify"
    function playerName(p) {
        if (!p) return "";
        let id = (p.identity || p.dbusName.replace(/^org\.mpris\.MediaPlayer2\./, "")).toLowerCase();
        return id.replace(/^mozilla\s+/, "");
    }

    // 83 -> "1:23", 3725 -> "1:02:05"
    function time(seconds) {
        let s = Math.max(0, Math.floor(seconds || 0));
        let h = Math.floor(s / 3600), m = Math.floor(s / 60) % 60, sec = s % 60;
        let mm = h > 0 && m < 10 ? "0" + m : "" + m;
        return (h > 0 ? h + ":" : "") + mm + ":" + (sec < 10 ? "0" : "") + sec;
    }
}
