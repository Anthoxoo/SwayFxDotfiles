import Quickshell
import QtQuick
import "./modules"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    AppLauncher {}
    CalendarMenu {}
    BrightnessMenu {}
    OmaPodsMenu {}
    PowerMenu {}
    BrightnessOsd {}
    Notifications {}
}
