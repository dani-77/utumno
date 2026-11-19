import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.WindowManager
import "../config" as Cfg

// Generic ext-workspace-v1 widget (niri, wasp, whiplash, spitfire, ...).
// Shows active and urgent from the protocol, and dims empty workspaces when
// the compositor publishes window counts (see windowCounts below).
Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    // The screen of the bar this widget sits in.
    property var screen

    // Compositors such as wasp advertise one workspace group per monitor, so
    // the full list would repeat every workspace once per monitor. Show only
    // this bar's monitor, keeping the full list if no group claims that screen.
    readonly property var available: {
        const onScreen = screen ? WindowManager.screenProjection(screen)?.windowsets ?? [] : [];
        return onScreen.length > 0 ? onScreen : WindowManager.windowsets;
    }

    readonly property var sorted: {
        const ws = root.available.filter(w => w.shouldDisplay);
        ws.sort((a, b) => {
            const ac = a.coordinates, bc = b.coordinates;
            for (let i = 0; i < Math.max(ac.length, bc.length); i++) {
                const av = ac[i] ?? 0, bv = bc[i] ?? 0;
                if (av !== bv) return av - bv;
            }
            return 0;
        });
        return ws;
    }

    // ext-workspace has no "occupied" state, so the d77 compositors (whiplash,
    // wasp, spitfire) write one line per workspace, "<ext-workspace id>
    // <window count>", to $XDG_RUNTIME_DIR/d77-workspaces-$WAYLAND_DISPLAY.
    // Without that file windowCounts stays null and nothing is dimmed.
    property var windowCounts: null

    FileView {
        id: countsFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/d77-workspaces-" + Quickshell.env("WAYLAND_DISPLAY")
        watchChanges: true
        printErrors: false

        onLoaded: {
            const counts = {};
            for (const line of text().split("\n")) {
                const parts = line.trim().split(/\s+/);
                if (parts.length === 2) counts[parts[0]] = parseInt(parts[1]);
            }
            root.windowCounts = counts;
        }
        onLoadFailed: error => root.windowCounts = null
        onFileChanged: countsFile.reload()
    }

    function isEmpty(ws) {
        return root.windowCounts !== null && root.windowCounts[ws.id] === 0;
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.sorted

            delegate: Rectangle {
                required property var modelData
                width: 26
                height: 26
                radius: Cfg.Colors.radius / 2
                color: modelData.active ? Cfg.Colors.blue
                    : modelData.urgent ? Cfg.Colors.red
                    : Cfg.Colors.bgHighlight
                // Empty workspaces fade back; the active one never does.
                opacity: !modelData.active && !modelData.urgent && root.isEmpty(modelData) ? 0.4 : 1

                Text {
                    anchors.centerIn: parent
                    text: modelData.name
                    color: modelData.active ? Cfg.Colors.bg : Cfg.Colors.fgDark
                    font.family: "monospace"
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.canActivate) modelData.activate();
                    }
                }
            }
        }
    }
}
