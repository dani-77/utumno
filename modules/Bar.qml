import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../config" as Cfg

PanelWindow {
    id: bar
    property var appLauncher
    property var sessionMenu
    property var osd
    property var ollamaChat
    property string compositor: "generic"

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: Cfg.Colors.gap
        left: Cfg.Colors.gap
        right: Cfg.Colors.gap
    }
    implicitHeight: Cfg.Colors.barHeight
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "utumno-bar"
    exclusiveZone: implicitHeight + Cfg.Colors.gap

    Rectangle {
        anchors.fill: parent
        radius: Cfg.Colors.radius
        color: Cfg.Colors.bg

        RowLayout {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: Cfg.Colors.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Cfg.Colors.gap

            Rectangle {
                width: 30
                height: 30
                radius: 7
                color: launchMa.containsMouse ? Qt.lighter(Cfg.Colors.magenta, 1.3) : Cfg.Colors.magenta

                Text {
                    anchors.centerIn: parent
                    text: "󰍜"
                    font.family: Cfg.Colors.font
                    font.pixelSize: 13
                    color: Cfg.Colors.bg
                }
                MouseArea {
                    id: launchMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.appLauncher && bar.appLauncher.toggle()
                }
            }

            Rectangle { width: 1; height: 22; color: Cfg.Colors.muted }

            Rectangle {
                width: 30
                height: 30
                radius: 7
                color: aiMa.containsMouse ? Qt.lighter(Cfg.Colors.green, 1.3) : Cfg.Colors.green

                Text {
                    anchors.centerIn: parent
                    text: "AI"
                    font.family: Cfg.Colors.font
                    font.pixelSize: 10
                    font.bold: true
                    color: Cfg.Colors.bg
                }
                MouseArea {
                    id: aiMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.ollamaChat && bar.ollamaChat.toggle()
                }
            }

            Rectangle { width: 1; height: 22; color: Cfg.Colors.muted }

            // Hyprland/Sway use their own dedicated per-compositor widgets
            // (fixed 1-9 grid, native IPC); niri and anything else
            // (mangowc included) fall back to the generic ext-workspace-v1
            // widget, which only shows workspaces that actually exist.
            Loader {
                sourceComponent: {
                    if (bar.compositor === "hyprland") return workspacesHyprlandComp;
                    if (bar.compositor === "sway") return workspacesSwayComp;
                    return workspacesGenericComp;
                }
            }
            Component { id: workspacesHyprlandComp; WorkspacesHyprland {} }
            Component { id: workspacesSwayComp; WorkspacesSway {} }
            Component { id: workspacesGenericComp; Workspaces {} }
        }

        RowLayout {
            id: centerRow
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(
                leftRow.x + leftRow.width + Cfg.Colors.gap * 3,
                Math.min(
                    rightRow.x - width - Cfg.Colors.gap * 3,
                    (parent.width - width) / 2
                )
            )
            spacing: Cfg.Colors.gap
            Weather {}
            Clock {}
        }

        RowLayout {
            id: rightRow
            anchors.right: parent.right
            anchors.rightMargin: Cfg.Colors.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Cfg.Colors.gap

            Cpu {}
            Ram {}
            Volume {}
            Network {
                terminal: bar.appLauncher ? bar.appLauncher.terminal : "alacritty"
            }
            Battery {
                osd: bar.osd
            }

            Rectangle { width: 1; height: 22; color: Cfg.Colors.muted }

            Rectangle {
                width: 30
                height: 30
                radius: 7
                color: sessBtnMa.containsMouse || (bar.sessionMenu && bar.sessionMenu.sessionOpen)
                    ? Cfg.Colors.red
                    : Qt.rgba(0.97, 0.46, 0.56, 0.3)

                Text {
                    anchors.centerIn: parent
                    text: "⏻"
                    font.pixelSize: 16
                    color: Cfg.Colors.red
                }
                MouseArea {
                    id: sessBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.sessionMenu && bar.sessionMenu.toggle()
                }
            }
        }
    }
}
