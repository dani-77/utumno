import QtQuick
import Quickshell.Networking
import Quickshell.Io
import "../config" as Cfg

Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    // Terminal used to open nmtui, wired from Bar.qml (mirrors the
    // launcher's auto-detected terminal, same as quickshell-d77's bar).
    property string terminal: "alacritty"

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

    // Opens nmtui in a floating terminal, same as quickshell-d77's bar.
    Process {
        id: nmtuiProc
        running: false
        command: ["sh", "-c",
            root.terminal === "wezterm"
                ? "setsid wezterm start --class nmtui-float -- nmtui >/dev/null 2>&1 &"
                : "setsid " + root.terminal + " --class nmtui-float -e nmtui >/dev/null 2>&1 &"
        ]
    }

    MouseArea {
        anchors.fill: label
        acceptedButtons: Qt.LeftButton
        onClicked: nmtuiProc.running = true
    }
}
