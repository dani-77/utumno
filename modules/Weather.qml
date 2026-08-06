import QtQuick
import Quickshell
import Quickshell.Io
import "../config" as Cfg

// Weather via wttr.in, adapted from quickshell-d77's Dashboard.qml
// (which uses the fuller ?format=3 including location). Here only the
// condition icon + temperature are shown in the bar itself (?format=%c+%t),
// since the bar has no room for the location name — the fuller ?format=3
// line (location + condition + temp) is fetched alongside it and shown as
// a tooltip below the bar on hover. Polled periodically instead of
// once-per-open, since this widget stays visible in the bar at all times.
Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    property string weatherText: "…"
    property string weatherFull: "…"
    property bool hovered: false

    Process {
        id: weatherProc
        running: false
        // Record-separator (0x1E) between the two responses, so the split
        // can't be confused by spaces/colons in the weather text itself.
        command: ["sh", "-c",
            "curl -s --max-time 6 -A 'curl/7.0' 'https://wttr.in/?format=%c+%t' 2>/dev/null; " +
            "printf '\\036'; " +
            "curl -s --max-time 6 -A 'curl/7.0' 'https://wttr.in/?format=3' 2>/dev/null"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\u001e");
                const short = (parts[0] || "").trim();
                const full = (parts[1] || "").trim();
                root.weatherText = short !== "" ? short : "weather unavailable";
                root.weatherFull = full !== "" ? full : root.weatherText;
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
        font.pixelSize: Cfg.Colors.fsize
        text: root.weatherText
    }

    MouseArea {
        anchors.fill: label
        hoverEnabled: true
        onEntered: root.hovered = true
        onExited: root.hovered = false
    }

    // Tooltip: full "location: condition temp" line, shown below the bar
    // while hovering. LazyLoader keeps it out of existence otherwise.
    LazyLoader {
        active: root.hovered

        PanelWindow {
            // No left/right anchor → the compositor centers it
            // horizontally on the output, same trick Osd.qml relies on
            // for its own edge-anchored placement.
            anchors.top: true
            margins.top: Cfg.Colors.barHeight + Cfg.Colors.gap * 2
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
                    text: root.weatherFull
                }
            }
        }
    }
}
