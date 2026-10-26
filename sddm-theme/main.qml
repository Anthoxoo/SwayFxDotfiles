import QtQuick 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#141416"

    property int sessionIndex: sessionSelect.index

    TextConstants { id: textConstants }

    Image {
        anchors.fill: parent
        source: "background.png"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.fill: parent
        color: "#141416"
        opacity: 0.72
    }

    Text {
        id: clockLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -140
        color: "#e5e5e5"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 86
        font.bold: true
        text: Qt.formatTime(new Date(), "HH:mm")
    }

    Text {
        id: dateLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -55
        color: "#ff8800"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        text: Qt.formatDate(new Date(), "dddd dd MMMM yyyy")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            clockLabel.text = Qt.formatTime(new Date(), "HH:mm")
            dateLabel.text = Qt.formatDate(new Date(), "dddd dd MMMM yyyy")
        }
    }

    Text {
        id: userLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 25
        color: "#8a8a8d"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 13
        text: "󰌾  " + userModel.lastUser
    }

    Rectangle {
        id: pwBox
        width: 280
        height: 48
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 80
        color: "#e6141416"
        border.color: "#ff8800"
        border.width: 2
        radius: 0

        PasswordBox {
            id: passwordInput
            anchors.fill: parent
            anchors.margins: 2
            color: "#141416"
            borderColor: "transparent"
            focusColor: "transparent"
            hoverColor: "transparent"
            textColor: "#e5e5e5"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            focus: true

            Keys.onPressed: {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    sddm.login(userModel.lastUser, passwordInput.text, sessionSelect.index)
                    event.accepted = true
                }
            }
        }
    }

    Text {
        id: errorMessage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pwBox.bottom
        anchors.topMargin: 10
        color: "#e05252"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 12
        text: ""
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: pwBox.bottom
        anchors.topMargin: 42
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: "#8a8a8d"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            text: "Session :"
        }

        ComboBox {
            id: sessionSelect
            width: 195
            height: 30
            model: sessionModel
            index: sessionModel.lastIndex
            color: "#141416"
            borderColor: "#ff8800"
            focusColor: "#33ff8800"
            hoverColor: "#ff8800"
            menuColor: "#141416"
            textColor: "#e5e5e5"
            arrowColor: "#1e1e20"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 26
                color: "#1e1e20"
                border.color: "#ff8800"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "▾"
                    color: "#ff8800"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }
            }
        }
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            passwordInput.text = ""
            pwBox.border.color = "#e05252"
            errorMessage.text = "Mot de passe incorrect"
            passwordInput.focus = true
        }
    }

    Component.onCompleted: {
        passwordInput.forceActiveFocus()
    }
}