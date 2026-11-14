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
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
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
    property var selectedDate: new Date()

    // Formulaire "nouvel événement" (ouvre Google Agenda pré-rempli)
    property bool adding: false
    property string addError: ""
    readonly property var addSlot: adding ? Agenda.parseSlot(evWhen.text, selectedDate) : null

    function startAdding() {
        addError = "";
        evTitle.text = "";
        evWhen.text = "";
        adding = true;
        evTitle.forceActiveFocus();
    }

    function cancelAdding() {
        adding = false;
        keyCatcher.forceActiveFocus();
    }

    function submitEvent() {
        let err = Agenda.openCreate(evTitle.text, evWhen.text, selectedDate);
        if (err !== "") {
            addError = err;
            if (Agenda.splitTitle(evTitle.text).title === "") evTitle.forceActiveFocus();
            else evWhen.forceActiveFocus();
            return;
        }
        adding = false;
        SysState.calendarMenuOpen = false;   // laisser le navigateur prendre le focus
    }

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
            let hasToday = false;
            for (let d = 0; d < 7; d++) {
                let cur = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate() + w * 7 + d);
                days.push({
                    date: cur,
                    dayNum: String(cur.getDate()),
                    inMonth: cur.getMonth() === viewMonth,
                    isToday: isSameDay(cur, todayDate)
                });
                if (isSameDay(cur, todayDate)) hasToday = true;
            }
            rows.push({ week: "w" + wkNum, days: days, isCurrent: hasToday });
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
        selectedDate = todayDate;
        viewYear = todayDate.getFullYear();
        viewMonth = todayDate.getMonth();
        rebuildCalendar();
    }

    onVisibleChanged: {
        if (visible) {
            adding = false;
            resetToday();
            Agenda.refreshIfStale();
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
            } else if (event.key === Qt.Key_N || event.key === Qt.Key_Plus) {
                calWin.startAdding();
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

                // Semaine ISO du jour
                Text {
                    text: "· week " + calWin.isoWeekNumber(calWin.todayDate)
                    color: Theme.muted
                    font.family: Theme.fontMain
                    font.pixelSize: 12
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
                                color: modelData.isCurrent ? Theme.accent : Theme.disabled
                                font.bold: modelData.isCurrent
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
                                color: modelData.isToday ? Theme.accent : (dayMouse.containsMouse ? Theme.hoverBg : "transparent")
                                border.width: (!modelData.isToday && calWin.isSameDay(modelData.date, calWin.selectedDate)) ? 1 : 0
                                border.color: Theme.accent

                                // Jour avec événements (agenda iCal)
                                Rectangle {
                                    visible: Agenda.hasEvents(modelData.date)
                                    width: 4
                                    height: 4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    color: modelData.isToday ? Theme.bgSolid : (modelData.inMonth ? Theme.accent : Theme.disabled)
                                }

                                MouseArea {
                                    id: dayMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: {
                                        calWin.selectedDate = modelData.date;
                                        keyCatcher.forceActiveFocus();
                                    }
                                }

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

            // --- Agenda (iCal) ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
            }

            ColumnLayout {
                id: agendaCol
                Layout.fillWidth: true
                spacing: 3

                readonly property var dayEvents: Agenda.configured ? Agenda.eventsOn(calWin.selectedDate) : []
                readonly property int maxShown: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: {
                            let d = calWin.selectedDate;
                            if (calWin.isSameDay(d, calWin.todayDate)) return "today";
                            let days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
                            return days[d.getDay()] + " " + d.getDate() + " " + calWin.monthNames[d.getMonth()].substring(0, 3);
                        }
                        color: Theme.accent
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: Agenda.error !== ""
                        text: "\u{F0026} offline"
                        color: Theme.urgent
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }

                    // Nouvel événement (raccourci : n)
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 0
                        color: addMouse.containsMouse || calWin.adding ? Theme.hoverBg : "transparent"
                        border.color: addMouse.containsMouse || calWin.adding ? Theme.accent : Theme.sep
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: addMouse.containsMouse || calWin.adding ? Theme.accent : Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: calWin.adding ? calWin.cancelAdding() : calWin.startAdding()
                        }
                    }
                }

                // Formulaire nouvel événement
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: formCol.implicitHeight
                    visible: calWin.adding
                    color: Theme.bgInset
                    border.color: Theme.sep
                    border.width: 1

                    ColumnLayout {
                        id: formCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        // Titre (+ lieu après " @ ")
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "title  (@ place)"
                                color: Theme.placeholder
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                                visible: evTitle.text.length === 0
                            }
                            TextInput {
                                id: evTitle
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.fg
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.bgSolid
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                                clip: true
                                KeyNavigation.tab: evWhen
                                onTextChanged: calWin.addError = ""
                                Keys.onReturnPressed: evWhen.forceActiveFocus()
                                Keys.onEnterPressed: evWhen.forceActiveFocus()
                                Keys.onEscapePressed: calWin.cancelAdding()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.sep }

                        // Créneau
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "14:00 · 14-16 · 9h+30m · empty = all day"
                                color: Theme.placeholder
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                                visible: evWhen.text.length === 0
                            }
                            TextInput {
                                id: evWhen
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.fg
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.bgSolid
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                                clip: true
                                KeyNavigation.tab: evTitle
                                KeyNavigation.backtab: evTitle
                                onTextChanged: calWin.addError = ""
                                Keys.onReturnPressed: calWin.submitEvent()
                                Keys.onEnterPressed: calWin.submitEvent()
                                Keys.onEscapePressed: calWin.cancelAdding()
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.sep }

                        // Aperçu / erreur
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 22
                            leftPadding: 8
                            rightPadding: 8
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: {
                                if (calWin.addError !== "") return calWin.addError;
                                if (!calWin.addSlot) return "invalid time";
                                return "\u{F00ED}  " + Agenda.slotLabel(calWin.addSlot) + "  · enter ↗";
                            }
                            color: (calWin.addError !== "" || !calWin.addSlot) ? Theme.urgent : Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }
                    }
                }

                Repeater {
                    model: agendaCol.dayEvents.slice(0, agendaCol.maxShown)
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: Agenda.timeRange(modelData, calWin.selectedDate)
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            Layout.preferredWidth: 78
                        }
                        Text {
                            text: modelData.title + (modelData.location ? "  · " + modelData.location : "")
                            color: Theme.fg
                            elide: Text.ElideRight
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                            Layout.fillWidth: true
                        }
                    }
                }

                Text {
                    visible: agendaCol.dayEvents.length > agendaCol.maxShown
                    text: "+" + (agendaCol.dayEvents.length - agendaCol.maxShown) + " more"
                    color: Theme.disabled
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
                Text {
                    visible: Agenda.configured && agendaCol.dayEvents.length === 0 && !calWin.adding
                    text: "no events"
                    color: Theme.disabled
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            Text {
                visible: !Agenda.configured
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "agenda: add an iCal URL to ~/.config/quickshell/ical.conf"
                color: Theme.disabled
                font.family: Theme.fontMain
                font.pixelSize: 10
            }

            // --- Météo (wttr.in) ---
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.sep
                visible: Weather.ready
            }

            RowLayout {
                Layout.fillWidth: true
                visible: Weather.ready
                spacing: 10

                Text {
                    text: Weather.icon
                    color: Theme.accent
                    font.family: Theme.fontMain
                    font.pixelSize: 28
                }

                ColumnLayout {
                    spacing: 0
                    Layout.fillWidth: true

                    Text {
                        text: Weather.temp + "°  " + Weather.desc
                        color: Theme.fg
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        font.family: Theme.fontMain
                        font.pixelSize: 13
                    }
                    Text {
                        text: "feels " + Weather.feels + "° · " + Weather.humidity + "% · " + Weather.wind + " km/h"
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }

                Text {
                    text: Weather.area
                    color: Theme.disabled
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignTop
                }
            }

            Row {
                id: forecastRow
                Layout.fillWidth: true
                visible: Weather.ready && Weather.days.length > 0

                Repeater {
                    model: Weather.days
                    delegate: Column {
                        required property var modelData
                        width: forecastRow.width / Math.max(1, Weather.days.length)
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: Theme.muted
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            color: Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 16
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.min + "° / " + modelData.max + "°"
                            color: Theme.fg
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
