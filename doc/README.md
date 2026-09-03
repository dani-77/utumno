# Utumno — technical documentation

> Looking to install or use Utumno? See the [root README](../README.md) instead — this
> document covers architecture, module internals and the full IPC reference.

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
  15 min, shown left of the clock (ported from quickshell-d77's Dashboard). The fuller
  `?format=3` line (location + condition + temp) is fetched alongside it and shown as
  a tooltip below the bar on hover.
- `Cpu.qml` / `Ram.qml` — usage % polled from `/proc/stat` / `/proc/meminfo`
- `Volume.qml` — ALSA volume/mute via `amixer` (this setup runs plain PulseAudio,
  not PipeWire, so volume is read through ALSA rather than
  `Quickshell.Services.Pipewire`)
- `Network.qml` — SSID + signal quality via `Quickshell.Networking`; click opens `nmtui`
  in a floating terminal (`--class nmtui-float`), same as quickshell-d77's bar
- `Battery.qml` — state-dependent Nerd Font icon (charging/level) + % via
  `UPower.displayDevice`; click cycles the power profile
  (`osd.cyclePowerProfile()`/`powerprofilesctl`), same as quickshell-d77's bar
- Launcher button (left) and session button (right, ⏻), both ported from quickshell-d77.
  The Ollama chat has no bar button (see `ollamachat/` below) — keybind/IPC only.

The launcher and `nmtui-float` share one auto-detected terminal (`Launcher.qml`'s
`_termCandidates`: alacritty > kitty > foot > wezterm > xterm) — nothing hardcoded, matching
quickshell-d77.

Plus, ported from quickshell-d77 and adapted to this shell's `config/Colors.qml` palette
instead of an inline `g` singleton:

- **`backdrop/`** — decorative Tokyo Night background (chevrons + logo), shown only while
  no wallpaper is set (`Services/WallpaperState.qml`)
- **`launcher/`** — native Rofi-style application launcher (`.desktop` scanning, fuzzy
  filter, keyboard nav)
- **`wallpaper/`** — grid wallpaper picker, applies via `wallpaper/set-wallpaper.sh`, which
  branches per compositor: on Hyprland it detects whichever wallpaper daemon is actually
  running (`hyprpaper`, `swww`, or `swaybg`) and drives that one — Hyprland itself doesn't
  draw wallpapers, so assuming hyprpaper would silently no-op on a swww/swaybg setup;
  `swaymsg output ... bg` on Sway; and — since niri has no native wallpaper protocol — the
  same `swww`/`swaybg`/`feh` fallback chain for niri and anything else. If swww is picked
  but `swww-daemon` isn't running yet, the script starts it itself.
- **`lockscreen/`** — real `WlSessionLock`, password validated via PAM
  (`Quickshell.Services.Pam`)
- **`session/`** — suspend/reboot/poweroff/logout menu, via `loginctl`/`systemctl`, with a
  per-compositor logout (`hyprctl dispatch hl.dsp.exit()` on Hyprland, `swaymsg exit` on
  Sway, `niri msg action quit --skip-confirmation` on niri — the niri path also avoids a
  known niri issue where `loginctl terminate-session` leaves `niri.service` stuck active — see
  [niri-wm/niri#2729](https://github.com/niri-wm/niri/discussions/2729))
- **`osd/`** — top-right overlay for volume (ALSA/`amixer`) and brightness
  (`brightnessctl`), plus a power-profile cycler (`powerprofilesctl`)
- **`ollamachat/`** — native chat popup for a locally running [Ollama](https://ollama.com)
  daemon (`http://127.0.0.1:11434`), talked to via `curl`. Streams the model's response as
  it arrives, lets you switch between installed models or pull a new one straight from the
  popup (with live download progress), and remembers the last picked model at
  `~/.config/ollama-chat/model.conf` (shared with quickshell-d77, since it's the same file).
  Chat requests go through `/api/chat` with the whole conversation history sent each time, so
  the model actually remembers earlier turns instead of seeing each prompt in isolation; the
  model itself stays loaded for the rest of the session (`keep_alive: "5m"`) rather than
  reloading from scratch on every message, and is explicitly unloaded the moment the popup
  closes. There's deliberately no bar button for it — the feature isn't consistent or reliable
  enough yet to earn permanent bar real estate. Open it via IPC or a keybind instead (see
  the root README). On startup it also runs a one-off
  hardware check (`nvidia-smi` for NVIDIA VRAM, `rocm-smi`/`lspci` for AMD or other dedicated
  GPUs, falling back to total system RAM when there's no dedicated GPU) and shows a suggested
  model-size range for the machine; installed models matching that range get a `★` in the
  picker. The `lspci` fallback also cross-checks `/proc/cpuinfo` for AMD's "with Radeon
  Graphics" marketing suffix (present on nearly every iGPU-equipped Ryzen) — some AMD APUs
  report only a bare codename in `lspci` (e.g. `[AMD/ATI] Barcelo`, no "Radeon"/"Graphics" in
  it) that would otherwise be mistaken for a dedicated card. The status dot checks Ollama with
  a bounded `curl` against the API root rather than
  `sv status ollama` (a plain user always gets "access denied" on this runit install's
  `0700 root:root` supervise dirs, so the dot would read down forever otherwise), and the
  generate request is guarded with `--speed-limit 1 --speed-time 30` rather than a flat
  `--max-time`, so a slower model like `qwen2.5:3b` isn't killed mid-stream just for taking
  longer than 30s total to respond. The response area is a read-only `TextEdit`, so generated
  text can be selected and copied out with the mouse or keyboard. If it finds Ollama running
  with no models installed at all (a fresh setup), it auto-pulls the tiny fallback model
  (`qwen2.5:0.5b`) once, so there's something to talk to right away — the pull attempt itself
  doubles as the reachability check, so a missing daemon or network just surfaces as a failed
  download like any manual install would. A **Cancel** link next to the progress banner stops
  it (or any manual install) at any point.

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

- **Wallpaper picker**: one of `swww` (the script starts `swww-daemon` itself if it isn't
  already running), `swaybg`, or `feh`
- **Lockscreen**: PAM (`linux-pam`, already part of Void's base system) — no extra package
- **Session menu**: `elogind` (Void's non-systemd `loginctl`/`systemctl` provider — usually
  already pulled in by your desktop meta-package)
- **OSD power profile cycling**: `power-profiles-daemon` (`powerprofilesctl`)

## Installation

```sh
git clone https://github.com/dani-77/utumno ~/.config/quickshell/utumno
```

Or, system-wide via the included `Makefile` (installs to `/usr/share/quickshell/utumno`,
picked up by `qs -c utumno` same as the `~/.config` path):

```sh
sudo make install
# sudo make uninstall  to remove
```

**On Void Linux**, that same system-wide install is also packaged as a proper
`xbps-src` template — see [void/README.md](../void/README.md) to build it
yourself, or grab a pre-built binary from the
[`d77void/srcpkgs-d77`](https://github.com/d77void/srcpkgs-d77) repo (served
via its SourceForge repo, see that project's README).

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
├── ollamachat/
│   └── OllamaChat.qml      # chat popup for a local Ollama daemon
└── void/                   # Void Linux xbps-src packaging (see void/README.md)
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
