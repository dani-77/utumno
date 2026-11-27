import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland GlobalShortcut fallback, ported from quickshell-d77. Loaded by
// shell.qml only on Hyprland. The appid stays "quickshell" so the same
// `bind = SUPER, X, global, quickshell:<name>` lines work for both shells.
Item {
    property var appLauncher
    property var sessionMenu
    property var lockScreen
    property var dashboard

    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "open/close app launcher"
        onPressed: appLauncher.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "session"
        description: "open/close session menu (lock/suspend/reboot/...)"
        onPressed: sessionMenu.toggle()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "lock"
        description: "Lock the screen (native lockscreen)"
        onPressed: lockScreen.lock()
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "dashboard"
        description: "open/close the quick info dashboard (stats, weather, cmus, session)"
        onPressed: dashboard.toggle()
    }
}
