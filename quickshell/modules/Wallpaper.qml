import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"

// Fond d'écran sur le calque "background" de chaque écran, avec fondu enchaîné.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: wallWin
        required property var modelData
        screen: modelData

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "qs-wallpaper"
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        color: Theme.bgSolid

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Deux images superposées : la nouvelle se charge en arrière-plan,
        // puis on fait un fondu de l'une vers l'autre.
        property bool showA: true
        property string pending: ""

        function load(url) {
            if (url === "") return;
            let target = showA ? imgB : imgA;
            let visibleImg = showA ? imgA : imgB;
            if (visibleImg.source.toString() === url && visibleImg.status === Image.Ready) return;
            pending = url;
            target.source = url;
            if (target.status === Image.Ready) swapTo(target);
        }

        function swapTo(img) {
            if (img.source.toString() !== pending) return;
            showA = (img === imgA);
            pending = "";
        }

        Connections {
            target: Wallpapers
            function onCurrentUrlChanged() { wallWin.load(Wallpapers.currentUrl); }
        }
        Component.onCompleted: load(Wallpapers.currentUrl)

        Image {
            id: imgA
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            sourceSize: Qt.size(wallWin.width, wallWin.height)
            opacity: wallWin.showA ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready) wallWin.swapTo(imgA)
        }

        Image {
            id: imgB
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            sourceSize: Qt.size(wallWin.width, wallWin.height)
            opacity: wallWin.showA ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
            onStatusChanged: if (status === Image.Ready) wallWin.swapTo(imgB)
        }
    }
}
