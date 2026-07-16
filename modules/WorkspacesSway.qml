import QtQuick
import Quickshell.I3
import "../config" as Cfg

// Sway workspaces via Quickshell.I3 (Sway implements the i3 IPC protocol),
// ported from quickshell-d77. Fixed 1-9 grid, unlike the niri widget —
// Sway workspaces are a static set the user switches between, not created
// on demand.
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: 9
            Rectangle {
                required property int index
                property int  wsId:     index + 1
                property var  ws:       I3.workspaces.values.find(w => w.number === wsId)
                property bool isActive: I3.focusedWorkspace !== null &&
                                        I3.focusedWorkspace.number === wsId

                width: 22
                height: 22
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
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: I3.dispatch("workspace " + wsId)
                }
            }
        }
    }
}
