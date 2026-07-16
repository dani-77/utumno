import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "../config" as Cfg

// Hyprland workspaces via Quickshell.Hyprland (native hyprctl-backed IPC),
// ported from quickshell-d77. Fixed 1-9 grid, unlike the niri widget —
// Hyprland workspaces are a static set the user switches between, not
// created on demand.
//
// Switching uses `hyprctl dispatch hl.dsp.focus({workspace = N})` — the
// Lua-based custom dispatcher quickshell-d77 relies on throughout (see
// also SessionMenu.qml's hl.dsp.exit() for logout) — not the plain
// `hyprctl dispatch workspace N` / Quickshell.Hyprland's own dispatch(),
// since this setup's Hyprland config only wires up the Lua dispatchers.
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    Process {
        id: wsProc
        running: false
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: 9
            Rectangle {
                required property int index
                property int  wsId:     index + 1
                property var  ws:       Hyprland.workspaces.values.find(w => w.id === wsId)
                property bool isActive: Hyprland.focusedWorkspace !== null &&
                                        Hyprland.focusedWorkspace.id === wsId

                width: 26
                height: 26
                radius: Cfg.Colors.radius / 2
                color: isActive ? Cfg.Colors.blue
                    : ws ? Cfg.Colors.bgHighlight
                    : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.wsId
                    color: parent.isActive ? Cfg.Colors.bg
                         : parent.ws      ? Cfg.Colors.fgDark
                         : Cfg.Colors.comment
                    font.family: "monospace"
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wsProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({workspace = " + wsId + "})"]
                        wsProc.running = true
                    }
                }
            }
        }
    }
}
