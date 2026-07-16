import QtQuick
import "../config" as Cfg

Item {
    id: root
    implicitWidth: label.implicitWidth + Cfg.Colors.gap * 2
    implicitHeight: parent ? parent.height : Cfg.Colors.barHeight

    property string format: "ddd dd MMM  hh:mm"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: label.text = Qt.formatDateTime(new Date(), root.format)
    }

    Text {
        id: label
        anchors.centerIn: parent
        color: Cfg.Colors.fg
        font.family: "monospace"
        font.pixelSize: Cfg.Colors.fsize
        text: Qt.formatDateTime(new Date(), root.format)
    }
}
