import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: monWin

    visible: SysState.monitorsMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property var st: SysState.monitorsState || ({ count: 1, activeCount: 1, hideWhenSingle: false, outputs: [] })
    property var outs: st.outputs || []
    property int selectedIdx: outs.length > 1 ? 1 : 0
    property var currentOut: (outs && outs.length > selectedIdx) ? outs[selectedIdx] : null

    property var localPos: ({})
    property bool isDragging: false

    property var bounds: {
        let minX = 0, minY = 0, maxX = 1920, maxY = 1080;
        let first = true;
        for (let i = 0; i < outs.length; i++) {
            let o = outs[i];
            if (!o.active) continue;
            let ox = (localPos[o.name] !== undefined) ? localPos[o.name].x : o.x;
            let oy = (localPos[o.name] !== undefined) ? localPos[o.name].y : o.y;
            if (first) {
                minX = ox;
                minY = oy;
                maxX = ox + o.width;
                maxY = oy + o.height;
                first = false;
            } else {
                if (ox < minX) minX = ox;
                if (oy < minY) minY = oy;
                if (ox + o.width > maxX) maxX = ox + o.width;
                if (oy + o.height > maxY) maxY = oy + o.height;
            }
        }
        let spanW = Math.max(1920, maxX - minX);
        let spanH = Math.max(1080, maxY - minY);
        return { minX: minX, minY: minY, spanW: spanW, spanH: spanH };
    }

    property real canvasScale: {
        let availW = 264;
        let availH = 132;
        return Math.min(availW / (bounds.spanW * 1.35), availH / (bounds.spanH * 1.35));
    }

    function syncFromState() {
        if (isDragging) return;
        let map = {};
        for (let i = 0; i < outs.length; i++) {
            let o = outs[i];
            map[o.name] = { x: o.x, y: o.y };
        }
        localPos = map;
        if (selectedIdx >= outs.length) {
            selectedIdx = Math.max(0, outs.length - 1);
        }
    }

    onOutsChanged: syncFromState()

    onVisibleChanged: {
        if (visible) {
            isDragging = false;
            selectedIdx = outs.length > 1 ? 1 : 0;
            syncFromState();
            keyCatcher.forceActiveFocus();
            focusRetry.restart();
        }
    }

    Timer {
        id: focusRetry
        interval: 25
        repeat: false
        onTriggered: {
            if (monWin.visible) keyCatcher.forceActiveFocus();
        }
    }

    function snapToMonitors(dragName, rawX, rawY, w, h) {
        let anchor = null;
        for (let i = 0; i < outs.length; i++) {
            if (outs[i].active && outs[i].name !== dragName) {
                anchor = outs[i];
                break;
            }
        }
        if (!anchor) return { x: 0, y: 0 };

        let ax = (localPos[anchor.name] !== undefined) ? localPos[anchor.name].x : anchor.x;
        let ay = (localPos[anchor.name] !== undefined) ? localPos[anchor.name].y : anchor.y;
        let aw = anchor.width;
        let ah = anchor.height;

        let acx = ax + aw / 2.0;
        let acy = ay + ah / 2.0;
        let bcx = rawX + w / 2.0;
        let bcy = rawY + h / 2.0;

        let dx = (bcx - acx) / ((aw + w) / 2.0);
        let dy = (bcy - acy) / ((ah + h) / 2.0);

        let sx = rawX;
        let sy = rawY;
        let magnet = 90;

        if (Math.abs(dx) >= Math.abs(dy)) {
            sx = (dx < 0) ? (ax - w) : (ax + aw);
            sy = Math.max(ay - h + 240, Math.min(ay + ah - 240, rawY));
            if (Math.abs(sy - ay) < magnet) sy = ay;
            else if (Math.abs(sy - (ay + (ah - h) / 2)) < magnet) sy = Math.round(ay + (ah - h) / 2);
            else if (Math.abs(sy - (ay + ah - h)) < magnet) sy = ay + ah - h;
        } else {
            sy = (dy < 0) ? (ay - h) : (ay + ah);
            sx = Math.max(ax - w + 240, Math.min(ax + aw - 240, rawX));
            if (Math.abs(sx - ax) < magnet) sx = ax;
            else if (Math.abs(sx - (ax + (aw - w) / 2)) < magnet) sx = Math.round(ax + (aw - w) / 2);
            else if (Math.abs(sx - (ax + aw - w)) < magnet) sx = ax + aw - w;
        }

        return { x: Math.round(sx), y: Math.round(sy) };
    }

    function quickPlace(dir) {
        if (outs.length < 2) return;
        let target = outs[selectedIdx] || outs[outs.length - 1];
        SysState.monitorsPlace(target.name, dir);
    }

    function cycleRefreshRate() {
        if (!currentOut || !currentOut.rates || currentOut.rates.length <= 1) return;
        let rList = currentOut.rates;
        let curIdx = 0;
        for (let i = 0; i < rList.length; i++) {
            if (rList[i].hz === currentOut.hz) {
                curIdx = i;
                break;
            }
        }
        let nextRate = rList[(curIdx + 1) % rList.length];
        SysState.monitorsRate(currentOut.name, nextRate.modeStr, nextRate.hz);
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SysState.monitorsMenuOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                monWin.quickPlace("left");
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                monWin.quickPlace("right");
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                monWin.quickPlace("above");
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                monWin.quickPlace("below");
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                monWin.cycleRefreshRate();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab) {
                if (monWin.outs.length > 0) {
                    monWin.selectedIdx = (monWin.selectedIdx + 1) % monWin.outs.length;
                }
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: SysState.monitorsMenuOpen = false
    }

    Rectangle {
        width: 326
        height: Math.max(120, mainCol.implicitHeight + 24)
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 32
        anchors.rightMargin: 70
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        MouseArea {
            anchors.fill: parent
            onPressed: keyCatcher.forceActiveFocus()
        }

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // En-tête : titre + bouton d'affichage permanent ou externe uniquement
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "󰍹  monitors"
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: hideLabel.implicitWidth + 14
                    height: 20
                    radius: 0
                    color: hideMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: hideMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        id: hideLabel
                        anchors.centerIn: parent
                        text: monWin.st.hideWhenSingle ? "bar: ext only" : "bar: always"
                        color: hideMouse.containsMouse ? Theme.accent : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: hideMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: Qt.callLater(() => SysState.monitorsCmd("toggle-autohide"))
                    }
                }
            }

            // Canevas visuel 2D (Drag & Snap façon Windows)
            Rectangle {
                id: canvasBox
                Layout.fillWidth: true
                Layout.preferredHeight: 154
                color: Theme.bgInset
                border.color: Theme.sep
                border.width: 1
                radius: 0
                clip: true

                Repeater {
                    model: monWin.outs
                    delegate: Rectangle {
                        id: monRect
                        required property var modelData
                        required property int index

                        visible: Boolean(modelData.active)
                        property bool isSel: index === monWin.selectedIdx

                        property real logX: (monWin.localPos[modelData.name] !== undefined) ? monWin.localPos[modelData.name].x : modelData.x
                        property real logY: (monWin.localPos[modelData.name] !== undefined) ? monWin.localPos[modelData.name].y : modelData.y

                        width: Math.max(44, Math.round(modelData.width * monWin.canvasScale))
                        height: Math.max(28, Math.round(modelData.height * monWin.canvasScale))

                        x: Math.round((canvasBox.width - monWin.bounds.spanW * monWin.canvasScale) / 2 + (logX - monWin.bounds.minX) * monWin.canvasScale)
                        y: Math.round((canvasBox.height - monWin.bounds.spanH * monWin.canvasScale) / 2 + (logY - monWin.bounds.minY) * monWin.canvasScale)

                        radius: 0
                        color: isSel ? Theme.hoverBg : Theme.bgCard
                        border.color: isSel ? Theme.accent : Theme.muted
                        border.width: 1
                        z: isSel ? 2 : 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 1

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: (monRect.index + 1) + " · " + monRect.modelData.name
                                color: monRect.isSel ? Theme.accent : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: monRect.modelData.width + "×" + monRect.modelData.height + " · " + (monRect.modelData.hz || 60) + "Hz"
                                color: Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 9
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: monWin.outs.length > 1 ? Qt.SizeAllCursor : Qt.PointingHandCursor
                            property real startMouseX: 0
                            property real startMouseY: 0
                            property real origLogX: 0
                            property real origLogY: 0
                            property real freezeScale: 0.04

                            onPressed: mouse => {
                                keyCatcher.forceActiveFocus();
                                monWin.selectedIdx = monRect.index;
                                if (monWin.outs.length <= 1) return;
                                monWin.isDragging = true;
                                freezeScale = monWin.canvasScale;
                                let pt = mapToItem(canvasBox, mouse.x, mouse.y);
                                startMouseX = pt.x;
                                startMouseY = pt.y;
                                origLogX = monRect.logX;
                                origLogY = monRect.logY;
                            }

                            onPositionChanged: mouse => {
                                if (!pressed || !monWin.isDragging || monWin.outs.length <= 1) return;
                                let pt = mapToItem(canvasBox, mouse.x, mouse.y);
                                let rawX = origLogX + (pt.x - startMouseX) / freezeScale;
                                let rawY = origLogY + (pt.y - startMouseY) / freezeScale;
                                let snapped = monWin.snapToMonitors(monRect.modelData.name, rawX, rawY, monRect.modelData.width, monRect.modelData.height);
                                let copy = Object.assign({}, monWin.localPos);
                                copy[monRect.modelData.name] = snapped;
                                monWin.localPos = copy;
                            }

                            onReleased: {
                                if (!monWin.isDragging) return;
                                monWin.isDragging = false;
                                SysState.monitorsSetPos(JSON.stringify(monWin.localPos));
                            }
                        }
                    }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 6
                    visible: monWin.outs.length > 1
                    text: "drag to arrange"
                    color: Theme.disabled
                    font.family: Theme.fontMain
                    font.pixelSize: 10
                }
            }

            // Boutons d'alignement rapide (affichés dès que 2+ écrans sont connectés)
            RowLayout {
                visible: monWin.outs.length > 1
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: [
                        { id: "left",  label: "← left" },
                        { id: "above", label: "↑ above" },
                        { id: "below", label: "↓ below" },
                        { id: "right", label: "→ right" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: 0
                        color: dirMouse.containsMouse ? Theme.hoverBg : "transparent"
                        border.color: dirMouse.containsMouse ? Theme.accent : Theme.sep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: dirMouse.containsMouse ? Theme.accent : Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: dirMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: Qt.callLater(() => monWin.quickPlace(modelData.id))
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            // Liste des écrans + fréquence actuelle + activation on/off
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: monWin.outs
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        property bool isSel: index === monWin.selectedIdx

                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: 0
                        color: isSel ? Theme.hoverBg : "transparent"
                        border.color: isSel ? Theme.accent : Theme.sep
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: (index + 1) + " · " + modelData.name
                                color: isSel ? Theme.accent : Theme.fg
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.desc
                                color: Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            Text {
                                text: (modelData.hz || 60) + "Hz"
                                color: (modelData.hz > 60) ? Theme.accent : Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                            }

                            Rectangle {
                                visible: monWin.outs.length > 1
                                width: 42
                                height: 20
                                radius: 0
                                color: modelData.active ? Theme.accent : "transparent"
                                border.color: modelData.active ? Theme.accent : Theme.sep
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.active ? "on" : "off"
                                    color: modelData.active ? Theme.bgSolid : Theme.muted
                                    font.family: Theme.fontMain
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: Qt.callLater(() => SysState.monitorsToggle(modelData.name))
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            cursorShape: Qt.PointingHandCursor
                            onPressed: monWin.selectedIdx = index
                        }
                    }
                }
            }

            // Sélecteur de taux de rafraîchissement (Refresh Rate en Hz — affiché si l'écran supporte > 60Hz ou plusieurs fréquences)
            RowLayout {
                visible: Boolean(monWin.currentOut && monWin.currentOut.hasHighHz)
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "refresh"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    Layout.preferredWidth: 48
                }

                Repeater {
                    model: (monWin.currentOut && monWin.currentOut.rates) ? monWin.currentOut.rates : []
                    delegate: Rectangle {
                        required property var modelData
                        property bool isCur: Boolean(monWin.currentOut && monWin.currentOut.hz === modelData.hz)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 0
                        color: isCur ? Theme.accent : (hzMouse.containsMouse ? Theme.hoverBg : "transparent")
                        border.color: isCur ? Theme.accent : Theme.sep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.hz + "Hz"
                            color: isCur ? Theme.bgSolid : (hzMouse.containsMouse ? Theme.accent : Theme.muted)
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: hzMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                if (monWin.currentOut) {
                                    let targetName = monWin.currentOut.name;
                                    let targetMode = modelData.modeStr;
                                    let targetHz = modelData.hz;
                                    Qt.callLater(() => SysState.monitorsRate(targetName, targetMode, targetHz));
                                }
                            }
                        }
                    }
                }
            }

            // Échelle (Scale) de l'écran sélectionné
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: "scale"
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    Layout.preferredWidth: 48
                }

                Repeater {
                    model: [1.0, 1.25, 1.5, 2.0]
                    delegate: Rectangle {
                        required property real modelData
                        property bool isCur: monWin.currentOut ? (Math.abs(monWin.currentOut.scale - modelData) < 0.05) : (modelData === 1.0)

                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        radius: 0
                        color: isCur ? Theme.accent : (scMouse.containsMouse ? Theme.hoverBg : "transparent")
                        border.color: isCur ? Theme.accent : Theme.sep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: Math.round(modelData * 100) + "%"
                            color: isCur ? Theme.bgSolid : (scMouse.containsMouse ? Theme.accent : Theme.muted)
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: scMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                if (monWin.currentOut) {
                                    let targetName = monWin.currentOut.name;
                                    Qt.callLater(() => SysState.monitorsScale(targetName, String(modelData)));
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
