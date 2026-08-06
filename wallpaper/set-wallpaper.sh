#!/usr/bin/env bash
# set-wallpaper.sh - Compositor-agnostic wallpaper tool for Quickshell
# Ported from quickshell-d77. niri has no dedicated branch here because it
# already falls through to the generic case (swww/swaybg/feh), same as any
# other non-Hyprland/Sway compositor. On Hyprland, the wallpaper daemon
# actually running (hyprpaper, swww, or swaybg) is auto-detected rather
# than assumed, since Hyprland itself doesn't draw wallpapers.

STATE_FILE="$HOME/.cache/quickshell/wallpaper/current"

detect_compositor() {
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        echo "hyprland"
    elif [ -n "$SWAYSOCK" ]; then
        echo "sway"
    else
        echo "generic"
    fi
}

detect_wallpaper_daemon() {
    if pgrep -x hyprpaper >/dev/null 2>&1; then
        echo "hyprpaper"
    elif pgrep -x swww-daemon >/dev/null 2>&1; then
        echo "swww"
    elif pgrep -x swaybg >/dev/null 2>&1; then
        echo "swaybg"
    else
        echo "none"
    fi
}

# Starts swww-daemon if it isn't already running, then waits for its socket
# to come up. Needed because `swww img` fails silently (non-zero exit, no
# wallpaper applied) if the daemon isn't up yet.
#
# --no-cache: by default swww-daemon restores each output's last wallpaper
# from its own cache right after starting. That restore runs asynchronously
# and races with the `swww img` call we make immediately after this
# function returns, so it can silently overwrite the wallpaper we just set.
# We always apply our own path right away, so the daemon's cache lookup is
# both unnecessary and actively harmful here.
ensure_swww_daemon() {
    if ! pgrep -x swww-daemon >/dev/null 2>&1; then
        swww-daemon --no-cache >/dev/null 2>&1 &
        disown
        local tries=0
        while [ $tries -lt 20 ]; do
            swww query >/dev/null 2>&1 && return 0
            sleep 0.1
            tries=$((tries + 1))
        done
    fi
}

apply_wallpaper_swww() {
    local path="$1"
    local mon="$2"
    ensure_swww_daemon
    if [ -n "$mon" ]; then
        swww img "$path" --outputs "$mon" --transition-type none >/dev/null 2>&1
    else
        swww img "$path" --transition-type none >/dev/null 2>&1
    fi
}

apply_wallpaper_swaybg() {
    local path="$1"
    pkill swaybg >/dev/null 2>&1
    swaybg -i "$path" -m fill >/dev/null 2>&1 &
    disown
}

detect_focused_monitor() {
    local comp=$(detect_compositor)
    if [ "$comp" = "hyprland" ]; then
        if command -v hyprctl >/dev/null 2>&1; then
            hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name' 2>/dev/null
        fi
    elif [ "$comp" = "sway" ]; then
        if command -v swaymsg >/dev/null 2>&1; then
            swaymsg -t get_outputs | jq -r '.[] | select(.focused==true) | .name' 2>/dev/null
        fi
    fi
}

apply_wallpaper() {
    local path="$1"
    local mon="$2"

    if [ -z "$path" ] || [ ! -f "$path" ]; then
        echo "Error: Invalid wallpaper path: $path" >&2
        exit 1
    fi

    # Save the path to state file for persistence
    mkdir -p "$(dirname "$STATE_FILE")"
    echo -n "$path" > "$STATE_FILE"

    local comp=$(detect_compositor)

    # If monitor is empty, try to detect the focused one
    if [ -z "$mon" ]; then
        mon=$(detect_focused_monitor)
    fi

    case "$comp" in
        hyprland)
            # Hyprland doesn't draw wallpapers itself, so which tool actually
            # owns the job varies per setup (hyprpaper, swww, swaybg). Detect
            # the daemon that's really running instead of assuming hyprpaper,
            # otherwise hyprctl calls below silently no-op when it isn't up.
            local daemon=$(detect_wallpaper_daemon)
            case "$daemon" in
                hyprpaper)
                    # If monitor is still empty, hyprpaper uses empty monitor (comma + path) to apply to all
                    local target_mon="$mon"
                    hyprctl hyprpaper wallpaper "$target_mon, $path" 2>/dev/null
                    if [ $? -ne 0 ]; then
                        hyprctl hyprpaper preload "$path" >/dev/null 2>&1
                        hyprctl hyprpaper wallpaper "$target_mon, $path" >/dev/null 2>&1
                    fi
                    ;;
                swww)
                    apply_wallpaper_swww "$path" "$mon"
                    ;;
                swaybg)
                    apply_wallpaper_swaybg "$path"
                    ;;
                *)
                    # No wallpaper daemon detected running yet - fall back to
                    # whichever tool is installed, preferring swww since it
                    # supports live IPC switching (swaybg needs a restart per
                    # change, hyprpaper needs preload/wallpaper IPC).
                    if command -v swww >/dev/null 2>&1; then
                        apply_wallpaper_swww "$path" "$mon"
                    elif command -v swaybg >/dev/null 2>&1; then
                        apply_wallpaper_swaybg "$path"
                    elif command -v hyprctl >/dev/null 2>&1; then
                        hyprctl hyprpaper preload "$path" >/dev/null 2>&1
                        hyprctl hyprpaper wallpaper "$mon, $path" >/dev/null 2>&1
                    fi
                    ;;
            esac
            ;;
        sway)
            if command -v swaymsg >/dev/null 2>&1; then
                if [ -z "$mon" ]; then
                    mon="*"
                fi
                swaymsg output "$mon" bg "$path" fill >/dev/null 2>&1
            fi
            ;;
        *)
            # Fallback to general tools like swww or feh if installed.
            # Routes through apply_wallpaper_swww (which calls
            # ensure_swww_daemon), not a bare `swww img` — otherwise this
            # races swww-daemon at session startup (autostart/exec-once
            # entries commonly get fired back-to-back with no ordering
            # guarantee between them) and silently no-ops, the same failure
            # mode already documented on ensure_swww_daemon above.
            if command -v swww >/dev/null 2>&1; then
                apply_wallpaper_swww "$path" "$mon"
            elif command -v swaybg >/dev/null 2>&1; then
                pkill swaybg
                swaybg -i "$path" -m fill >/dev/null 2>&1 &
            elif command -v feh >/dev/null 2>&1; then
                feh --bg-fill "$path"
            fi
            ;;
    esac
}

clear_wallpaper() {
    rm -f "$STATE_FILE"
    local comp=$(detect_compositor)
    case "$comp" in
        hyprland)
            local daemon=$(detect_wallpaper_daemon)
            case "$daemon" in
                hyprpaper)
                    hyprctl hyprpaper unload all >/dev/null 2>&1 || true
                    ;;
                swww)
                    swww clear >/dev/null 2>&1 || true
                    ;;
                swaybg)
                    pkill swaybg >/dev/null 2>&1 || true
                    ;;
            esac
            ;;
        sway)
            if command -v swaymsg >/dev/null 2>&1; then
                swaymsg output "*" bg "none" >/dev/null 2>&1 || true
            fi
            ;;
        *)
            if command -v swww >/dev/null 2>&1; then
                swww clear >/dev/null 2>&1 || true
            else
                pkill swaybg || true
            fi
            ;;
    esac
    return 0
}

startup() {
    if [ -f "$STATE_FILE" ]; then
        local path=$(cat "$STATE_FILE")
        if [ -f "$path" ]; then
            apply_wallpaper "$path" ""
        fi
    fi
}

COMMAND="$1"
shift

case "$COMMAND" in
    apply)
        apply_wallpaper "$@"
        ;;
    clear)
        clear_wallpaper
        ;;
    startup)
        startup
        ;;
    *)
        echo "Usage: $0 {apply <path> [monitor]|clear|startup}" >&2
        exit 1
        ;;
esac
