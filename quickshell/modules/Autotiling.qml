import Quickshell
import Quickshell.Io
import Quickshell.I3
import QtQuick

// Autotiling (replaces the autotiling Python daemon): sway's split direction follows the focused
// window's shape, so the next window opens beside it when it is wider than tall, under it
// otherwise. Floating and fullscreen windows, and windows in tabbed or stacked containers, are
// left alone. Same rule as autotiling's defaults (window and binding mode events).
Scope {
    id: root

    property bool pending: false

    I3IpcListener {
        subscriptions: ["window", "mode"]
        onIpcEvent: event => {
            // Title, mark and urgency changes don't move anything
            let change = "";
            try {
                change = (typeof event.data === "string" ? JSON.parse(event.data) : event.data).change || "";
            } catch (e) {}
            if (change === "title" || change === "mark" || change === "urgent") return;
            root.check();
        }
    }

    function check() {
        if (tree.running) pending = true;
        else tree.running = true;
    }

    Process {
        id: tree
        command: ["swaymsg", "-r", "-t", "get_tree"]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
        onExited: {
            if (!root.pending) return;
            root.pending = false;
            running = true;
        }
    }

    function apply(json) {
        let found = null;
        let walk = (node, parent) => {
            if (found) return;
            if (node.focused) {
                found = { con: node, parent: parent };
                return;
            }
            for (let child of (node.nodes || [])) walk(child, node);
            for (let child of (node.floating_nodes || [])) walk(child, node);
        };
        try {
            walk(JSON.parse(json), null);
        } catch (e) {
            return;
        }
        if (!found || !found.parent) return;
        let con = found.con, parent = found.parent;
        // type: "workspace" (empty one focused) or "floating_con" are skipped
        if (con.type !== "con" || con.fullscreen_mode === 1) return;
        if (parent.layout === "tabbed" || parent.layout === "stacked") return;
        let layout = con.rect.height > con.rect.width ? "splitv" : "splith";
        // By id: focus may have moved on since the tree was read
        if (layout !== parent.layout) I3.dispatch("[con_id=" + con.id + "] " + layout);
    }
}
