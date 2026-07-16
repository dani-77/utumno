import QtQuick
import Quickshell.Services.UPower
import "../config" as Cfg

Item {
    id: root
    // Osd instance, wired from Bar.qml — click cycles the power profile
    // and shows the result in the OSD, same as quickshell-d77's bar.
    property var osd
    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device && device.isLaptopBattery
    visible: hasBattery
    implicitWidth: hasBattery ? row.implicitWidth + Cfg.Colors.gap * 2 : 0
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    function icon(pct, charging) {
        // Nerd Font (Material Design) battery glyphs, by codepoint to avoid encoding issues
        if (charging) return String.fromCodePoint(0xf0084); // battery-charging
        if (pct >= 95) return String.fromCodePoint(0xf0079); // battery (full)
        if (pct >= 85) return String.fromCodePoint(0xf0082); // battery-90
        if (pct >= 75) return String.fromCodePoint(0xf0081); // battery-80
        if (pct >= 65) return String.fromCodePoint(0xf0080); // battery-70
        if (pct >= 55) return String.fromCodePoint(0xf007f); // battery-60
        if (pct >= 45) return String.fromCodePoint(0xf007e); // battery-50
        if (pct >= 35) return String.fromCodePoint(0xf007d); // battery-40
        if (pct >= 25) return String.fromCodePoint(0xf007c); // battery-30
        if (pct >= 15) return String.fromCodePoint(0xf007b); // battery-20
        if (pct >= 5) return String.fromCodePoint(0xf007a); // battery-10
        return String.fromCodePoint(0xf008e); // battery-alert (critical)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Text {
            font.family: "monospace"
            font.pixelSize: Cfg.Colors.fsize
            color: root.device && root.device.state === UPowerDeviceState.Charging
                ? Cfg.Colors.green
                : (root.device && root.device.percentage < 0.2 ? Cfg.Colors.red : Cfg.Colors.fg)
            text: {
                if (!root.device) return "";
                const pct = Math.round(root.device.percentage * 100);
                const charging = root.device.state === UPowerDeviceState.Charging;
                return root.icon(pct, charging) + " " + pct + "%";
            }
        }
    }

    // Sibling of Row (not a child of it), so anchors.fill can overlay the
    // whole widget instead of getting its own slot in Row's horizontal flow.
    MouseArea {
        anchors.fill: row
        acceptedButtons: Qt.LeftButton
        onClicked: root.osd && root.osd.cyclePowerProfile()
    }
}
