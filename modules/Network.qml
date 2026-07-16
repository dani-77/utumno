import QtQuick
import Quickshell.Networking
import "../config" as Cfg

Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    readonly property var activeDevice: {
        const devices = Networking.devices.values;
        for (const d of devices) {
            if (d.connected) return d;
        }
        return null;
    }

    readonly property var activeNetwork: {
        const d = root.activeDevice;
        if (!d) return null;
        if (d.type === DeviceType.Wired) return d.network;
        const networks = d.networks.values;
        for (const n of networks) {
            if (n.connected) return n;
        }
        return null;
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Cfg.Colors.fg
        font.family: "monospace"
        font.pixelSize: 13
        text: {
            const d = root.activeDevice;
            if (!d) return "󰤭 offline";
            if (d.type === DeviceType.Wired) return "󰈀 wired";
            const net = root.activeNetwork;
            if (!net) return "󰤨 wifi";
            const quality = Math.round(net.signalStrength * 100);
            return "󰤨 " + net.name + " " + quality + "%";
        }
    }
}
