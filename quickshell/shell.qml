import Quickshell
import QtQuick
import "./modules"

ShellRoot {
    Wallpaper {}

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
    ThemeMenu {}
    BrightnessOsd {}
    AudioOsd {}
    Notifications {}
    ReminderPopup {}
    LockScreen {}
    PolkitDialog {}
    Screenshot {}
    Autotiling {}
}
