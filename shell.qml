import QtQuick
import Quickshell
import Quickshell.Io
import "modules" as Modules
import "backdrop"
import "osd"
import "launcher"
import "lockscreen"
import "session"
import "wallpaper"
import "ollamachat"

ShellRoot {
    id: root

    // Ported from quickshell-d77: every surface in this shell is a Wayland
    // layer-shell client, so i3 (X11-only) is deliberately not detected.
    readonly property string compositor: {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== null) return "hyprland";
        if (Quickshell.env("SWAYSOCK") !== null) return "sway";
        if (Quickshell.env("NIRI_SOCKET") !== null) return "niri";
        return "generic";
    }

    // ══════════════════════════════════════════════════════
    // BACKDROP (conditional decorative background)
    // ══════════════════════════════════════════════════════
    // One instance per screen, on the Bottom layer-shell layer. Visible only
    // while Services.WallpaperState.hasWallpaper is false.
    WallpaperBackground {}

    // ══════════════════════════════════════════════════════
    // LAUNCHER
    // ══════════════════════════════════════════════════════
    // terminal is left unset: Launcher auto-detects it from
    // _termCandidates, and Network.qml's nmtui-float reuses whatever
    // it lands on — keeps both agnostic, matching quickshell-d77.
    Launcher {
        id: launcherPopup
    }

    // ══════════════════════════════════════════════════════
    // WALLPAPER PICKER
    // ══════════════════════════════════════════════════════
    Wallpaper {
        id: wallpaperPicker
        wallpaperDir: Quickshell.env("HOME") + "/Wallpaper"
    }

    // One bar per monitor; the popups (launcher, session menu, OSD) stay
    // single and are shared by every bar. Their ids must not match the Bar
    // properties they're bound to: inside a Variants delegate, `osd: osd`
    // resolves to the Bar's own (empty) property, not the id, which left
    // every bar button doing nothing.
    Variants {
        model: Quickshell.screens

        Modules.Bar {
            required property var modelData
            screen: modelData
            appLauncher: launcherPopup
            sessionMenu: sessionPopup
            osd: osdPopup
            compositor: root.compositor
        }
    }

    // ══════════════════════════════════════════════════════
    // LOCKSCREEN
    // ══════════════════════════════════════════════════════
    Lockscreen {
        id: lockScreen
    }

    // ══════════════════════════════════════════════════════
    // SESSION MENU (suspend/reboot/poweroff/logout)
    // ══════════════════════════════════════════════════════
    SessionMenu {
        id: sessionPopup
        compositor: root.compositor
        onLockRequested: lockScreen.lock()
    }

    // ══════════════════════════════════════════════════════
    // OSD (On-Screen Display: volume + brightness)
    // ══════════════════════════════════════════════════════
    Osd {
        id: osdPopup
        step:    5
        timeout: 2500
    }

    // ══════════════════════════════════════════════════════
    // OLLAMA CHAT
    // ══════════════════════════════════════════════════════
    // Native chat popup for a locally running Ollama daemon
    // (http://127.0.0.1:11434). Ported from quickshell-d77. No bar button —
    // the feature isn't consistent or reliable enough yet to earn permanent
    // bar real estate. Open it via IPC (see the ollamachat IpcHandler below)
    // or a keybind.
    OllamaChat {
        id: ollamaChat
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { launcherPopup.toggle() }
        function open(): void { launcherPopup.open() }
        function close(): void { launcherPopup.close() }
    }

    IpcHandler {
        target: "lockscreen"

        function lock(): void { lockScreen.lock() }
        function unlock(): void { lockScreen.unlock() }
        function toggle(): void { lockScreen.toggle() }
    }

    IpcHandler {
        target: "session"

        function toggle(): void { sessionPopup.toggle() }
        function open(): void { sessionPopup.open() }
        function close(): void { sessionPopup.close() }
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void { wallpaperPicker.toggle() }
        function open(): void { wallpaperPicker.open() }
        function close(): void { wallpaperPicker.close() }
        function reload(): void { wallpaperPicker.reload() }
        function set(path: string): void { wallpaperPicker.apply(path) }
        function random(): void { wallpaperPicker.applyRandom() }
        function clear(): void { wallpaperPicker.clear() }
    }

    IpcHandler {
        target: "ollamachat"

        function toggle(): void { ollamaChat.toggle() }
        function open(): void { ollamaChat.open() }
        function close(): void { ollamaChat.close() }
    }

    IpcHandler {
        target: "utumno"

        function reload(): void {
            Qt.callLater(() => Quickshell.reload(true));
        }

        function toggle(): void {
            // placeholder para futuros popups (launcher, control center...)
        }
    }

    // OSD IPC (volume via ALSA + brightness via brightnessctl).
    // Bind to multimedia keys in your compositor config, e.g.:
    //   bindel = , XF86AudioRaiseVolume, exec, qs -c utumno ipc call osd volumeUp
    IpcHandler {
        target: "osd"

        function volumeUp(): void { osdPopup.volumeUp() }
        function volumeDown(): void { osdPopup.volumeDown() }
        function volumeMuteToggle(): void { osdPopup.volumeMuteToggle() }
        function brightnessUp(): void { osdPopup.brightnessUp() }
        function brightnessDown(): void { osdPopup.brightnessDown() }
        function showVolume(): void { osdPopup.showVolume() }
        function showBrightness(): void { osdPopup.showBrightness() }
    }
}
