import QtQuick
import Quickshell.Services.UPower
import "../config" as Cfg

Item {
    id: root
    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device && device.isLaptopBattery
    visible: hasBattery
    implicitWidth: hasBattery ? row.implicitWidth + Cfg.Colors.gap * 2 : 0
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            font.family: "monospace"
            font.pixelSize: 13
            color: root.device && root.device.state === UPowerDeviceState.Charging
                ? Cfg.Colors.green
                : (root.device && root.device.percentage < 0.2 ? Cfg.Colors.red : Cfg.Colors.fg)
            text: {
                if (!root.device) return "";
                const pct = Math.round(root.device.percentage * 100);
                const charging = root.device.state === UPowerDeviceState.Charging ? "⚡" : "";
                return charging + pct + "%";
            }
        }
    }
}
