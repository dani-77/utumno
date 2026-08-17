import QtQuick
import Quickshell
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

    property bool hovered: false

    // "Xh Ymin" (or just "Ymin" under an hour) from a duration in seconds.
    function formatDuration(seconds) {
        const total = Math.round(seconds / 60);
        const h = Math.floor(total / 60);
        const m = total % 60;
        return h > 0 ? (h + "h " + m + "min") : (m + "min");
    }

    // Charge/discharge line for the tooltip: time to empty or to full
    // when known, falling back to the raw UPower state otherwise
    // (e.g. "Fully charged", "Pending charge").
    function timeText() {
        if (!root.device) return "";
        const state = root.device.state;
        if (state === UPowerDeviceState.Charging) {
            const t = root.device.timeToFull;
            return t > 0 ? ("Charging — " + root.formatDuration(t) + " until full") : "Charging";
        }
        if (state === UPowerDeviceState.Discharging) {
            const t = root.device.timeToEmpty;
            return t > 0 ? (root.formatDuration(t) + " remaining") : "On battery";
        }
        // e.g. "FullyCharged" → "Fully Charged"
        return UPowerDeviceState.toString(state).replace(/([a-z])([A-Z])/g, "$1 $2");
    }

    // Mirrors Osd.qml's own _powerLabel() mapping — kept local since
    // that one is private to the OSD.
    function profileLabel() {
        const p = root.osd ? root.osd.powerProfile : "";
        if (p === "performance") return "Performance";
        if (p === "power-saver") return "Power saver";
        if (p === "balanced") return "Balanced";
        return "Unknown";
    }

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
        hoverEnabled: true
        onClicked: root.osd && root.osd.cyclePowerProfile()
        onEntered: root.hovered = true
        onExited: root.hovered = false
    }

    // Tooltip: time to empty/full + active power profile, shown below
    // the bar on hover — same pattern as Weather.qml's tooltip.
    LazyLoader {
        active: root.hovered

        PanelWindow {
            // Anchored to the top-right corner (Battery lives at the
            // right end of the bar), unlike Weather's centered tooltip
            // which suits its spot in the bar's center row.
            anchors.top: true
            anchors.right: true
            margins.top: Cfg.Colors.barHeight + Cfg.Colors.gap * 2
            margins.right: Cfg.Colors.gap
            exclusiveZone: 0
            color: "transparent"

            implicitWidth: tooltipLabel.implicitWidth + Cfg.Colors.gap * 3
            implicitHeight: tooltipLabel.implicitHeight + Cfg.Colors.gap * 2

            // Empty mask → does not block mouse events.
            mask: Region {}

            Rectangle {
                anchors.fill: parent
                radius: Cfg.Colors.radius
                color: Cfg.Colors.bg
                border.color: Cfg.Colors.muted
                border.width: 1

                Text {
                    id: tooltipLabel
                    anchors.centerIn: parent
                    color: Cfg.Colors.fg
                    font.family: "monospace"
                    font.pixelSize: Cfg.Colors.fsize
                    text: root.timeText() + "\nPower profile: " + root.profileLabel()
                }
            }
        }
    }
}
