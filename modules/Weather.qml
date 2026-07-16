import QtQuick
import Quickshell.Io
import "../config" as Cfg

// Weather via wttr.in, adapted from quickshell-d77's Dashboard.qml
// (which uses the fuller ?format=3 including location). Here only the
// condition icon + temperature are shown (?format=%c+%t), since the bar
// has no room for the location name. Polled periodically instead of
// once-per-open, since this widget stays visible in the bar at all times.
Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    property string weatherText: "…"

    Process {
        id: weatherProc
        running: false
        command: ["sh", "-c", "curl -s --max-time 6 -A 'curl/7.0' 'https://wttr.in/?format=%c+%t' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root.weatherText = t !== "" ? t : "weather unavailable";
            }
        }
    }

    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: weatherProc.running = true
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Cfg.Colors.fg
        font.family: "monospace"
        font.pixelSize: 13
        text: root.weatherText
    }
}
