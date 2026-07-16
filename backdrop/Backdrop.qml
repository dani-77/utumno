import QtQuick
import "../Services" as Services
import "../config" as Cfg

// Decorative background shown only when no wallpaper is set by the user
// (WallpaperState.hasWallpaper === false). As soon as a wallpaper is chosen
// in the picker (Wallpaper.qml), this hides itself reactively, without
// restarting Quickshell. Ported from quickshell-d77 (inspired by
// DankBackdrop from DankMaterialShell).

Item {
    id: root
    clip: true

    property color colBg: Cfg.Colors.bg
    property color colFg: Cfg.Colors.fgDark
    property color colPurple: Cfg.Colors.magenta

    // Logo shown in the bottom-left corner.
    property string logoSource: "assets/d77-logo.svg"

    visible: !Services.WallpaperState.hasWallpaper

    Rectangle {
        anchors.fill: parent
        color: root.colBg
    }

    // Chevron 1 (darker, behind)
    Rectangle {
        x: root.width * 0.68
        y: -root.height * 0.3
        width: root.width * 0.8
        height: root.height * 1.6
        color: Qt.darker(root.colPurple, 2.2)
        rotation: 35
    }

    // Chevron 2 (colPurple, overlaid in front)
    Rectangle {
        x: root.width * 0.84
        y: -root.height * 0.2
        width: root.width * 0.4
        height: root.height * 1.3
        color: Qt.darker(root.colPurple, 1.4)
        rotation: 35
    }

    // Logo in the bottom-left corner, at ~25% opacity.
    Image {
        anchors.left:   parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 48
        width:  180
        height: width
        fillMode:     Image.PreserveAspectFit
        smooth:       true
        mipmap:       true
        asynchronous: true
        source:  Qt.resolvedUrl(root.logoSource)
        opacity: 0.25
        visible: status === Image.Ready
    }
}
