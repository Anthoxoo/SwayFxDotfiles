import QtQuick
import "../core"

Rectangle {
    id: clockContainer
    height: 28
    width: clockLabel.implicitWidth + 12
    color: "transparent"

    property string timeStr: formatNow()

    function isoWeek(d) {
        let dt = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        let dayNum = dt.getUTCDay() || 7;
        dt.setUTCDate(dt.getUTCDate() + 4 - dayNum);
        let yearStart = new Date(Date.UTC(dt.getUTCFullYear(), 0, 1));
        return String(Math.ceil((((dt - yearStart) / 86400000) + 1) / 7)).padStart(2, "0");
    }

    function formatNow() {
        let now = new Date();
        let hh = String(now.getHours()).padStart(2, "0");
        let mm = String(now.getMinutes()).padStart(2, "0");
        if (!SysState.clockAlt) return hh + ":" + mm;
        let days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
        return days[now.getDay()] + " " + String(now.getDate()).padStart(2, "0") + " " + months[now.getMonth()] + "  w" + isoWeek(now) + "  " + hh + ":" + mm;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockContainer.timeStr = clockContainer.formatNow()
    }

    Text {
        id: clockLabel
        anchors.centerIn: parent
        text: clockContainer.timeStr
        color: (clockMouse.containsMouse || SysState.calendarMenuOpen) ? Theme.accent : Theme.fg
        font.family: Theme.fontMain
        font.pixelSize: 13
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: Theme.accent
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            if (mouse.button === Qt.LeftButton) {
                SysState.powerMenuOpen = false;
                SysState.brightnessMenuOpen = false;
                SysState.podsMenuOpen = false;
                SysState.launcherOpen = false;
                SysState.calendarMenuOpen = !SysState.calendarMenuOpen;
            } else if (mouse.button === Qt.RightButton) {
                SysState.clockAlt = !SysState.clockAlt;
                clockContainer.timeStr = clockContainer.formatNow();
            }
        }
    }
}
