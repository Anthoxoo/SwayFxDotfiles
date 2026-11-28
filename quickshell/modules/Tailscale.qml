import QtQuick
import "../core"

// Tailscale in the bar (core/Tailnet.qml): bright when connected, grey otherwise; hidden without
// the tailscale CLI. Click: menu (modules/TailscaleMenu.qml) · right click: copy this device's IP.
Item {
    id: tsRoot
    property bool hovered: false

    visible: Tailnet.installed
    implicitWidth: icon.implicitWidth + 8
    implicitHeight: 28

    readonly property string tooltipHtml: {
        let lines = [Theme.tipTitle("󰖂  tailscale: " + Tailnet.stateText)];
        if (Tailnet.running && Tailnet.self) {
            lines.push(Theme.tipRow("ip", Tailnet.self.ipv4 || "-", 10));
            lines.push(Theme.tipRow("name", Tailnet.self.name, 10));
            lines.push(Theme.tipRow("devices", Tailnet.onlineCount + "/" + Tailnet.peers.length + " online", 10));
            if (Tailnet.exitNode) lines.push(Theme.tipRow("exit node", Tailnet.exitNode, 10));
        }
        lines.push(Theme.tipMuted(Tailnet.running ? "click menu · right click copy ip" : "click menu"));
        return Theme.tipBlock(lines);
    }

    function keepAnchor() {
        Tailnet.anchorX = tsRoot.mapToItem(null, tsRoot.width / 2, 0).x;
    }

    Timer {
        id: hoverTimer
        interval: 400
        onTriggered: if (tsMouse.containsMouse && !SysState.tailscaleMenuOpen) tsRoot.hovered = true
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: "󰖂"
        font.family: Theme.fontMain
        font.pixelSize: 14
        // accent also for a moment after a copy
        color: tsMouse.containsMouse || SysState.tailscaleMenuOpen || Tailnet.copied !== "" ? Theme.accent
             : (Tailnet.running ? Theme.fg : Theme.disabled)
    }

    MouseArea {
        id: tsMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            tsRoot.keepAnchor();
            hoverTimer.restart();
        }
        onExited: {
            hoverTimer.stop();
            tsRoot.hovered = false;
        }
        onPressed: mouse => {
            hoverTimer.stop();
            tsRoot.hovered = false;
            if (mouse.button === Qt.LeftButton) {
                let next = !SysState.tailscaleMenuOpen;
                SysState.closeAllPopups();
                tsRoot.keepAnchor();
                SysState.tailscaleMenuOpen = next;
            } else if (Tailnet.running && Tailnet.self) {
                Tailnet.copy(Tailnet.self.ipv4);
            }
        }
    }
}
