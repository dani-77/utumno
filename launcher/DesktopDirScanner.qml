// ══════════════════════════════════════════════════════
// DesktopDirScanner.qml
// Sweep the default directories and return the contents
// of these directories, concatenating all the .desktop fles.
// Ported from quickshell-d77.
// ══════════════════════════════════════════════════════
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: scanner

    // ── Signal emitted when the scan ends ──────────
    // raw: raw text with every .desktop file concatenated,
    //      separated by the ===DESKTOP_FILE_START=== delimiter
    signal scanned(string raw)

    // ── Directories searched (in order of priority) ──────
    property var dirs: [
        Quickshell.env("HOME") + "/.local/share/applications",
        "/usr/local/share/applications",
        "/usr/share/applications"
    ]

    // Indicates whether a scan is in progress.
    readonly property bool scanning: proc.running

    // ── Trigger the scan ───────────────────────────────
    function scan() {
        if (proc.running)
            return
        proc.command = ["sh", "-c", buildCommand()]
        proc.running = true
    }

    // ── Assembles the scan command ────────────────
    // For each existing directory, browse *.desktop and
    // prints a delimiter followed by the file content.
    function buildCommand() {
        var quoted = []
        for (var i = 0; i < dirs.length; i++)
            quoted.push("'" + String(dirs[i]).replace(/'/g, "'\\''") + "'")

        return "for d in " + quoted.join(" ") + "; do " +
               "[ -d \"$d\" ] || continue; " +
               "for f in \"$d\"/*.desktop; do " +
               "[ -f \"$f\" ] || continue; " +
               "printf '===DESKTOP_FILE_START===\\n'; " +
               "cat \"$f\"; printf '\\n'; " +
               "done; done"
    }

    // ── Scan process ──────────────────
    Process {
        id: proc
        running: false
        stdout: StdioCollector {
            onStreamFinished: scanner.scanned(text)
        }
    }
}
