// ══════════════════════════════════════════════════════
// Lockscreen.qml
// Main component of the lockscreen module. Encapsulates the
// WlSessionLock + LockContext and exposes a public API
// (lock/unlock/toggle) ready to be IPC connected.
//
// Usage in shell.qml:
//   import "lockscreen"
//   Lockscreen { id: lockScreen }
//   lockScreen.lock()    // lock the screen
//   lockScreen.unlock()  // unlock (no password)
//
// Ported from quickshell-d77.
// ══════════════════════════════════════════════════════
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../config" as Cfg

Scope {
    id: root

    // ══════════════════════════════════════════════════════
    // THEME (Tokyo Night, from config/Colors.qml)
    // ══════════════════════════════════════════════════════
    property color colBg:     Cfg.Colors.bg
    property color colFg:     Cfg.Colors.fgDark
    property color colMuted:  Cfg.Colors.muted
    property color colBlue:   Cfg.Colors.blue
    property color colPurple: Cfg.Colors.magenta
    property color colRed:    Cfg.Colors.red
    property string font:     Cfg.Colors.font
    property int    fsize:    Cfg.Colors.fsize

    // ── State ────────────────────────────────────────────
    // true while screen is locked.
    readonly property alias locked: lock.locked

    // ── Signals ────────────────────────────────────────────
    // Emitted when the lock state changes.
    signal didLock()
    signal didUnlock()

    // ══════════════════════════════════════════════════════
    // Public API (via IPC)
    // ══════════════════════════════════════════════════════
    // Lock the screen. Session locked until the password
    // is validated via PAM (or unlock() if called).
    function lock() {
        if (lock.locked) return
        lockContext.currentText      = ""
        lockContext.showFailure      = false
        lockContext.unlockInProgress = false
        lock.locked = true
        root.didLock()
    }

    // Unlock the screen, without password.
    function unlock() {
        if (!lock.locked) return
        lock.locked = false
        lockContext.currentText      = ""
        lockContext.showFailure      = false
        lockContext.unlockInProgress = false
        root.didUnlock()
    }

    // Alternates between locked/unlocked.
    function toggle() {
        if (lock.locked) unlock()
        else             lock()
    }

    // ══════════════════════════════════════════════════════
    // SHARED CONTEXT + AUTHENTICATION
    // ══════════════════════════════════════════════════════
    LockContext {
        id: lockContext

        onUnlocked: {
            lock.locked = false
            root.didUnlock()
        }
    }

    // ══════════════════════════════════════════════════════
    // LOCKED SESSION
    // ══════════════════════════════════════════════════════
    WlSessionLock {
        id: lock
        locked: false

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: lockContext

                // THEME
                colBg:     root.colBg
                colFg:     root.colFg
                colMuted:  root.colMuted
                colBlue:   root.colBlue
                colPurple: root.colPurple
                colRed:    root.colRed
                font:      root.font
                fsize:     root.fsize
            }
        }
    }
}
