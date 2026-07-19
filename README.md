# Utumno

A minimal QML/Quickshell desktop shell for [niri](https://github.com/YaLTeR/niri), in the
same spirit as [`fabric-d77`](https://github.com/dani-77/fabric-d77) and
[`quickshell-d77`](https://github.com/dani-77/quickshell-d77) — Tokyo Night theme,
lean tooling, terminal-first workflow. Deliberately lighter than `quickshell-d77`: it ports
the bar, launcher, wallpaper picker, lockscreen, session menu and OSD, but leaves out the
dashboard, music picker and greeter, which quickshell-d77 still owns.

## Current state

Floating top bar (`modules/Bar.qml`, rounded corners, gap from screen edges) with:

- **Workspaces** — a `Loader` in `Bar.qml` picks the right widget for the running
  compositor (`shell.qml`'s `compositor` detection), matching quickshell-d77's own
  per-compositor approach instead of one generic widget for everyone:
  - `WorkspacesHyprland.qml` — fixed 1-9 grid via `Quickshell.Hyprland`. Switching goes
    through `hyprctl dispatch "hl.dsp.focus({workspace = N})"` (a `Process`, not
    `Quickshell.Hyprland.dispatch()`) because this setup's Hyprland config only wires up
    custom Lua dispatchers (`hl.dsp.focus`/`hl.dsp.exit`, same as `session/SessionMenu.qml`'s
    logout) — the plain dispatch call is silently rejected by Hyprland's Lua layer.
    **Verified working** against a real Hyprland instance.
  - `WorkspacesSway.qml` — fixed 1-9 grid via `Quickshell.I3` (Sway implements the i3 IPC
    protocol). **Verified working.**
  - `Workspaces.qml` — the compositor-agnostic `Quickshell.WindowManager`
    (`ext-workspace-v1`) widget, used for niri and anything else (mangowc included). Shows
    only the workspaces that actually exist (niri creates them dynamically), not a fixed
    1-9 grid. **Verified working** on niri.
- `Clock.qml`
- `Weather.qml` — wttr.in condition icon + temperature (`?format=%c+%t`), polled every
  15 min, shown left of the clock (ported from quickshell-d77's Dashboard, minus the
  location text — no room for it in a bar widget)
- `Cpu.qml` / `Ram.qml` — usage % polled from `/proc/stat` / `/proc/meminfo`
- `Volume.qml` — ALSA volume/mute via `amixer` (this setup runs plain PulseAudio,
  not PipeWire, so volume is read through ALSA rather than
  `Quickshell.Services.Pipewire`)
- `Network.qml` — SSID + signal quality via `Quickshell.Networking`; click opens `nmtui`
  in a floating terminal (`--class nmtui-float`), same as quickshell-d77's bar
- `Battery.qml` — state-dependent Nerd Font icon (charging/level) + % via
  `UPower.displayDevice`; click cycles the power profile
  (`osd.cyclePowerProfile()`/`powerprofilesctl`), same as quickshell-d77's bar
- Launcher button (left) and session button (right, ⏻), both ported from quickshell-d77

The launcher and `nmtui-float` share one auto-detected terminal (`Launcher.qml`'s
`_termCandidates`: alacritty > kitty > foot > wezterm > xterm) — nothing hardcoded, matching
quickshell-d77.

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
git clone https://github.com/dani-77/utumno ~/.config/quickshell/utumno
```

Add to your niri `config.kdl`:

```kdl
spawn-at-startup "qs" "-c" "utumno"
```

If you use the wallpaper picker, restore the last wallpaper at login too (niri has no
preload step like Hyprland's hyprpaper, so this just re-applies it after startup):

```kdl
spawn-at-startup "sh" "-c" "~/.config/quickshell/utumno/wallpaper/set-wallpaper.sh startup"
```

To test without installing into `~/.config/quickshell/` first:

```sh
qs -c utumno -p /path/to/utumno
```

## Structure

```
utumno/
├── shell.qml              # entry point: compositor detection, module wiring, IpcHandlers
├── modules/
│   ├── Bar.qml               # PanelWindow (WlrLayer.Top), floating + rounded
│   ├── Workspaces.qml        # niri/generic workspaces via Quickshell.WindowManager
│   ├── WorkspacesHyprland.qml # Hyprland workspaces via Quickshell.Hyprland + hl.dsp.focus
│   ├── WorkspacesSway.qml    # Sway workspaces via Quickshell.I3
│   ├── Clock.qml
│   ├── Weather.qml           # wttr.in condition icon + temperature
│   ├── Cpu.qml               # /proc/stat polling
│   ├── Ram.qml               # /proc/meminfo polling
│   ├── Volume.qml            # amixer (ALSA)
│   ├── Network.qml           # SSID via Quickshell.Networking, click opens nmtui
│   └── Battery.qml           # via UPower.displayDevice, click cycles power profile
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
qs -c utumno ipc call utumno reload

qs -c utumno ipc call launcher toggle
qs -c utumno ipc call launcher open
qs -c utumno ipc call launcher close

qs -c utumno ipc call wallpaper toggle
qs -c utumno ipc call wallpaper open
qs -c utumno ipc call wallpaper close
qs -c utumno ipc call wallpaper reload
qs -c utumno ipc call wallpaper set /path/to/image.png
qs -c utumno ipc call wallpaper random
qs -c utumno ipc call wallpaper clear

qs -c utumno ipc call lockscreen lock
qs -c utumno ipc call lockscreen unlock
qs -c utumno ipc call lockscreen toggle

qs -c utumno ipc call session toggle
qs -c utumno ipc call session open
qs -c utumno ipc call session close

qs -c utumno ipc call osd volumeUp
qs -c utumno ipc call osd volumeDown
qs -c utumno ipc call osd volumeMuteToggle
qs -c utumno ipc call osd brightnessUp
qs -c utumno ipc call osd brightnessDown
qs -c utumno ipc call osd showVolume
qs -c utumno ipc call osd showBrightness

qs -c utumno ipc show     # list every target/function exposed
```

### Suggested niri keybinds (`config.kdl`)

```kdl
binds {
    Mod+D          { spawn "qs" "-c" "utumno" "ipc" "call" "launcher" "toggle"; }
    Mod+Shift+E    { spawn "qs" "-c" "utumno" "ipc" "call" "session" "toggle"; }
    Mod+L          { spawn "qs" "-c" "utumno" "ipc" "call" "lockscreen" "lock"; }
    Mod+Y          { spawn "qs" "-c" "utumno" "ipc" "call" "wallpaper" "toggle"; }

    XF86AudioRaiseVolume  { spawn "qs" "-c" "utumno" "ipc" "call" "osd" "volumeUp"; }
    XF86AudioLowerVolume  { spawn "qs" "-c" "utumno" "ipc" "call" "osd" "volumeDown"; }
    XF86AudioMute         { spawn "qs" "-c" "utumno" "ipc" "call" "osd" "volumeMuteToggle"; }
    XF86MonBrightnessUp   { spawn "qs" "-c" "utumno" "ipc" "call" "osd" "brightnessUp"; }
    XF86MonBrightnessDown { spawn "qs" "-c" "utumno" "ipc" "call" "osd" "brightnessDown"; }
}
```

## Roadmap

- [ ] Notifications (`Quickshell.Services.Notifications`)
- [ ] Control center popup (volume/brightness/network toggles in one panel, instead of
      only the OSD + bar widgets)

## License

MIT (or update to match your other repos).
