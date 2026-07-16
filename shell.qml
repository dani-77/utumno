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
    Launcher {
        id: appLauncher
        terminal: "alacritty"
    }

    // ══════════════════════════════════════════════════════
    // WALLPAPER PICKER
    // ══════════════════════════════════════════════════════
    Wallpaper {
        id: wallpaperPicker
        wallpaperDir: Quickshell.env("HOME") + "/Wallpaper"
    }

    Modules.Bar {
        appLauncher: appLauncher
        sessionMenu: sessionMenu
        compositor: root.compositor
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
        id: sessionMenu
        compositor: root.compositor
        onLockRequested: lockScreen.lock()
    }

    // ══════════════════════════════════════════════════════
    // OSD (On-Screen Display: volume + brightness)
    // ══════════════════════════════════════════════════════
    Osd {
        id: osd
        step:    5
        timeout: 2500
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { appLauncher.toggle() }
        function open(): void { appLauncher.open() }
        function close(): void { appLauncher.close() }
    }

    IpcHandler {
        target: "lockscreen"

        function lock(): void { lockScreen.lock() }
        function unlock(): void { lockScreen.unlock() }
        function toggle(): void { lockScreen.toggle() }
    }

    IpcHandler {
        target: "session"

        function toggle(): void { sessionMenu.toggle() }
        function open(): void { sessionMenu.open() }
        function close(): void { sessionMenu.close() }
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
        target: "helium"

        function reload(): void {
            Qt.callLater(() => Quickshell.reload(true));
        }

        function toggle(): void {
            // placeholder para futuros popups (launcher, control center...)
        }
    }

    // OSD IPC (volume via ALSA + brightness via brightnessctl).
    // Bind to multimedia keys in your compositor config, e.g.:
    //   bindel = , XF86AudioRaiseVolume, exec, qs -c helium-d77 ipc call osd volumeUp
    IpcHandler {
        target: "osd"

        function volumeUp(): void { osd.volumeUp() }
        function volumeDown(): void { osd.volumeDown() }
        function volumeMuteToggle(): void { osd.volumeMuteToggle() }
        function brightnessUp(): void { osd.brightnessUp() }
        function brightnessDown(): void { osd.brightnessDown() }
        function showVolume(): void { osd.showVolume() }
        function showBrightness(): void { osd.showBrightness() }
    }
}
