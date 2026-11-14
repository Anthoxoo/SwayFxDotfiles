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
    WifiMenu {}
    BluetoothMenu {}
    MonitorsMenu {}
    BrightnessMenu {}
    OmaPodsMenu {}
    AudioMenu {}
    BatteryMenu {}
    PowerMenu {}
    BrightnessOsd {}
    AudioOsd {}
    Notifications {}
    LockScreen {}
}
