import QtQuick
import Quickshell.Io
import "../config" as Cfg

Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    property real usage: 0

    FileView {
        id: memFile
        path: "/proc/meminfo"

        onLoaded: {
            const values = {};
            for (const line of memFile.text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m) values[m[1]] = Number(m[2]);
            }
            const total = values.MemTotal;
            const available = values.MemAvailable;
            if (total > 0 && available !== undefined) {
                root.usage = Math.round(100 * (1 - available / total));
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: memFile.reload()
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Cfg.Colors.fg
        font.family: "monospace"
        font.pixelSize: Cfg.Colors.fsize
        text: "󰍛 " + root.usage + "%"
    }
}
