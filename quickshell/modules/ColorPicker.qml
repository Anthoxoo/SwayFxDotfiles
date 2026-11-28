import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"

// Color picker overlay (started by core/Picker.qml): the frozen screens, with a loupe under the
// pointer. Click copies #rrggbb, Shift+click rgb(r, g, b); Escape or a right click cancels.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        visible: Picker.shown
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "qs-colorpicker"
        exclusionMode: ExclusionMode.Ignore
        color: "black"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        readonly property string url: Picker.shown ? "file://" + Picker.frozen(modelData.name) : ""
        property string loadedUrl: ""
        onUrlChanged: {
            canvas.ready = false;
            if (loadedUrl !== "") canvas.unloadImage(loadedUrl);
            loadedUrl = url;
            if (url !== "") canvas.loadImage(url);
        }
        onVisibleChanged: if (visible) keys.forceActiveFocus()

        // The frozen screen (shown at once), then the same pixels in a canvas to read them
        Image {
            id: frozenImg
            anchors.fill: parent
            source: win.url
            cache: false
            smooth: false
        }
        Canvas {
            id: canvas
            property bool ready: false
            // At the image's own size (output pixels), scaled to the window
            width: Math.max(1, frozenImg.implicitWidth)
            height: Math.max(1, frozenImg.implicitHeight)
            scale: frozenImg.implicitWidth > 0 ? win.width / frozenImg.implicitWidth : 1
            transformOrigin: Item.TopLeft
            onImageLoaded: requestPaint()
            onPaint: {
                if (win.url === "" || !isImageLoaded(win.url)) return;
                getContext("2d").drawImage(win.url, 0, 0);
                ready = true;
                win.sample();
            }
        }

        // Pixel under the pointer (image coordinates) and its color
        readonly property int pxX: Math.floor(mouse.mouseX / canvas.scale)
        readonly property int pxY: Math.floor(mouse.mouseY / canvas.scale)
        property var rgb: [0, 0, 0]
        readonly property string hex: Picker.hexOf(rgb[0], rgb[1], rgb[2])
        // Black or white, whichever reads on this color
        readonly property color contrast: 0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2] > 140 ? "black" : "white"

        function sample() {
            if (!canvas.ready) return;
            let d = canvas.getContext("2d").getImageData(pxX, pxY, 1, 1).data;
            rgb = [d[0], d[1], d[2]];
        }
        onPxXChanged: sample()
        onPxYChanged: sample()

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.CrossCursor
            onPressed: event => {
                if (event.button === Qt.RightButton || !canvas.ready) {
                    Picker.cancel();
                    return;
                }
                win.sample();
                Picker.picked(win.rgb[0], win.rgb[1], win.rgb[2], (event.modifiers & Qt.ShiftModifier) !== 0);
            }
        }

        Item {
            id: keys
            focus: true
            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Escape) return;
                Picker.cancel();
                event.accepted = true;
            }
        }

        // --- Loupe: 15×15 pixels around the pointer, 10× -----------------------------
        Item {
            id: loupe
            readonly property int cells: 15
            readonly property int zoom: 10
            readonly property int side: cells * zoom + 4
            visible: mouse.containsMouse && canvas.ready
            width: side
            height: side + label.height + 6
            // Beside the pointer, on the side with room
            x: mouse.mouseX + 24 + width > win.width ? mouse.mouseX - 24 - width : mouse.mouseX + 24
            y: mouse.mouseY + 24 + height > win.height ? mouse.mouseY - 24 - height : mouse.mouseY + 24

            Rectangle {
                width: loupe.side
                height: loupe.side
                color: Theme.bgSolid
                border.color: Theme.accent
                border.width: 2

                ShaderEffectSource {
                    x: 2
                    y: 2
                    width: loupe.cells * loupe.zoom
                    height: loupe.cells * loupe.zoom
                    sourceItem: canvas
                    sourceRect: Qt.rect(win.pxX - (loupe.cells - 1) / 2, win.pxY - (loupe.cells - 1) / 2, loupe.cells, loupe.cells)
                    smooth: false
                }
                // The picked pixel
                Rectangle {
                    x: 2 + (loupe.cells - 1) / 2 * loupe.zoom - 1
                    y: 2 + (loupe.cells - 1) / 2 * loupe.zoom - 1
                    width: loupe.zoom + 2
                    height: loupe.zoom + 2
                    color: "transparent"
                    border.color: win.contrast
                    border.width: 1
                }
            }

            Rectangle {
                id: label
                y: loupe.side + 6
                width: loupe.side
                height: 26
                color: Theme.bgSolid
                border.color: Theme.border
                border.width: 1
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 6
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        color: win.hex
                        border.color: Theme.border
                        border.width: 1
                    }
                    Text {
                        text: win.hex
                        color: Theme.fg
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                    }
                    Text {
                        text: win.rgb.join(" ")
                        color: Theme.muted
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // --- Hint ------------------------------------------------------------------------
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 40
            width: hint.implicitWidth + 24
            height: 30
            color: Theme.bgSolid
            border.color: Theme.accent
            border.width: 1
            Text {
                id: hint
                anchors.centerIn: parent
                text: "󰈊  click copy hex · shift+click rgb · esc cancel"
                color: Theme.fg
                font.family: Theme.fontMain
                font.pixelSize: 12
            }
        }
    }
}
