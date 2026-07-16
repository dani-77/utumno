// ══════════════════════════════════════════════════════
// SessionMenu.qml
// Session menu popup (lock/suspend/reboot/shutdown/logout) +
// the session error banner. Ported from quickshell-d77's inline
// shell.qml session menu, extracted into its own module since
// helium-d77 has no Dashboard to embed it in.
//
// Suspend/reboot/poweroff go through the freedesktop login1 D-Bus
// interface via `loginctl`, which works identically whether it's
// backed by systemd-logind or elogind (falls back to `systemctl`
// if loginctl itself isn't on PATH). Logout prefers a native
// per-compositor exit so niri's systemd --user service (niri.service)
// gets cleaned up correctly instead of just detaching the display
// (see https://github.com/niri-wm/niri/discussions/2729); Hyprland/
// Sway use their own native exit dispatch, and anything else falls
// back to `loginctl terminate-session`.
// ══════════════════════════════════════════════════════
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../config" as Cfg

Scope {
    id: root

    required property string compositor

    // Emitted instead of calling Lockscreen directly, so this module
    // doesn't need a reference to it — shell.qml wires it up.
    signal lockRequested()

    property bool   sessionOpen: false
    property string sessionError: ""

    function open()   { root.sessionOpen = true }
    function close()  { root.sessionOpen = false }
    function toggle() { root.sessionOpen = !root.sessionOpen }

    function _sessionCmd(action) {
        return ["sh", "-c", "loginctl " + action + " 2>&1 || systemctl " + action + " 2>&1"]
    }
    function _sessionFailMsg(label, output) {
        var out = output.trim()
        return label + " failed" + (out !== "" ? ": " + out : " — no systemd-logind/elogind reachable?")
    }

    Process {
        id: suspendProc
        command: root._sessionCmd("suspend")
        running: false
        property string _out: ""
        stdout: SplitParser { onRead: line => suspendProc._out += line + " " }
        onExited: function(code) {
            if (code !== 0) root.sessionError = root._sessionFailMsg("Suspend", suspendProc._out)
            suspendProc._out = ""
        }
    }
    Process {
        id: rebootProc
        command: root._sessionCmd("reboot")
        running: false
        property string _out: ""
        stdout: SplitParser { onRead: line => rebootProc._out += line + " " }
        onExited: function(code) {
            if (code !== 0) root.sessionError = root._sessionFailMsg("Reboot", rebootProc._out)
            rebootProc._out = ""
        }
    }
    Process {
        id: shutdownProc
        command: root._sessionCmd("poweroff")
        running: false
        property string _out: ""
        stdout: SplitParser { onRead: line => shutdownProc._out += line + " " }
        onExited: function(code) {
            if (code !== 0) root.sessionError = root._sessionFailMsg("Poweroff", shutdownProc._out)
            shutdownProc._out = ""
        }
    }
    Process {
        id: logoutProc
        property string _out: ""
        command: {
            if (root.compositor === "hyprland") return ["hyprctl", "dispatch", "hl.dsp.exit()"];
            if (root.compositor === "sway") return ["swaymsg", "exit"];
            if (root.compositor === "niri") return ["niri", "msg", "action", "quit", "--skip-confirmation"];
            return ["sh", "-c", "loginctl terminate-session \"${XDG_SESSION_ID:-self}\" 2>&1"];
        }
        running: false
        stdout: SplitParser { onRead: line => logoutProc._out += line + " " }
        onExited: function(code) {
            if (code !== 0) root.sessionError = root._sessionFailMsg("Logout", logoutProc._out)
            logoutProc._out = ""
        }
    }

    Timer {
        id: sessionErrorTimer
        interval: 5000
        onTriggered: root.sessionError = ""
    }
    onSessionErrorChanged: {
        if (root.sessionError !== "")
            sessionErrorTimer.restart()
    }

    // ══════════════════════════════════════════════════════
    // SESSION POPUP
    // ══════════════════════════════════════════════════════
    PanelWindow {
        id: sessionPopup
        visible: root.sessionOpen
        color: "transparent"

        anchors.top:    true
        anchors.bottom: true
        anchors.left:   true
        anchors.right:  true

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "helium-d77-session"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: {
            if (visible) {
                sessionBox.currentIndex = 0
                sessionBox.forceActiveFocus()
            }
        }

        // Dimmed backdrop; clicking it closes the menu.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.35)
            MouseArea {
                anchors.fill: parent
                onClicked: root.sessionOpen = false
            }
        }

        // ── Central session menu box ──────────────────────
        Rectangle {
            id: sessionBox
            anchors.centerIn: parent
            width:  220
            height: 256
            radius: 12
            color: Qt.darker(Cfg.Colors.bg, 1.4)
            border.color: Cfg.Colors.red
            border.width: 2

            property int currentIndex: 0

            readonly property var sessionActions: [
                null, suspendProc, rebootProc, shutdownProc, logoutProc
            ]

            function activateSelected() {
                root.sessionOpen = false
                if (currentIndex === 0) root.lockRequested()
                else                    sessionActions[currentIndex].running = true
            }

            focus: true
            Keys.onUpPressed:     currentIndex = (currentIndex - 1 + sessionActions.length) % sessionActions.length
            Keys.onDownPressed:   currentIndex = (currentIndex + 1) % sessionActions.length
            Keys.onEscapePressed: root.sessionOpen = false
            Keys.onReturnPressed: activateSelected()
            Keys.onEnterPressed:  activateSelected()

            // Swallow clicks inside the box so they don't reach the backdrop.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill:    parent
                anchors.margins: 10
                spacing: 4

                // Lock
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: (ma0.containsMouse || sessionBox.currentIndex === 0) ? Qt.rgba(0.48, 0.64, 0.97, 0.2) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Text {
                            text: "󰌾"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 10 }
                            color: Cfg.Colors.blue
                        }
                        Text {
                            text: "Lock"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 1 }
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Cfg.Colors.fgDark
                        }
                    }
                    MouseArea {
                        id: ma0
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: sessionBox.currentIndex = 0
                        onClicked: {
                            root.sessionOpen = false
                            root.lockRequested()
                        }
                    }
                }

                // Suspend
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: (ma1.containsMouse || sessionBox.currentIndex === 1) ? Qt.rgba(0.88, 0.69, 0.41, 0.2) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Text {
                            text: "󰒲"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 10 }
                            color: Cfg.Colors.yellow
                        }
                        Text {
                            text: "Suspend"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 1 }
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Cfg.Colors.fgDark
                        }
                    }
                    MouseArea {
                        id: ma1
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: sessionBox.currentIndex = 1
                        onClicked: {
                            root.sessionOpen = false
                            suspendProc.running = true
                        }
                    }
                }

                // Reboot
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: (ma2.containsMouse || sessionBox.currentIndex === 2) ? Qt.rgba(0.88, 0.69, 0.41, 0.2) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Text {
                            text: "󰑓"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 10 }
                            color: Cfg.Colors.yellow
                        }
                        Text {
                            text: "Reboot"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 1 }
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Cfg.Colors.fgDark
                        }
                    }
                    MouseArea {
                        id: ma2
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: sessionBox.currentIndex = 2
                        onClicked: {
                            root.sessionOpen = false
                            rebootProc.running = true
                        }
                    }
                }

                // Shutdown
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: (ma3.containsMouse || sessionBox.currentIndex === 3) ? Qt.rgba(0.97, 0.46, 0.56, 0.2) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Text {
                            text: "󰐥"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 10 }
                            color: Cfg.Colors.red
                        }
                        Text {
                            text: "Shutdown"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 1 }
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Cfg.Colors.fgDark
                        }
                    }
                    MouseArea {
                        id: ma3
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: sessionBox.currentIndex = 3
                        onClicked: {
                            root.sessionOpen = false
                            shutdownProc.running = true
                        }
                    }
                }

                // Logout
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 6
                    color: (ma4.containsMouse || sessionBox.currentIndex === 4) ? Qt.rgba(0.27, 0.29, 0.42, 0.5) : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 8
                        Text {
                            text: "󰍃"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 10 }
                            color: Cfg.Colors.muted
                        }
                        Text {
                            text: "Logout"
                            font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize + 1 }
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: Cfg.Colors.fgDark
                        }
                    }
                    MouseArea {
                        id: ma4
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: sessionBox.currentIndex = 4
                        onClicked: {
                            root.sessionOpen = false
                            logoutProc.running = true
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════
    // SESSION ERROR BANNER
    // Small auto-hiding toast for when a session action (suspend/
    // reboot/poweroff/logout) fails — e.g. no systemd-logind/elogind on
    // D-Bus. Independent of sessionPopup, which is already closed by the
    // time a Process can fail.
    // ══════════════════════════════════════════════════════
    PanelWindow {
        id: sessionErrorBanner
        visible: root.sessionError !== ""
        color: "transparent"

        anchors.top: true
        margins.top: 50

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "helium-d77-session-error"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusiveZone: 0

        // Empty mask → does not block mouse events (matches Osd.qml).
        mask: Region {}

        // Real D-Bus/systemd error text can run long (e.g. "Failed to
        // issue method call: Caller does not belong to any known
        // session."), so cap the width and wrap instead of stretching
        // across the screen.
        implicitWidth:  Math.min(bannerText.implicitWidth + 40, 640)
        implicitHeight: bannerText.implicitHeight + 24

        Rectangle {
            id: banner
            anchors.fill: parent
            radius: 8
            color: Qt.darker(Cfg.Colors.bg, 1.2)
            border.color: Cfg.Colors.red
            border.width: 2

            Text {
                id: bannerText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 600)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.sessionError
                font { family: Cfg.Colors.font; pixelSize: Cfg.Colors.fsize }
                color: Cfg.Colors.red
            }
        }
    }
}
