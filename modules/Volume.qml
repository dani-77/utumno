import QtQuick
import Quickshell.Io
import "../config" as Cfg

Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    property int volume: 0
    property bool muted: false

    Process {
        id: proc
        command: ["amixer", "get", "Master"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pct = text.match(/\[(\d+)%\]/);
                const state = text.match(/\[(on|off)\]/);
                if (pct) root.volume = Number(pct[1]);
                if (state) root.muted = state[1] === "off";
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.running = true
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Cfg.Colors.fg
        font.family: "monospace"
        font.pixelSize: Cfg.Colors.fsize
        text: (root.muted ? "󰝟 " : "󰕾 ") + root.volume + "%"
    }
}
