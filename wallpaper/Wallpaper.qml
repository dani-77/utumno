// ══════════════════════════════════════════════════════
// Wallpaper.qml
// Grid-style wallpaper picker (DankMaterialShell-like).
// Scans a local directory for images and applies the
// selection through set-wallpaper.sh (compositor-agnostic).
// Ported from quickshell-d77.
// ══════════════════════════════════════════════════════
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../config" as Cfg

PanelWindow {
    id: wallpaper

    // ══════════════════════════════════════════════════════
    // THEME (Tokyo Night, from config/Colors.qml)
    // ══════════════════════════════════════════════════════
    property color colBg:     Cfg.Colors.bg
    property color colFg:     Cfg.Colors.fgDark
    property color colMuted:  Cfg.Colors.muted
    property color colCyan:   Cfg.Colors.cyanAccent
    property color colBlue:   Cfg.Colors.blue
    property color colPurple: Cfg.Colors.magenta
    property string font:     Cfg.Colors.font
    property int    fsize:    Cfg.Colors.fsize

    // ══════════════════════════════════════════════════════
    // CONFIG
    // ══════════════════════════════════════════════════════
    // Directory to scan for wallpapers. Override in shell.qml if needed.
    property string wallpaperDir: Quickshell.env("HOME") + "/Wallpaper"
    // Monitor to target. Empty = fallback (all monitors without one set).
    property string monitor: ""

    property var extensions: ["png", "jpg", "jpeg", "webp", "bmp"]

    // Where the last chosen wallpaper is persisted across logout/reboot.
    // Must match STATE_FILE in set-wallpaper.sh — both read/write the same
    // path.
    property string stateFile: Quickshell.env("HOME") + "/.cache/quickshell/wallpaper/current"

    // ══════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════
    property var images: []
    property string currentWallpaper: ""
    property bool   loading: false

    // ── Public API ───────────────────────────────────────
    function open() {
        visible = true
        reload()
    }
    function hide() {
        visible = false
    }
    function close() {
        hide()
    }
    function toggle() {
        if (visible) hide()
        else         open()
    }

    function reload() {
        loading = true
        images = []
        scanProc.running = true
        readStateProc.running = true
    }

    function apply(path) {
        currentWallpaper = path
        lastError = ""
        wallpaperProc.command = [Quickshell.shellDir + "/wallpaper/set-wallpaper.sh", "apply", path, wallpaper.monitor]
        wallpaperProc.running = true
    }

    // Removes the active wallpaper and clears stateFile, so
    // Services.WallpaperState.hasWallpaper flips to false and the
    // backdrop (WallpaperBackground) becomes visible again.
    function clear() {
        currentWallpaper = ""
        lastError = ""
        clearProc.running = true
    }

    property string lastError: ""

    // Picks a random wallpaper from the already-scanned list and applies it.
    // If the list is still empty (e.g. called via IPC before any open()),
    // triggers a scan first and applies once it completes.
    function applyRandom() {
        if (images.length === 0) {
            _pendingRandom = true
            reload()
            return
        }
        var pick = images[Math.floor(Math.random() * images.length)]
        apply(pick.path)
    }
    property bool _pendingRandom: false

    // ══════════════════════════════════════════════════════
    // PROCESSES
    // ══════════════════════════════════════════════════════

    // Scans wallpaperDir for image files (one per line: name<TAB>fullpath)
    Process {
        id: scanProc
        command: ["sh", "-c",
            "find \"" + wallpaper.wallpaperDir + "\" -maxdepth 1 -type f \\( " +
            wallpaper.extensions.map(e => "-iname \"*." + e + "\"").join(" -o ") +
            " \\) -printf \"%f\\t%p\\n\" 2>/dev/null | sort"
        ]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "")
                    return
                var parts = line.split("\t")
                if (parts.length < 2)
                    return
                var arr = wallpaper.images.slice()
                arr.push({ name: parts[0], path: parts[1] })
                wallpaper.images = arr
            }
        }
        onExited: function(code) {
            wallpaper.loading = false
            if (wallpaper._pendingRandom) {
                wallpaper._pendingRandom = false
                if (wallpaper.images.length > 0) {
                    var pick = wallpaper.images[Math.floor(Math.random() * wallpaper.images.length)]
                    wallpaper.apply(pick.path)
                }
            }
        }
    }

    // Reads the persisted wallpaper path on reload, so the picker can
    // highlight the currently-applied thumbnail.
    Process {
        id: readStateProc
        command: ["sh", "-c", "cat '" + wallpaper.stateFile + "' 2>/dev/null"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "")
                    wallpaper.currentWallpaper = line.trim()
            }
        }
    }

    // Applies the wallpaper by delegating to set-wallpaper.sh, which also
    // persists the path to stateFile and picks the right backend for the
    // detected compositor (see set-wallpaper.sh).
    Process {
        id: wallpaperProc
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t !== "" && t !== "ok")
                    wallpaper.lastError = "wallpaper: " + t
            }
        }
        onExited: function(code) {
            if (code !== 0)
                wallpaper.lastError = "wallpaper failed (code " + code + ")"
        }
    }

    // Clears the active wallpaper and removes stateFile, so the saved
    // wallpaper isn't reapplied by `set-wallpaper.sh startup` on the next
    // login.
    Process {
        id: clearProc
        command: [Quickshell.shellDir + "/wallpaper/set-wallpaper.sh", "clear"]
        running: false
        onExited: function(code) {
            if (code !== 0)
                wallpaper.lastError = "clear failed (code " + code + ")"
        }
    }

    // ══════════════════════════════════════════════════════
    // LAYER SHELL WINDOW
    // ══════════════════════════════════════════════════════
    visible: false
    color: "transparent"

    implicitWidth:  720
    implicitHeight: 520

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace:     "helium-d77-wallpaper"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea {
            anchors.fill: parent
            onClicked: wallpaper.hide()
        }
    }

    // ══════════════════════════════════════════════════════
    // PICKER BOX
    // ══════════════════════════════════════════════════════
    Rectangle {
        id: box
        anchors.centerIn: parent
        width:  parent.width
        height: parent.height
        radius: 12
        color: wallpaper.colBg
        border.color: wallpaper.colPurple
        border.width: 2

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 14
            spacing: 10

            // ── Header ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Wallpapers"
                    font.family: wallpaper.font
                    font.pixelSize: wallpaper.fsize + 4
                    font.bold: true
                    color: wallpaper.colFg
                }

                Item { Layout.fillWidth: true }

                Text {
                    visible: wallpaper.loading
                    text: "Loading..."
                    font.family: wallpaper.font
                    font.pixelSize: wallpaper.fsize - 1
                    color: wallpaper.colMuted
                }

                Text {
                    text: wallpaper.images.length + " wallpapers"
                    font.family: wallpaper.font
                    font.pixelSize: wallpaper.fsize - 1
                    color: wallpaper.colMuted
                }

                // Reset wallpaper: returns to the decorative backdrop (Backdrop.qml).
                Rectangle {
                    id: resetBtn
                    Layout.leftMargin: 4
                    implicitWidth:  resetRow.implicitWidth  + 16
                    implicitHeight: resetRow.implicitHeight + 8
                    radius: 6
                    color: resetMa.containsMouse ? Qt.rgba(0.94, 0.3, 0.3, 0.18) : "transparent"
                    border.width: 1
                    border.color: resetMa.containsMouse ? "#f7768e" : wallpaper.colMuted

                    RowLayout {
                        id: resetRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "󰑓"
                            font.family: wallpaper.font
                            font.pixelSize: wallpaper.fsize
                            color: "#f7768e"
                        }
                        Text {
                            text: "Clear"
                            font.family: wallpaper.font
                            font.pixelSize: wallpaper.fsize - 1
                            color: "#f7768e"
                        }
                    }

                    MouseArea {
                        id: resetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: wallpaper.clear()
                    }
                }
            }

            // ── Error banner ─────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: wallpaper.lastError !== ""
                height: visible ? 32 : 0
                radius: 6
                color: Qt.rgba(0.94, 0.3, 0.3, 0.15)
                border.color: "#f7768e"
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: wallpaper.lastError
                    font.family: wallpaper.font
                    font.pixelSize: wallpaper.fsize - 2
                    color: "#f7768e"
                }
            }

            // ── Grid ─────────────────────────────────────
            GridView {
                id: grid
                Layout.fillWidth:  true
                Layout.fillHeight: true
                clip: true
                cellWidth:  160
                cellHeight: 110
                model: wallpaper.images
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    required property int index
                    required property var modelData

                    width:  grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 8
                        color: Qt.darker(wallpaper.colBg, 1.2)
                        border.width: modelData.path === wallpaper.currentWallpaper ? 3 : 1
                        border.color: modelData.path === wallpaper.currentWallpaper
                            ? wallpaper.colPurple
                            : (thumbMa.containsMouse ? wallpaper.colBlue : wallpaper.colMuted)
                        clip: true

                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: "file://" + modelData.path
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true

                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 22
                                color: Qt.rgba(0, 0, 0, 0.55)

                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    font.family: wallpaper.font
                                    font.pixelSize: wallpaper.fsize - 3
                                    color: wallpaper.colFg
                                }
                            }
                        }

                        MouseArea {
                            id: thumbMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wallpaper.apply(modelData.path)
                        }
                    }
                }

                // Empty / loading message
                Text {
                    anchors.centerIn: parent
                    visible: wallpaper.images.length === 0
                    text: wallpaper.loading
                        ? "Loading wallpapers..."
                        : "No images found in\n" + wallpaper.wallpaperDir
                    horizontalAlignment: Text.AlignHCenter
                    font.family: wallpaper.font
                    font.pixelSize: wallpaper.fsize
                    color: wallpaper.colMuted
                }
            }
        }
    }

    // Close on Escape (needs focus; PanelWindow grabs keyboard via Exclusive)
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: wallpaper.hide()
    }
}
