import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config" as Cfg

// One instance per screen (Variants over Quickshell.screens). Sits on the
// "Bottom" layer-shell layer. When there is no wallpaper: only this (the
// Backdrop) is visible. When there is a wallpaper, the wallpaper tool draws
// beneath it, and the Backdrop hides itself, letting the real wallpaper show.
// Ported from quickshell-d77.

Variants {
    id: root

    property color colBg: Cfg.Colors.bg
    property color colFg: Cfg.Colors.fgDark
    property color colPurple: Cfg.Colors.magenta

    model: Quickshell.screens

    PanelWindow {
        id: panel
        required property var modelData
        screen: modelData

        WlrLayershell.layer:         WlrLayer.Bottom
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace:     "utumno-backdrop"

        anchors {
            top:    true
            bottom: true
            left:   true
            right:  true
        }

        color: "transparent"

        // Do not intercept clicks/focus — this is purely background decoration.
        mask: Region {
            item: Item {}
        }

        Backdrop {
            anchors.fill: parent
            colBg:     root.colBg
            colFg:     root.colFg
            colPurple: root.colPurple
        }
    }
}
