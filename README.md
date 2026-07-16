# helium-d77

A minimal QML/Quickshell desktop shell for Hyprland, in the same spirit as
[`fabric-d77`](https://github.com/dani-77/fabric-d77) and
[`quickshell-d77`](https://github.com/dani-77/quickshell-d77) — Tokyo Night theme,
lean tooling, terminal-first workflow.

## Current state

Functional starting point: a top bar (`Bar.qml`) with a clock, SSID/network status,
and battery indicator, plus an `IpcHandler` (`helium`) exposing a `reload` command.

## Dependencies (Void Linux)

```sh
sudo xbps-install quickshell hyprland qt6-base qt6-declarative qt6-svg \
    qt6-shadertools pipewire wireplumber upower NetworkManager polkit brightnessctl
```

## Installation

```sh
git clone https://github.com/dani-77/helium-d77 ~/.config/quickshell/helium-d77
```

Add to your `hyprland.conf`:

```
exec-once = qs -c helium-d77
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
│   ├── Bar.qml           # PanelWindow (WlrLayer.Top)
│   ├── Clock.qml
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
