import QtQuick
import Quickshell.Io
import "../config" as Cfg

Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    property real usage: 0
    property real prevIdle: -1
    property real prevTotal: -1

    FileView {
        id: statFile
        path: "/proc/stat"

        onLoaded: {
            const line = statFile.text().split("\n")[0];
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const nonIdle = f[0] + f[1] + f[2] + f[5] + f[6] + f[7];
            const total = idle + nonIdle;

            if (root.prevTotal >= 0) {
                const totalDelta = total - root.prevTotal;
                const idleDelta = idle - root.prevIdle;
                if (totalDelta > 0) root.usage = Math.round(100 * (1 - idleDelta / totalDelta));
            }
            root.prevIdle = idle;
            root.prevTotal = total;
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statFile.reload()
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Cfg.Colors.fg
        font.family: "monospace"
        font.pixelSize: Cfg.Colors.fsize
        text: "󰻠 " + root.usage + "%"
    }
}
