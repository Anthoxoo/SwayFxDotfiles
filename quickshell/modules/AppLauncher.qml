import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: launcherWin

    visible: SysState.launcherOpen
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

    property string query: ""
    property int selectedIndex: 0
    property real lastMouseX: -1
    property real lastMouseY: -1

    property bool isCalc: query.trim().startsWith("=")
    property bool isShell: query.trim().startsWith("!")

    property string calcResult: {
        if (!isCalc) return "";
        let expr = query.trim().substring(1).trim();
        if (!expr) return "";
        try {
            if (/^[0-9+\-*/().%\s^]+$/.test(expr)) {
                let val = Function("return (" + expr.replace(/\^/g, "**") + ")")();
                if (val !== undefined && !isNaN(val)) return String(val);
            }
        } catch (e) {}
        return "...";
    }

    property var filteredApps: {
        let q = query.trim().toLowerCase();
        let all = SysState.appList || [];
        if (!q || isCalc || isShell) return all.slice(0, 60);

        let scored = [];
        for (let i = 0; i < all.length; i++) {
            let a = all[i];
            let nameL = (a.name || "").toLowerCase();
            let kw = a.keywords || "";
            let rank = 0;

            if (nameL === q) rank = 1000;
            else if (nameL.startsWith(q)) rank = 500;
            else if (nameL.includes(q)) rank = 250;
            else if (kw.includes(q)) rank = 100;

            if (rank > 0) {
                scored.push({ app: a, rank: rank + (a.score || 0) * 15 });
            }
        }
        scored.sort((x, y) => y.rank - x.rank);
        return scored.map(s => s.app).slice(0, 60);
    }

    onVisibleChanged: {
        if (visible) {
            SysState.refreshAppsIfStale();
            query = "";
            selectedIndex = 0;
            searchInput.text = "";
            resultsList.contentY = 0;
            searchInput.forceActiveFocus();
            focusTimer.restart();
        }
    }

    Timer {
        id: focusTimer
        interval: 25
        repeat: false
        onTriggered: {
            if (launcherWin.visible) searchInput.forceActiveFocus();
        }
    }

    function executeSelection() {
        if (isCalc) {
            if (calcResult && calcResult !== "...") {
                SysState.runCmd("printf '%s' '" + calcResult + "' | wl-copy");
            }
            SysState.launcherOpen = false;
            return;
        }
        if (isShell) {
            let cmd = query.trim().substring(1).trim();
            if (cmd) SysState.runCmd(cmd);
            SysState.launcherOpen = false;
            return;
        }
        if (filteredApps.length > 0 && selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            let target = filteredApps[selectedIndex];
            SysState.launchApp(target.id, target.exec, target.terminal);
            SysState.launcherOpen = false;
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: SysState.launcherOpen = false
    }

    Rectangle {
        id: box
        width: 540
        height: 374
        anchors.centerIn: parent
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        // Gestion propre de la molette (pas de rebond, défilement net par lignes)
        MouseArea {
            anchors.fill: parent
            onPressed: searchInput.forceActiveFocus()
            onWheel: wheel => {
                let count = launcherWin.filteredApps.length;
                if (count === 0) return;
                if (wheel.angleDelta.y < 0) {
                    launcherWin.selectedIndex = Math.min(count - 1, launcherWin.selectedIndex + 1);
                } else if (wheel.angleDelta.y > 0) {
                    launcherWin.selectedIndex = Math.max(0, launcherWin.selectedIndex - 1);
                }
                resultsList.positionViewAtIndex(launcherWin.selectedIndex, ListView.Contain);
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: Theme.bgSolid

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: launcherWin.isCalc ? "=" : (launcherWin.isShell ? "!" : "❯")
                        color: Theme.accent
                        font.family: Theme.fontMain
                        font.pixelSize: 15
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search..."
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 14
                            visible: searchInput.text.length === 0
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg
                            selectionColor: Theme.accent
                            selectedTextColor: Theme.bgSolid
                            font.family: Theme.fontMain
                            font.pixelSize: 14
                            clip: true
                            focus: true

                            onTextChanged: {
                                launcherWin.query = text;
                                launcherWin.selectedIndex = 0;
                                resultsList.positionViewAtBeginning();
                            }

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    SysState.launcherOpen = false;
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                    if (launcherWin.filteredApps.length > 0) {
                                        launcherWin.selectedIndex = (launcherWin.selectedIndex + 1) % launcherWin.filteredApps.length;
                                        resultsList.positionViewAtIndex(launcherWin.selectedIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                    if (launcherWin.filteredApps.length > 0) {
                                        launcherWin.selectedIndex = (launcherWin.selectedIndex - 1 + launcherWin.filteredApps.length) % launcherWin.filteredApps.length;
                                        resultsList.positionViewAtIndex(launcherWin.selectedIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageDown) {
                                    if (launcherWin.filteredApps.length > 0) {
                                        launcherWin.selectedIndex = Math.min(launcherWin.filteredApps.length - 1, launcherWin.selectedIndex + 8);
                                        resultsList.positionViewAtIndex(launcherWin.selectedIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_PageUp) {
                                    if (launcherWin.filteredApps.length > 0) {
                                        launcherWin.selectedIndex = Math.max(0, launcherWin.selectedIndex - 8);
                                        resultsList.positionViewAtIndex(launcherWin.selectedIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    launcherWin.executeSelection();
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    Text {
                        text: {
                            if (launcherWin.isCalc) return launcherWin.calcResult;
                            if (launcherWin.isShell) return "shell";
                            return String(launcherWin.filteredApps.length);
                        }
                        color: launcherWin.isCalc ? Theme.accent : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 6
                clip: true
                spacing: 2
                interactive: false
                boundsBehavior: Flickable.StopAtBounds
                model: launcherWin.filteredApps

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    property bool isSelected: index === launcherWin.selectedIndex

                    width: resultsList.width
                    height: 38
                    radius: 0
                    color: isSelected ? Theme.hoverBg : "transparent"

                    Rectangle {
                        visible: parent.isSelected
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: Theme.accent
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Item {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                source: modelData.icon || ""
                                sourceSize.width: 18
                                sourceSize.height: 18
                                visible: status === Image.Ready
                                smooth: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: appIcon.status !== Image.Ready
                                text: "·"
                                color: isSelected ? Theme.accent : Theme.muted
                                font.family: Theme.fontMain
                                font.pixelSize: 16
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name || ""
                            color: isSelected ? Theme.accent : Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }

                        Text {
                            text: modelData.desc || ""
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.maximumWidth: 160
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => {
                            let pt = rowMouse.mapToItem(box, mouse.x, mouse.y);
                            if (Math.abs(pt.x - launcherWin.lastMouseX) > 2 || Math.abs(pt.y - launcherWin.lastMouseY) > 2) {
                                launcherWin.lastMouseX = pt.x;
                                launcherWin.lastMouseY = pt.y;
                                launcherWin.selectedIndex = index;
                            }
                        }
                        onPressed: {
                            launcherWin.selectedIndex = index;
                            launcherWin.executeSelection();
                        }
                        onWheel: wheel => {
                            let count = launcherWin.filteredApps.length;
                            if (count === 0) return;
                            if (wheel.angleDelta.y < 0) {
                                launcherWin.selectedIndex = Math.min(count - 1, launcherWin.selectedIndex + 1);
                            } else if (wheel.angleDelta.y > 0) {
                                launcherWin.selectedIndex = Math.max(0, launcherWin.selectedIndex - 1);
                            }
                            resultsList.positionViewAtIndex(launcherWin.selectedIndex, ListView.Contain);
                        }
                    }
                }
            }
        }
    }
}
