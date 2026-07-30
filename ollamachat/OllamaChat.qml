// ══════════════════════════════════════════════════════
// OllamaChat.qml
// Native chat popup for a locally running Ollama daemon
// (http://127.0.0.1:11434), talked to via curl (no HTTP/JS
// client libraries needed). Streams the generated response
// as it arrives, lets you switch between installed models
// or pull a new one ("+ instalar novo modelo...") with live
// progress, and remembers the last picked model at
// ~/.config/ollama-chat/model.conf.
// Ported from quickshell-d77.
//
// Mirrors Launcher.qml's window/field pattern: PanelWindow
// overlay, custom Rectangle+TextInput fields (no
// QtQuick.Controls, to stay consistent with the rest of the
// shell), Tokyo Night palette from config/Colors.qml.
// Opened from the bar's "AI" button or via IPC.
// ══════════════════════════════════════════════════════
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../config" as Cfg

PanelWindow {
    id: chat

    // ══════════════════════════════════════════════════════
    // THEME (Tokyo Night, from config/Colors.qml)
    // ══════════════════════════════════════════════════════
    property color colBg:     Cfg.Colors.bg
    property color colFg:     Cfg.Colors.fgDark
    property color colMuted:  Cfg.Colors.muted
    property color colCyan:   Cfg.Colors.cyanAccent
    property color colBlue:   Cfg.Colors.blue
    property color colGreen:  Cfg.Colors.green
    property color colRed:    Cfg.Colors.red
    property color colPurple: Cfg.Colors.magenta
    property string font:     Cfg.Colors.font
    property int    fsize:    Cfg.Colors.fsize

    // ══════════════════════════════════════════════════════
    // CONFIG
    // ══════════════════════════════════════════════════════
    readonly property string fallbackModel:   "qwen2.5:0.5b"
    readonly property string installSentinel: "+ instalar novo modelo..."
    property string configPath: Quickshell.env("HOME") + "/.config/ollama-chat/model.conf"

    // ══════════════════════════════════════════════════════
    // STATE
    // ══════════════════════════════════════════════════════
    property string model:          fallbackModel
    property string savedModel:     ""
    property string history:        ""
    property bool   ollamaUp:       false
    property bool   modelsLoaded:   false
    property bool   installing:     false
    property var    availableModels: [fallbackModel]
    property string infoText:       ""   // empty = shows nothing
    property bool   modelMenuOpen:  false

    // Shell-quotes a string for safe interpolation inside a single-quoted
    // sh argument. Model names can come from user-typed input
    // (installField), so this can't be skipped without risking command
    // injection when a name contains a quote or shell metacharacters.
    function _shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // ── Public API ───────────────────────────────────────
    function open() {
        visible = true
        input.forceActiveFocus()
    }
    function hide() {
        modelMenuOpen        = false
        installField.visible = false
        visible = false
    }
    // Alias for IPC API (toggle/open/close).
    function close() {
        hide()
    }
    function toggle() {
        if (visible) hide()
        else         open()
    }

    Component.onCompleted: loadModelProc.running = true

    // ══════════════════════════════════════════════════════
    // LAYER SHELL WINDOW
    // ══════════════════════════════════════════════════════
    visible: false
    color: "transparent"

    implicitWidth:  560
    implicitHeight: 620

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace:     "utumno-ollamachat"

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        MouseArea {
            anchors.fill: parent
            onClicked: chat.hide()
        }
    }

    // ══════════════════════════════════════════════════════
    // CHAT BOX
    // ══════════════════════════════════════════════════════
    Rectangle {
        id: box
        anchors.centerIn: parent
        width:  parent.width
        height: parent.height
        radius: 12
        color: chat.colBg
        border.color: chat.colPurple
        border.width: 2

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 14
            spacing: 8

            // ── Header ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: chat.ollamaUp ? chat.colGreen : chat.colRed
                }
                Text {
                    text: "Ollama"
                    font.family: chat.font
                    font.pixelSize: chat.fsize + 3
                    font.bold: true
                    color: chat.colFg
                }

                Item { Layout.fillWidth: true }

                // ── Model picker (custom combo) ───────────
                Rectangle {
                    id: modelButton
                    implicitWidth:  Math.min(220, modelRow.implicitWidth + 20)
                    implicitHeight: 30
                    radius: 6
                    color: Qt.darker(chat.colBg, 1.3)
                    border.width: 1
                    border.color: chat.modelMenuOpen ? chat.colPurple : chat.colMuted

                    RowLayout {
                        id: modelRow
                        anchors.fill: parent
                        anchors.leftMargin:  10
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: chat.model
                            elide: Text.ElideRight
                            font.family: chat.font
                            font.pixelSize: chat.fsize - 1
                            color: chat.colFg
                        }
                        Text {
                            text: chat.modelMenuOpen ? "▲" : "▼"
                            font.family: chat.font
                            font.pixelSize: chat.fsize - 3
                            color: chat.colMuted
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !chat.installing
                        cursorShape: Qt.PointingHandCursor
                        onClicked: chat.modelMenuOpen = !chat.modelMenuOpen
                    }
                }
            }

            // ── Model dropdown list ───────────────────────
            Rectangle {
                id: modelMenu
                visible: chat.modelMenuOpen
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(160, modelList.contentHeight + 8)
                radius: 8
                color: Qt.darker(chat.colBg, 1.3)
                border.width: 1
                border.color: chat.colMuted
                clip: true

                ListView {
                    id: modelList
                    anchors.fill:    parent
                    anchors.margins: 4
                    model: chat.availableModels.concat([chat.installSentinel])
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        width:  modelList.width
                        height: 28
                        radius: 6
                        color: itemMa.containsMouse ? Qt.rgba(0.73, 0.60, 0.97, 0.18) : "transparent"

                        Text {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            text: modelData
                            font.family: chat.font
                            font.pixelSize: chat.fsize - 1
                            color: modelData === chat.installSentinel ? chat.colCyan : chat.colFg
                        }

                        MouseArea {
                            id: itemMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                chat.modelMenuOpen = false
                                if (modelData === chat.installSentinel) {
                                    installField.visible = true
                                    installInput.forceActiveFocus()
                                    return
                                }
                                chat.model    = modelData
                                chat.infoText = ""
                                saveModelProc.command = ["sh", "-c",
                                    "mkdir -p \"$(dirname " + chat._shq(chat.configPath) + ")\" && printf '%s' " +
                                    chat._shq(chat.model) + " > " + chat._shq(chat.configPath)]
                                saveModelProc.running = true
                            }
                        }
                    }
                }
            }

            // ── Install new model field ───────────────────
            Rectangle {
                id: installField
                visible: false
                Layout.fillWidth: true
                height: 36
                radius: 8
                color: Qt.darker(chat.colBg, 1.3)
                border.width: 1
                border.color: installInput.activeFocus ? chat.colPurple : chat.colMuted

                TextInput {
                    id: installInput
                    anchors.fill: parent
                    anchors.leftMargin:  10
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: chat.colFg
                    font.family: chat.font
                    font.pixelSize: chat.fsize
                    selectionColor: chat.colPurple
                    selectByMouse: true

                    Keys.onEscapePressed: {
                        installField.visible = false
                        text = ""
                    }
                    onAccepted: {
                        var name = text.trim()
                        installField.visible = false
                        text = ""
                        if (name.length === 0) return
                        chat.installing = true
                        chat.infoText   = "A instalar '" + name + "'..."
                        pullProc.modelName = name
                        pullProc.buffer     = ""
                        pullProc.command = ["curl", "-s", "-N", "-X", "POST",
                            "http://127.0.0.1:11434/api/pull",
                            "-d", JSON.stringify({name: name, stream: true})]
                        pullProc.running = true
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: installInput.text === ""
                        text: "nome-do-modelo:tag (ex: llama3.2:3b)"
                        font: installInput.font
                        color: chat.colMuted
                    }
                }
            }

            // ── Info / progress banner ────────────────────
            Text {
                Layout.fillWidth: true
                visible: chat.infoText.length > 0
                text: chat.infoText
                wrapMode: Text.WordWrap
                font.family: chat.font
                font.italic: true
                font.pixelSize: chat.fsize - 1
                color: chat.colBlue
            }

            // ── History ────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 8
                color: Qt.darker(chat.colBg, 1.2)
                border.width: 1
                border.color: chat.colMuted
                clip: true

                Flickable {
                    id: historyFlick
                    anchors.fill:    parent
                    anchors.margins: 10
                    clip: true
                    contentWidth:  width
                    contentHeight: historyText.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    // Keeps the newest output in view as the model streams.
                    onContentHeightChanged: contentY = Math.max(0, contentHeight - height)

                    Text {
                        id: historyText
                        width: historyFlick.width
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        text: chat.history
                        font.family: chat.font
                        font.pixelSize: chat.fsize
                        color: chat.colFg
                    }
                }
            }

            // ── Prompt field ───────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 8
                color: Qt.darker(chat.colBg, 1.3)
                border.width: 1
                border.color: input.activeFocus ? chat.colPurple : chat.colMuted

                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin:  12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: chat.colFg
                    font.family: chat.font
                    font.pixelSize: chat.fsize + 1
                    selectionColor: chat.colPurple
                    selectByMouse: true

                    Keys.onEscapePressed: chat.hide()
                    onAccepted: {
                        var q = text.trim()
                        if (q.length === 0) return
                        chat.history += "\n> " + q + "\n"
                        proc.errorBuffer  = ""
                        proc.gotAnyOutput = false
                        proc.command = ["curl", "-s", "-N", "--max-time", "30",
                            "http://127.0.0.1:11434/api/generate",
                            "-d", JSON.stringify({model: chat.model, prompt: q, stream: true})]
                        proc.running = true
                        text = ""
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: input.text === ""
                        text: "Pergunta à IA..."
                        font: input.font
                        color: chat.colMuted
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════
    // PROCESSES
    // ══════════════════════════════════════════════════════

    // --- Carrega o modelo guardado ---
    Process {
        id: loadModelProc
        command: ["sh", "-c", "cat " + chat._shq(chat.configPath) + " 2>/dev/null || true"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim().length > 0) chat.savedModel = line.trim()
            }
        }
        onExited: () => { modelsProc.running = true }
    }

    Process { id: saveModelProc }

    // --- Lista de modelos instalados ---
    Timer {
        id: modelsRetryTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: modelsProc.running = true
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: { if (!chat.installing) modelsProc.running = true }
    }

    Process {
        id: modelsProc
        command: ["curl", "-s", "--max-time", "5", "http://127.0.0.1:11434/api/tags"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: (line) => { modelsProc.buffer += line }
        }
        onExited: (exitCode) => {
            if (chat.installing) { modelsProc.buffer = ""; return }
            if (exitCode === 0 && modelsProc.buffer.length > 0) {
                try {
                    var data  = JSON.parse(modelsProc.buffer)
                    var names = (data.models || []).map(m => m.name)
                    if (names.length === 0) names = [chat.fallbackModel]
                    chat.modelsLoaded    = true
                    chat.availableModels = names

                    var chosen
                    if (names.indexOf(chat.savedModel) !== -1) {
                        chosen = chat.savedModel
                    } else if (names.indexOf(chat.fallbackModel) !== -1) {
                        chosen = chat.fallbackModel
                    } else {
                        chosen = names[0]
                    }
                    chat.model = chosen
                } catch (e) {
                    modelsRetryTimer.start()
                }
            } else {
                modelsRetryTimer.start()
            }
            modelsProc.buffer = ""
        }
    }

    // --- Instalação de novo modelo (com progresso) ---
    Process {
        id: pullProc
        property string modelName: ""
        property string buffer: ""

        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var chunk = JSON.parse(line)
                    if (chunk.error) {
                        chat.infoText = "Erro a instalar '" + pullProc.modelName + "': " + chunk.error
                        return
                    }
                    var status = chunk.status || ""
                    if (chunk.total && chunk.completed) {
                        var pct = Math.round((chunk.completed / chunk.total) * 100)
                        chat.infoText = "A instalar '" + pullProc.modelName + "': " + status + " (" + pct + "%)"
                    } else {
                        chat.infoText = "A instalar '" + pullProc.modelName + "': " + status
                    }
                } catch (e) {}
            }
        }

        onExited: (exitCode) => {
            chat.installing = false
            if (exitCode === 0) {
                chat.infoText   = "'" + pullProc.modelName + "' instalado com sucesso."
                chat.savedModel = pullProc.modelName
                infoClearTimer.start()
                modelsProc.running = true
            } else {
                chat.infoText = "Falha ao instalar '" + pullProc.modelName + "' (curl código " + exitCode + ")"
            }
        }
    }

    Timer {
        id: infoClearTimer
        interval: 6000
        running: false
        repeat: false
        onTriggered: chat.infoText = ""
    }

    // --- Status do serviço ---
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }

    Process {
        id: statusProc
        command: ["sv", "status", "ollama"]
        stdout: SplitParser {
            onRead: (line) => {
                var wasDown = !chat.ollamaUp
                chat.ollamaUp = line.trim().startsWith("run:")
                if (wasDown && chat.ollamaUp && !chat.modelsLoaded) {
                    modelsProc.running = true
                }
            }
        }
        onExited: (exitCode) => { if (exitCode !== 0) chat.ollamaUp = false }
    }

    Process {
        id: proc
        property string errorBuffer:  ""
        property bool   gotAnyOutput: false

        stdout: SplitParser {
            onRead: (line) => {
                proc.gotAnyOutput = true
                try {
                    var chunk = JSON.parse(line)
                    if (chunk.error) {
                        chat.history += "\n[erro do modelo: " + chunk.error + "]\n"
                    } else {
                        chat.history += chunk.response || ""
                    }
                } catch (e) {}
            }
        }
        stderr: SplitParser {
            onRead: (line) => { proc.errorBuffer += line + "\n" }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || !proc.gotAnyOutput) {
                if (proc.errorBuffer.includes("Connection refused") || exitCode === 7) {
                    chat.history += "\n[Ollama não está a correr. Verifica com: sv status ollama]\n"
                } else if (exitCode === 28) {
                    chat.history += "\n[Ollama demorou demasiado a responder — timeout]\n"
                } else if (!proc.gotAnyOutput) {
                    chat.history += "\n[sem resposta do Ollama — código curl: " + exitCode + "]\n"
                }
            }
        }
    }
}
