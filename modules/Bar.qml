import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../config" as Cfg

PanelWindow {
    id: bar
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
    WlrLayershell.namespace: "helium-d77-bar"
    exclusiveZone: implicitHeight + Cfg.Colors.gap

    Rectangle {
        anchors.fill: parent
        radius: Cfg.Colors.radius
        color: Cfg.Colors.bg

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Cfg.Colors.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Cfg.Colors.gap

            Workspaces {}
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: Cfg.Colors.gap
            Clock {}
        }

        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: Cfg.Colors.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Cfg.Colors.gap

            Cpu {}
            Ram {}
            Volume {}
            Network {}
            Battery {}
        }
    }
}
