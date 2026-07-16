# helium-d77

A minimal QML/Quickshell desktop shell for [niri](https://github.com/YaLTeR/niri), in the
same spirit as [`fabric-d77`](https://github.com/dani-77/fabric-d77) and
[`quickshell-d77`](https://github.com/dani-77/quickshell-d77) — Tokyo Night theme,
lean tooling, terminal-first workflow. Deliberately lighter than `quickshell-d77`: it ports
the bar, launcher, wallpaper picker, lockscreen, session menu and OSD, but leaves out the
dashboard, music picker and greeter, which quickshell-d77 still owns.

## Current state

Floating top bar (`modules/Bar.qml`, rounded corners, gap from screen edges) with:

- `Workspaces.qml` — niri workspaces via the compositor-agnostic
  `Quickshell.WindowManager` (`ext-workspace-v1`) module, click to switch. Shows only the
  workspaces that actually exist (niri creates them dynamically), not a fixed 1-9 grid.
- `Clock.qml`
- `Cpu.qml` / `Ram.qml` — usage % polled from `/proc/stat` / `/proc/meminfo`
- `Volume.qml` — ALSA volume/mute via `amixer` (this setup runs plain PulseAudio,
  not PipeWire, so volume is read through ALSA rather than
  `Quickshell.Services.Pipewire`)
- `Network.qml` — SSID + signal quality via `Quickshell.Networking`
- `Battery.qml` — state-dependent Nerd Font icon (charging/level) + % via `UPower.displayDevice`
- Launcher button (left) and session button (right, ⏻), both ported from quickshell-d77

Plus, ported from quickshell-d77 and adapted to this shell's `config/Colors.qml` palette
instead of an inline `g` singleton:

- **`backdrop/`** — decorative Tokyo Night background (chevrons + logo), shown only while
  no wallpaper is set (`Services/WallpaperState.qml`)
- **`launcher/`** — native Rofi-style application launcher (`.desktop` scanning, fuzzy
  filter, keyboard nav)
- **`wallpaper/`** — grid wallpaper picker, applies via `wallpaper/set-wallpaper.sh`
  (compositor-agnostic: tries `swww`/`swaybg`/`feh` on niri, since niri has no native
  wallpaper protocol)
- **`lockscreen/`** — real `WlSessionLock`, password validated via PAM
  (`Quickshell.Services.Pam`)
- **`session/`** — suspend/reboot/poweroff/logout menu, via `loginctl`/`systemctl`, with a
  native `niri msg action quit` logout (avoids a known niri issue where
  `loginctl terminate-session` leaves `niri.service` stuck active — see
  [niri-wm/niri#2729](https://github.com/niri-wm/niri/discussions/2729))
- **`osd/`** — top-right overlay for volume (ALSA/`amixer`) and brightness
  (`brightnessctl`), plus a power-profile cycler (`powerprofilesctl`)

Not ported on purpose (kept lighter than quickshell-d77): the dashboard, the cmus-backed
music picker, and the greetd login greeter — the last one especially, since it would mean
touching this system's actual live login configuration.

Every ported module exposes the **same IPC target/function names as quickshell-d77** (see
below), so muscle memory and keybinds carry over directly.

## Dependencies (Void Linux)

```sh
sudo xbps-install quickshell niri qt6-base qt6-declarative qt6-svg \
    qt6-shadertools alsa-utils upower NetworkManager polkit brightnessctl
```

Optional, depending on which ported modules you use:

- **Wallpaper picker**: one of `swww` (needs `swww-daemon` running), `swaybg`, or `feh`
- **Lockscreen**: PAM (`linux-pam`, already part of Void's base system) — no extra package
- **Session menu**: `elogind` (Void's non-systemd `loginctl`/`systemctl` provider — usually
  already pulled in by your desktop meta-package)
- **OSD power profile cycling**: `power-profiles-daemon` (`powerprofilesctl`)

## Installation

```sh
git clone https://github.com/dani-77/helium-d77 ~/.config/quickshell/helium-d77
```

Add to your niri `config.kdl`:

```kdl
spawn-at-startup "qs" "-c" "helium-d77"
```

If you use the wallpaper picker, restore the last wallpaper at login too (niri has no
preload step like Hyprland's hyprpaper, so this just re-applies it after startup):

```kdl
spawn-at-startup "sh" "-c" "~/.config/quickshell/helium-d77/wallpaper/set-wallpaper.sh startup"
```

To test without installing into `~/.config/quickshell/` first:

```sh
qs -c helium-d77 -p /path/to/helium-d77
```

## Structure

```
helium-d77/
├── shell.qml              # entry point: compositor detection, module wiring, IpcHandlers
├── modules/
│   ├── Bar.qml             # PanelWindow (WlrLayer.Top), floating + rounded
│   ├── Workspaces.qml      # niri workspaces via Quickshell.WindowManager
│   ├── Clock.qml
│   ├── Cpu.qml             # /proc/stat polling
│   ├── Ram.qml             # /proc/meminfo polling
│   ├── Volume.qml          # amixer (ALSA)
│   ├── Network.qml         # SSID via Quickshell.Networking
│   └── Battery.qml         # via UPower.displayDevice
├── config/
│   └── Colors.qml          # Tokyo Night singleton (colors + font/fsize)
├── Services/
│   └── WallpaperState.qml  # singleton: currently active wallpaper path
├── backdrop/
│   ├── Backdrop.qml
│   ├── WallpaperBackground.qml
│   └── assets/d77-logo.svg
├── launcher/
│   ├── Launcher.qml
│   ├── AppLoader.qml
│   ├── DesktopDirScanner.qml
│   └── desktopParser.js
├── wallpaper/
│   ├── Wallpaper.qml
│   └── set-wallpaper.sh
├── lockscreen/
│   ├── Lockscreen.qml
│   ├── LockContext.qml
│   ├── LockSurface.qml
│   └── pam/password.conf
├── osd/
│   └── Osd.qml
└── session/
    └── SessionMenu.qml     # suspend/reboot/poweroff/logout + error banner
```

## IPC

Every target/function name matches quickshell-d77 exactly:

```sh
qs -c helium-d77 ipc call helium reload

qs -c helium-d77 ipc call launcher toggle
qs -c helium-d77 ipc call launcher open
qs -c helium-d77 ipc call launcher close

qs -c helium-d77 ipc call wallpaper toggle
qs -c helium-d77 ipc call wallpaper open
qs -c helium-d77 ipc call wallpaper close
qs -c helium-d77 ipc call wallpaper reload
qs -c helium-d77 ipc call wallpaper set /path/to/image.png
qs -c helium-d77 ipc call wallpaper random
qs -c helium-d77 ipc call wallpaper clear

qs -c helium-d77 ipc call lockscreen lock
qs -c helium-d77 ipc call lockscreen unlock
qs -c helium-d77 ipc call lockscreen toggle

qs -c helium-d77 ipc call session toggle
qs -c helium-d77 ipc call session open
qs -c helium-d77 ipc call session close

qs -c helium-d77 ipc call osd volumeUp
qs -c helium-d77 ipc call osd volumeDown
qs -c helium-d77 ipc call osd volumeMuteToggle
qs -c helium-d77 ipc call osd brightnessUp
qs -c helium-d77 ipc call osd brightnessDown
qs -c helium-d77 ipc call osd showVolume
qs -c helium-d77 ipc call osd showBrightness

qs -c helium-d77 ipc show     # list every target/function exposed
```

### Suggested niri keybinds (`config.kdl`)

```kdl
binds {
    Mod+D          { spawn "qs" "-c" "helium-d77" "ipc" "call" "launcher" "toggle"; }
    Mod+Shift+E    { spawn "qs" "-c" "helium-d77" "ipc" "call" "session" "toggle"; }
    Mod+L          { spawn "qs" "-c" "helium-d77" "ipc" "call" "lockscreen" "lock"; }
    Mod+Y          { spawn "qs" "-c" "helium-d77" "ipc" "call" "wallpaper" "toggle"; }

    XF86AudioRaiseVolume  { spawn "qs" "-c" "helium-d77" "ipc" "call" "osd" "volumeUp"; }
    XF86AudioLowerVolume  { spawn "qs" "-c" "helium-d77" "ipc" "call" "osd" "volumeDown"; }
    XF86AudioMute         { spawn "qs" "-c" "helium-d77" "ipc" "call" "osd" "volumeMuteToggle"; }
    XF86MonBrightnessUp   { spawn "qs" "-c" "helium-d77" "ipc" "call" "osd" "brightnessUp"; }
    XF86MonBrightnessDown { spawn "qs" "-c" "helium-d77" "ipc" "call" "osd" "brightnessDown"; }
}
```

## Roadmap

- [ ] Notifications (`Quickshell.Services.Notifications`)
- [ ] Control center popup (volume/brightness/network toggles in one panel, instead of
      only the OSD + bar widgets)

## License

MIT (or update to match your other repos).
