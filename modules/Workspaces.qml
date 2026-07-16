import QtQuick
import Quickshell.WindowManager
import "../config" as Cfg

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    readonly property var sorted: {
        const ws = WindowManager.windowsets.filter(w => w.shouldDisplay);
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
