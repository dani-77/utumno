pragma Singleton
import QtQuick

// Paleta Tokyo Night — consistente com os teus outros projetos (fabric-d77 / quickshell-d77)
QtObject {
    readonly property color bg: "#1a1b26"
    readonly property color bgDark: "#16161e"
    readonly property color bgHighlight: "#292e42"
    readonly property color fg: "#c0caf5"
    readonly property color fgDark: "#a9b1d6"
    readonly property color comment: "#565f89"

    readonly property color blue: "#7aa2f7"
    readonly property color cyan: "#7dcfff"
    readonly property color green: "#9ece6a"
    readonly property color magenta: "#bb9af7"
    readonly property color orange: "#ff9e64"
    readonly property color red: "#f7768e"
    readonly property color yellow: "#e0af68"

    readonly property int radius: 10
    readonly property int barHeight: 32
    readonly property int gap: 8
}
