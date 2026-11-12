import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: calWin

    visible: SysState.calendarMenuOpen
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: SysState.calendarMenuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property date todayDate: new Date()
    property int viewYear: todayDate.getFullYear()
    property int viewMonth: todayDate.getMonth()
    property var weeksModel: []

    readonly property var monthNames: [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december"
    ]
    readonly property var dayHeaders: ["mo", "tu", "we", "th", "fr", "sa", "su"]

    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear() &&
               a.getMonth() === b.getMonth() &&
               a.getDate() === b.getDate();
    }

    function isoWeekNumber(d) {
        let dt = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        let dayNum = dt.getUTCDay() || 7;
        dt.setUTCDate(dt.getUTCDate() + 4 - dayNum);
        let yearStart = new Date(Date.UTC(dt.getUTCFullYear(), 0, 1));
        return Math.ceil((((dt - yearStart) / 86400000) + 1) / 7);
    }

    function rebuildCalendar() {
        let first = new Date(viewYear, viewMonth, 1);
        let startOffset = (first.getDay() + 6) % 7; // Lundi = 0
        let startDate = new Date(viewYear, viewMonth, 1 - startOffset);

        let rows = [];
        for (let w = 0; w < 6; w++) {
            let thu = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + w * 7 + 3);
            let wkNum = String(isoWeekNumber(thu)).padStart(2, "0");
            let days = [];
            for (let d = 0; d < 7; d++) {
                let cur = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + w * 7 + d);
                days.push({
                    dayNum: String(cur.getDate()),
                    inMonth: cur.getMonth() === viewMonth,
                    isToday: isSameDay(cur, todayDate)
                });
            }
            rows.push({ week: "w" + wkNum, days: days });
        }
        weeksModel = rows;
    }

    function stepMonth(delta) {
        let d = new Date(viewYear, viewMonth + delta, 1);
        viewYear = d.getFullYear();
        viewMonth = d.getMonth();
        rebuildCalendar();
    }

    function resetToday() {
        todayDate = new Date();
        viewYear = todayDate.getFullYear();
        viewMonth = todayDate.getMonth();
        rebuildCalendar();
    }

    onVisibleChanged: {
        if (visible) {
            resetToday();
            keyCatcher.forceActiveFocus();
            focusRetry.restart();
        }
    }

    Timer {
        id: focusRetry
        interval: 25
        repeat: false
        onTriggered: {
            if (calWin.visible) keyCatcher.forceActiveFocus();
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                SysState.calendarMenuOpen = false;
                event.accepted = true;
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H || event.key === Qt.Key_BracketLeft) {
                calWin.stepMonth(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_BracketRight) {
                calWin.stepMonth(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_T || event.key === Qt.Key_Home) {
                calWin.resetToday();
                event.accepted = true;
            }
        }
    }

    // Clic à l'extérieur pour fermer
    MouseArea {
        anchors.fill: parent
        onPressed: SysState.calendarMenuOpen = false
    }

    // Boîte du calendrier centrée sous l'horloge
    Rectangle {
        width: 304
        height: mainCol.implicitHeight + 24
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 32
        color: Theme.bgSolid
        border.color: Theme.accent
        border.width: 1
        radius: 0

        MouseArea {
            anchors.fill: parent
            onPressed: keyCatcher.forceActiveFocus()
            onWheel: wheel => {
                if (wheel.angleDelta.y > 0) calWin.stepMonth(-1);
                else if (wheel.angleDelta.y < 0) calWin.stepMonth(1);
            }
        }

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // En-tête : Mois + Année à gauche, boutons ‹ • › à droite
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: calWin.monthNames[calWin.viewMonth] + " " + calWin.viewYear
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 13
                }

                Item { Layout.fillWidth: true }

                // Mois précédent
                Rectangle {
                    width: 22
                    height: 22
                    radius: 0
                    color: prevMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: prevMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "‹"
                        color: prevMouse.containsMouse ? Theme.accent : Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: calWin.stepMonth(-1)
                    }
                }

                // Retour à aujourd'hui
                Rectangle {
                    width: 22
                    height: 22
                    radius: 0
                    color: todayMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: todayMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "·"
                        color: todayMouse.containsMouse ? Theme.accent : Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: todayMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: calWin.resetToday()
                    }
                }

                // Mois suivant
                Rectangle {
                    width: 22
                    height: 22
                    radius: 0
                    color: nextMouse.containsMouse ? Theme.hoverBg : "transparent"
                    border.color: nextMouse.containsMouse ? Theme.accent : Theme.sep
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "›"
                        color: nextMouse.containsMouse ? Theme.accent : Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: calWin.stepMonth(1)
                    }
                }
            }

            // Séparateur
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            // Ligne des jours de la semaine (avec colonne ISO week vide à gauche)
            RowLayout {
                Layout.fillWidth: true
                spacing: 2

                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 22
                }

                Repeater {
                    model: calWin.dayHeaders
                    delegate: Item {
                        required property string modelData
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 22

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }
                    }
                }
            }

            // Grille des 6 semaines (numéro de semaine ISO + 7 jours)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: calWin.weeksModel
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2

                        // Numéro de semaine ISO (w01..w52)
                        Item {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 26

                            Text {
                                anchors.centerIn: parent
                                text: modelData.week
                                color: Theme.disabled
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                            }
                        }

                        // Les 7 jours de la semaine
                        Repeater {
                            model: modelData.days
                            delegate: Rectangle {
                                required property var modelData
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 26
                                radius: 0
                                color: modelData.isToday ? Theme.accent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.dayNum
                                    font.family: Theme.fontMain
                                    font.pixelSize: 12
                                    color: {
                                        if (modelData.isToday) return Theme.bgSolid;
                                        if (modelData.inMonth) return Theme.fg;
                                        return Theme.disabled;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
