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
    color: Theme.bg

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
        Wifi { id: wifiModule }
        Bluetooth { id: btModule }
        OmaPods { id: podsModule }
        Backlight { id: blModule }
        Audio { id: audioModule }
        Battery { id: batModule }
        Tray {}
        Power {}
    }

    property string activeRightTooltip: {
        if (mprisModule.hovered) return mprisModule.tooltipHtml;
        if (wifiModule.hovered) return SysState.wifiTooltipHtml;
        if (btModule.hovered) return SysState.btTooltipHtml;
        if (podsModule.hovered && !SysState.podsMenuOpen) return SysState.podsTooltipHtml;
        if (blModule.hovered && !SysState.brightnessMenuOpen) return SysState.brightTooltipHtml;
        if (audioModule.hovered) return SysState.audioTooltipHtml;
        if (batModule.hovered) return SysState.batTooltipHtml;
        return "";
    }

    property Item hoveredRightItem: {
        if (mprisModule.hovered) return mprisModule;
        if (wifiModule.hovered) return wifiModule;
        if (btModule.hovered) return btModule;
        if (podsModule.hovered) return podsModule;
        if (blModule.hovered) return blModule;
        if (audioModule.hovered) return audioModule;
        if (batModule.hovered) return batModule;
        return null;
    }

    // Popup Infobulle universelle pour les modules de droite
    PopupWindow {
        id: rightTooltipPopup
        anchor.window: barWindow
        anchor.rect.x: {
            if (!barWindow.hoveredRightItem) return barWindow.width - implicitWidth - 12;
            let pt = barWindow.hoveredRightItem.mapToItem(null, barWindow.hoveredRightItem.width / 2, 0);
            let targetX = Math.round(pt.x - (implicitWidth / 2));
            return Math.max(8, Math.min(barWindow.width - implicitWidth - 8, targetX));
        }
        anchor.rect.y: barWindow.height + 4
        visible: barWindow.activeRightTooltip !== ""
        implicitWidth: rightTipText.implicitWidth + 24
        implicitHeight: rightTipText.implicitHeight + 18
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Theme.bgSolid
            border.color: Theme.accent
            border.width: 1

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
