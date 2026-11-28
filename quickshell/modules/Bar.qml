import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: barWindow

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 28
    color: Theme.barBg
    // Namespace layer-shell : ciblé par `layer_effects "qs-bar"` (flou swayfx) dans sway/config.d/theme
    WlrLayershell.namespace: "qs-bar"

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Launcher {}
        Workspaces {}
        WindowTitle {}
    }

    Clock {
        id: clockModule
        anchors.centerIn: parent
    }

    RowLayout {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Mpris { id: mprisModule }
        ReminderBadge { id: remModule }
        Wifi { id: wifiModule }
        Bluetooth { id: btModule }
        OmaPods { id: podsModule }
        Monitors { id: monModule }
        Backlight { id: blModule }
        Audio { id: audioModule }
        Battery { id: batModule }
        Tray {}
        Power {}
    }

    property string activeRightTooltip: {
        if (mprisModule.hovered && !SysState.mediaMenuOpen) return mprisModule.tooltipHtml;
        if (remModule.hovered && !SysState.reminderOpen) return Reminders.tooltipHtml;
        if (wifiModule.hovered && !SysState.wifiMenuOpen) return SysState.wifiTooltipHtml;
        if (btModule.hovered && !SysState.btMenuOpen) return SysState.btTooltipHtml;
        if (podsModule.hovered && !SysState.podsMenuOpen) return SysState.podsTooltipHtml;
        if (monModule.hovered && !SysState.monitorsMenuOpen) return SysState.monitorsTooltipHtml;
        if (blModule.hovered && !SysState.brightnessMenuOpen) return SysState.brightTooltipHtml;
        if (audioModule.hovered && !SysState.audioMenuOpen) return SysState.audioTooltipHtml;
        if (batModule.hovered && !SysState.batteryMenuOpen) return SysState.batTooltipHtml;
        return "";
    }

    property Item hoveredRightItem: {
        if (mprisModule.hovered) return mprisModule;
        if (remModule.hovered) return remModule;
        if (wifiModule.hovered) return wifiModule;
        if (btModule.hovered) return btModule;
        if (podsModule.hovered) return podsModule;
        if (monModule.hovered) return monModule;
        if (blModule.hovered) return blModule;
        if (audioModule.hovered) return audioModule;
        if (batModule.hovered) return batModule;
        return null;
    }

    property int tooltipRightMargin: {
        if (!hoveredRightItem) return 12;
        let itemCenterFromRight = (rightRow.width - (hoveredRightItem.x + hoveredRightItem.width / 2)) + 12;
        let tipW = Math.max(80, rightTipText.implicitWidth + 24);
        return Math.max(8, Math.round(itemCenterFromRight - tipW / 2));
    }

    // Infobulle stable en PanelWindow (aucune erreur xdg_popup sous Sway/wlroots)
    PanelWindow {
        screen: barWindow.screen
        visible: barWindow.activeRightTooltip !== ""
        focusable: false
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"

        anchors {
            top: true
            right: true
        }
        margins {
            top: 32
            right: barWindow.tooltipRightMargin
        }

        implicitWidth: Math.max(40, rightTipText.implicitWidth + 24)
        implicitHeight: Math.max(24, rightTipText.implicitHeight + 18)

        Rectangle {
            anchors.fill: parent
            color: Theme.bgSolid
            border.color: Theme.accent
            border.width: 1
            radius: 0

            Text {
                id: rightTipText
                anchors.centerIn: parent
                textFormat: Text.RichText
                text: barWindow.activeRightTooltip
                font.family: Theme.fontMain
                font.pixelSize: 12
                color: Theme.fg
            }
        }
    }
}
