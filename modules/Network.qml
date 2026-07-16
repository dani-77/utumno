import QtQuick
import Quickshell.Networking
import "../config" as Cfg

Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    readonly property var activeConnection: Network.connections.length > 0 ? Network.connections[0] : null

    Text {
        id: label
        anchors.centerIn: parent
        color: Cfg.Colors.fg
        font.family: "monospace"
        font.pixelSize: 13
        text: {
            if (!root.activeConnection) return "󰤭 offline";
            const ssid = root.activeConnection.ssid ?? "";
            const signal = root.activeConnection.signalStrength ?? null;
            return ssid !== "" ? (ssid + (signal !== null ? " " + signal + "%" : "")) : "wired";
        }
    }
}
