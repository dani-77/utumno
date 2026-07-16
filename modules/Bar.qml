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
    implicitHeight: Cfg.Colors.barHeight
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "helium-d77-bar"
    exclusiveZone: implicitHeight

    Rectangle {
        anchors.fill: parent
        color: Cfg.Colors.bg

        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: Cfg.Colors.gap
            anchors.verticalCenter: parent.verticalCenter
            spacing: Cfg.Colors.gap

            Text {
                text: "helium-d77"
                color: Cfg.Colors.blue
                font.family: "monospace"
                font.bold: true
                font.pixelSize: 13
            }
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

            Network {}
            Battery {}
        }
    }
}
