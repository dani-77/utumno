import QtQuick
import Quickshell
import Quickshell.Io
import "modules" as Modules

ShellRoot {
    id: root

    Modules.Bar {}

    IpcHandler {
        target: "helium"

        function reload(): void {
            Qt.callLater(() => Quickshell.reload(true));
        }

        function toggle(): void {
            // placeholder para futuros popups (launcher, control center...)
        }
    }
}
