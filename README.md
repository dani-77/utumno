# helium-d77

A minimal QML/Quickshell desktop shell for [niri](https://github.com/YaLTeR/niri), in the
same spirit as [`fabric-d77`](https://github.com/dani-77/fabric-d77) and
[`quickshell-d77`](https://github.com/dani-77/quickshell-d77) — Tokyo Night theme,
lean tooling, terminal-first workflow.

## Current state

Functional floating top bar (`Bar.qml`, rounded corners, gap from screen edges) with:

- `Workspaces.qml` — niri workspaces via the compositor-agnostic
  `Quickshell.WindowManager` (`ext-workspace-v1`) module, click to switch
- `Clock.qml`
- `Cpu.qml` / `Ram.qml` — usage % polled from `/proc/stat` / `/proc/meminfo`
- `Volume.qml` — ALSA volume/mute via `amixer` (this setup runs plain PulseAudio,
  not PipeWire, so volume is read through ALSA rather than
  `Quickshell.Services.Pipewire`)
- `Network.qml` — SSID + signal quality via `Quickshell.Networking`
- `Battery.qml` — icon and % via `UPower.displayDevice`

Plus an `IpcHandler` (`helium`) exposing a `reload` command.

## Dependencies (Void Linux)

```sh
sudo xbps-install quickshell niri qt6-base qt6-declarative qt6-svg \
    qt6-shadertools alsa-utils upower NetworkManager polkit brightnessctl
```

## Installation

```sh
git clone https://github.com/dani-77/helium-d77 ~/.config/quickshell/helium-d77
```

Add to your niri `config.kdl`:

```kdl
spawn-at-startup "qs" "-c" "helium-d77"
```

To test without installing into `~/.config/quickshell/` first:

```sh
qs -c helium-d77 -p /path/to/helium-d77
```

## Structure

```
helium-d77/
├── shell.qml            # entry point, IpcHandler
├── modules/
│   ├── Bar.qml           # PanelWindow (WlrLayer.Top), floating + rounded
│   ├── Workspaces.qml    # niri workspaces via Quickshell.WindowManager
│   ├── Clock.qml
│   ├── Cpu.qml           # /proc/stat polling
│   ├── Ram.qml           # /proc/meminfo polling
│   ├── Volume.qml        # amixer (ALSA)
│   ├── Network.qml       # SSID via Quickshell.Networking
│   └── Battery.qml       # via UPower.displayDevice
└── config/
    └── Colors.qml        # Tokyo Night singleton
```

## IPC

```sh
qs -c helium-d77 ipc call helium reload
```

## Roadmap

- [ ] Wallpaper picker (as in `quickshell-d77`)
- [ ] Launcher / app grid
- [ ] Control center (volume, brightness, network toggles)
- [ ] Notifications (`Quickshell.Services.Notifications`)
- [ ] Lock screen via `ext-session-lock-v1`

## License

MIT (or update to match your other repos).
