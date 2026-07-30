# Utumno

A minimal QML/Quickshell desktop shell for Wayland compositors, in the same spirit as
[`fabric-d77`](https://github.com/dani-77/fabric-d77) and
[`quickshell-d77`](https://github.com/dani-77/quickshell-d77) — Tokyo Night theme,
lean tooling, terminal-first workflow. Deliberately lighter than `quickshell-d77`: it ports
the bar, launcher, wallpaper picker, lockscreen, session menu, OSD and Ollama chat popup,
but leaves out the dashboard, music picker and greeter, which quickshell-d77 still owns.

Built primarily for [niri](https://github.com/YaLTeR/niri), and works just as well on
[Hyprland](https://hyprland.org/) — `shell.qml` auto-detects the running compositor
(`HYPRLAND_INSTANCE_SIGNATURE`/`SWAYSOCK`/`NIRI_SOCKET`) and switches the workspaces widget
and session-menu logout accordingly. Sway is wired up the same way and should work too, and
anything else exposing `ext-workspace-v1` (mangowc, etc.) falls back to the generic
workspaces widget — but **only niri and Hyprland have actually been tested**; treat Sway and
other compositors as untested/best-effort.

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
    protocol). Untested — not verified against a real Sway instance.
  - `Workspaces.qml` — the compositor-agnostic `Quickshell.WindowManager`
    (`ext-workspace-v1`) widget, used for niri and anything else (mangowc included). Shows
    only the workspaces that actually exist (niri creates them dynamically), not a fixed
    1-9 grid. **Verified working** on niri; other `ext-workspace-v1` compositors are
    untested.
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
- Launcher button (left), Ollama chat button (left, "AI"), and session button (right, ⏻),
  all ported from quickshell-d77

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
  (compositor-agnostic: tries `swww`/`swaybg`/`feh`, since neither niri nor Hyprland ship a
  native wallpaper protocol)
- **`lockscreen/`** — real `WlSessionLock`, password validated via PAM
  (`Quickshell.Services.Pam`)
- **`session/`** — suspend/reboot/poweroff/logout menu, via `loginctl`/`systemctl`, with a
  per-compositor logout (`hyprctl dispatch hl.dsp.exit()` on Hyprland, `swaymsg exit` on
  Sway, `niri msg action quit` on niri — the niri path also avoids a known niri issue where
  `loginctl terminate-session` leaves `niri.service` stuck active — see
  [niri-wm/niri#2729](https://github.com/niri-wm/niri/discussions/2729))
- **`osd/`** — top-right overlay for volume (ALSA/`amixer`) and brightness
  (`brightnessctl`), plus a power-profile cycler (`powerprofilesctl`)
- **`ollamachat/`** — native chat popup for a locally running [Ollama](https://ollama.com)
  daemon (`http://127.0.0.1:11434`), talked to via `curl`. Streams the model's response as
  it arrives, lets you switch between installed models or pull a new one straight from the
  popup (with live download progress), and remembers the last picked model at
  `~/.config/ollama-chat/model.conf` (shared with quickshell-d77, since it's the same file).
  Opened from the bar's green "AI" button or via IPC.

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

Or, on Hyprland, add to your `hyprland.conf`:

```
exec-once = qs -c utumno
```

If you use the wallpaper picker, restore the last wallpaper at login too (niri has no
preload step like Hyprland's hyprpaper, so this just re-applies it after startup):

```kdl
spawn-at-startup "sh" "-c" "~/.config/quickshell/utumno/wallpaper/set-wallpaper.sh startup"
```

```
exec-once = sh -c "~/.config/quickshell/utumno/wallpaper/set-wallpaper.sh startup"
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
├── session/
│   └── SessionMenu.qml     # suspend/reboot/poweroff/logout + error banner
└── ollamachat/
    └── OllamaChat.qml      # chat popup for a local Ollama daemon
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

qs -c utumno ipc call ollamachat toggle
qs -c utumno ipc call ollamachat open
qs -c utumno ipc call ollamachat close

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

### Equivalent Hyprland keybinds (`hyprland.conf`)

```
bind = SUPER, D, exec, qs -c utumno ipc call launcher toggle
bind = SUPER SHIFT, E, exec, qs -c utumno ipc call session toggle
bind = SUPER, L, exec, qs -c utumno ipc call lockscreen lock
bind = SUPER, Y, exec, qs -c utumno ipc call wallpaper toggle

bindel = , XF86AudioRaiseVolume, exec, qs -c utumno ipc call osd volumeUp
bindel = , XF86AudioLowerVolume, exec, qs -c utumno ipc call osd volumeDown
bindl  = , XF86AudioMute, exec, qs -c utumno ipc call osd volumeMuteToggle
bindel = , XF86MonBrightnessUp, exec, qs -c utumno ipc call osd brightnessUp
bindel = , XF86MonBrightnessDown, exec, qs -c utumno ipc call osd brightnessDown
```

## Roadmap

- [ ] Notifications (`Quickshell.Services.Notifications`)
- [ ] Control center popup (volume/brightness/network toggles in one panel, instead of
      only the OSD + bar widgets)

## License

MIT (or update to match your other repos).
