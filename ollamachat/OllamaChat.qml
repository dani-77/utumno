// ══════════════════════════════════════════════════════
// OllamaChat.qml
// Native chat popup for a locally running Ollama daemon
// (http://127.0.0.1:11434), talked to via curl (no HTTP/JS
// client libraries needed). Streams the generated response
// as it arrives, lets you switch between installed models
// or pull a new one ("+ install new model...") with live
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
    readonly property string installSentinel: "+ install new model..."
    // Without this, /api/generate falls back to Ollama's server-side
    // default (5 min), which keeps the model resident and consuming
    // RAM/CPU long after you've stopped chatting. "0" unloads it the
    // instant a response finishes, so it's only ever loaded on demand.
    readonly property string keepAlive:       "0"
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
    // Set once we've decided whether to auto-pull the fallback model on a
    // fresh Ollama with nothing installed, so it's only ever offered once
    // per popup lifetime — not retried on every 15s models poll.
    property bool   _autoPullOffered: false
    property var    availableModels: [fallbackModel]
    property string infoText:       ""   // empty = shows nothing
    property bool   modelMenuOpen:  false
    // Hardware auto-detection (GPU/RAM) — used to suggest a model-size
    // tier appropriate for this machine. Detected once at startup since
    // hardware doesn't change while the shell is running.
    property string hwSummary:      ""   // e.g. "GPU NVIDIA RTX 3080 (12 GB VRAM)"
    property string suggestedLabel: ""   // e.g. "7b – 8b"
    property var    suggestedSizes: []   // e.g. [7, 8] — numeric B-param sizes
    // True right before a models refresh that should (re)pick `model` from
    // savedModel/fallback/first — the very first load, and right after a
    // successful install (see pullProc.onExited). Left false the rest of
    // the time, so the plain 15s refresh tick only updates availableModels
    // and never silently reverts a manual dropdown pick back to
    // savedModel a few seconds after making it.
    property bool   _selectPending: true

    // Shell-quotes a string for safe interpolation inside a single-quoted
    // sh argument. Model names can come from user-typed input
    // (installField), so this can't be skipped without risking command
    // injection when a name contains a quote or shell metacharacters.
    function _shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    // Picks a suggested B-param range from detected VRAM/RAM. Integrated
    // graphics (or no GPU at all) run inference on the CPU sharing system
    // RAM, so it gets a more conservative ladder than a dedicated GPU with
    // the same amount of memory.
    function _suggestSizes(hw) {
        var gb = (hw.vram_mb || hw.ram_mb || 0) / 1024
        var dedicated = hw.gpu === "nvidia" || hw.gpu === "amd" || hw.gpu === "dedicated"
        if (!dedicated) {
            if (gb <= 4)  return [0.5, 1]
            if (gb <= 8)  return [1, 3]
            if (gb <= 16) return [3, 7]
            return [7, 8]
        }
        if (gb <= 4)  return [1, 3]
        if (gb <= 6)  return [3, 7]
        if (gb <= 8)  return [7]
        if (gb <= 12) return [7, 8]
        if (gb <= 16) return [13, 14]
        if (gb <= 24) return [14, 32]
        if (gb <= 48) return [32]
        return [70]
    }

    // Applies a parsed hwDetectProc result to hwSummary/suggestedLabel/sizes.
    function applyHwInfo(hw) {
        var gb = (hw.vram_mb || hw.ram_mb || 0) / 1024
        if (hw.gpu === "nvidia" || hw.gpu === "amd") {
            hwSummary = "GPU " + (hw.gpu === "nvidia" ? "NVIDIA" : "AMD") + " " + hw.name +
                        " (" + Math.round(gb) + " GB VRAM)"
        } else if (hw.gpu === "dedicated") {
            hwSummary = "Dedicated GPU: " + hw.name
        } else {
            hwSummary = "No dedicated GPU detected — " + Math.round(gb) + " GB RAM"
        }
        suggestedSizes = _suggestSizes(hw)
        suggestedLabel = suggestedSizes.map(s => (s % 1 === 0 ? s : s.toFixed(1)) + "b").join(" – ")
    }

    // True when a model's tag names a param size close to what was
    // suggested for this machine (within ±35%), so the picker can flag it.
    function isRecommended(name) {
        if (suggestedSizes.length === 0) return false
        var m = /(\d+(?:\.\d+)?)\s*b(?!\w)/i.exec(name)
        if (!m) return false
        var size = parseFloat(m[1])
        for (var i = 0; i < suggestedSizes.length; i++) {
            var target = suggestedSizes[i]
            if (Math.abs(size - target) <= target * 0.35) return true
        }
        return false
    }

    // Kicks off a pull of the fallback model without any user input — used
    // when a fresh Ollama install has nothing to select. Shares pullProc
    // with the manual "+ install new model..." flow, so progress reporting
    // and cancellation behave identically either way.
    function startAutoPull() {
        installing = true
        infoText   = "No models installed — auto-downloading '" + fallbackModel + "'. Click Cancel to stop."
        pullProc.modelName = fallbackModel
        pullProc.buffer     = ""
        pullProc.cancelled  = false
        pullProc.command = ["curl", "-s", "-N", "-X", "POST",
            "http://127.0.0.1:11434/api/pull",
            "-d", JSON.stringify({name: fallbackModel, stream: true})]
        pullProc.running = true
    }

    // Stops whichever pull (automatic or manual) is currently running.
    // Setting Process.running to false sends SIGTERM; pullProc.onExited
    // checks the cancelled flag to report it distinctly from a failure.
    function cancelInstall() {
        if (!installing) return
        pullProc.cancelled = true
        pullProc.running   = false
    }

    // Stops a response mid-stream, same SIGTERM approach as cancelInstall.
    function stopGeneration() {
        if (!proc.running) return
        proc.cancelled = true
        proc.running   = false
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

    Component.onCompleted: {
        loadModelProc.running = true
        hwDetectProc.running  = true
    }

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

            // ── Hardware / suggested model size ───────────
            Text {
                Layout.fillWidth: true
                visible: chat.hwSummary.length > 0
                text: chat.hwSummary +
                      (chat.suggestedLabel.length > 0 ? "  ·  suggested models: " + chat.suggestedLabel : "")
                elide: Text.ElideRight
                font.family: chat.font
                font.pixelSize: chat.fsize - 2
                color: chat.colMuted
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
                            text: (modelData !== chat.installSentinel && chat.isRecommended(modelData) ? "★ " : "") + modelData
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
                        chat.infoText   = "Installing '" + name + "'..."
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
                        text: chat.suggestedLabel.length > 0
                              ? "model-name:tag (suggested for this machine: " + chat.suggestedLabel + ")"
                              : "model-name:tag (e.g. llama3.2:3b)"
                        elide: Text.ElideRight
                        width: parent.width
                        font: installInput.font
                        color: chat.colMuted
                    }
                }
            }

            // ── Info / progress banner ────────────────────
            RowLayout {
                Layout.fillWidth: true
                visible: chat.infoText.length > 0
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: chat.infoText
                    wrapMode: Text.WordWrap
                    font.family: chat.font
                    font.italic: true
                    font.pixelSize: chat.fsize - 1
                    color: chat.colBlue
                }

                Text {
                    visible: chat.installing
                    text: "Cancel"
                    font.family: chat.font
                    font.underline: true
                    font.pixelSize: chat.fsize - 1
                    color: chat.colRed

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: chat.cancelInstall()
                    }
                }
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

                    TextEdit {
                        id: historyText
                        width: historyFlick.width
                        wrapMode: TextEdit.WordWrap
                        textFormat: TextEdit.PlainText
                        text: chat.history
                        font.family: chat.font
                        font.pixelSize: chat.fsize
                        color: chat.colFg
                        readOnly: true
                        selectByMouse: true
                        selectByKeyboard: true
                        persistentSelection: true
                        selectionColor: chat.colPurple

                        Keys.onEscapePressed: chat.hide()
                    }
                }
            }

            // ── Prompt field ───────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

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

                        Keys.onEscapePressed: {
                            if (proc.running) chat.stopGeneration()
                            else              chat.hide()
                        }
                        onAccepted: {
                            var q = text.trim()
                            if (q.length === 0 || proc.running) return
                            chat.history += "\n> " + q + "\n"
                            proc.errorBuffer  = ""
                            proc.gotAnyOutput = false
                            proc.cancelled    = false
                            // --speed-limit/--speed-time abort only on a genuine
                            // 30s stall (no bytes at all), unlike a flat
                            // --max-time which would also kill a slower model
                            // (e.g. qwen2.5:3b) mid-stream just for taking
                            // longer than 30s in total to finish generating.
                            proc.command = ["curl", "-s", "-N", "--speed-limit", "1", "--speed-time", "30",
                                "http://127.0.0.1:11434/api/generate",
                                "-d", JSON.stringify({model: chat.model, prompt: q, stream: true, keep_alive: chat.keepAlive})]
                            proc.running = true
                            text = ""
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: input.text === ""
                            text: proc.running ? "Generating... (Esc to stop)" : "Ask the AI..."
                            font: input.font
                            color: chat.colMuted
                        }
                    }
                }

                // ── Stop button ─────────────────────────────
                Rectangle {
                    visible: proc.running
                    implicitWidth: 64
                    implicitHeight: 40
                    radius: 8
                    color: stopMa.containsMouse ? Qt.rgba(0.94, 0.33, 0.31, 0.25) : Qt.darker(chat.colBg, 1.3)
                    border.width: 1
                    border.color: chat.colRed

                    Text {
                        anchors.centerIn: parent
                        text: "Stop"
                        font.family: chat.font
                        font.pixelSize: chat.fsize
                        color: chat.colRed
                    }

                    MouseArea {
                        id: stopMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: chat.stopGeneration()
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════
    // PROCESSES
    // ══════════════════════════════════════════════════════

    // --- Load the saved model ---
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

    // --- Hardware detection (dedicated GPU / RAM) ---
    // Runs once at startup: prefers nvidia-smi (exact VRAM), falls back to
    // rocm-smi for AMD, then lspci just to notice a dedicated GPU exists
    // (no VRAM figure available that way), and finally total system RAM
    // when there's no dedicated GPU at all (CPU inference shares it).
    Process {
        id: hwDetectProc
        property string buffer: ""
        command: ["sh", "-c", `
            if command -v nvidia-smi >/dev/null 2>&1; then
                info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
                if [ -n "$info" ]; then
                    name=$(printf '%s' "$info" | cut -d',' -f1 | sed 's/^ *//;s/ *$//;s/["\\\\]/ /g')
                    vram=$(printf '%s' "$info" | cut -d',' -f2 | tr -dc '0-9')
                    printf '{"gpu":"nvidia","name":"%s","vram_mb":%s}' "$name" "$vram"
                    exit 0
                fi
            fi
            if command -v rocm-smi >/dev/null 2>&1; then
                vram_b=$(rocm-smi --showmeminfo vram --csv 2>/dev/null | tail -1 | cut -d',' -f2 | tr -dc '0-9')
                if [ -n "$vram_b" ]; then
                    printf '{"gpu":"amd","name":"AMD GPU","vram_mb":%s}' "$((vram_b/1024/1024))"
                    exit 0
                fi
            fi
            if command -v lspci >/dev/null 2>&1; then
                gpu_line=$(lspci | grep -Ei 'vga compatible|3d controller' | grep -Ei 'nvidia|amd|radeon|geforce|rtx|quadro|arc a[0-9]' | head -1)
                if [ -n "$gpu_line" ]; then
                    name=$(printf '%s' "$gpu_line" | sed 's/^[^:]*: //;s/["\\\\]/ /g')
                    printf '{"gpu":"dedicated","name":"%s"}' "$name"
                    exit 0
                fi
            fi
            ram_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
            printf '{"gpu":"none","ram_mb":%s}' "$ram_mb"
        `]
        stdout: SplitParser {
            onRead: (line) => { hwDetectProc.buffer += line }
        }
        onExited: () => {
            try {
                chat.applyHwInfo(JSON.parse(hwDetectProc.buffer))
            } catch (e) {}
            hwDetectProc.buffer = ""
        }
    }

    // --- List of installed models ---
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
                    var data      = JSON.parse(modelsProc.buffer)
                    var realNames = (data.models || []).map(m => m.name)
                    var names     = realNames.length === 0 ? [chat.fallbackModel] : realNames
                    chat.modelsLoaded    = true
                    chat.availableModels = names

                    if (chat._selectPending) {
                        var chosen
                        if (names.indexOf(chat.savedModel) !== -1) {
                            chosen = chat.savedModel
                        } else if (names.indexOf(chat.fallbackModel) !== -1) {
                            chosen = chat.fallbackModel
                        } else {
                            chosen = names[0]
                        }
                        chat.model = chosen
                        chat._selectPending = false
                    }

                    // Fresh Ollama, nothing installed yet: auto-pull the
                    // fallback model once so there's something to talk to
                    // without the user having to know to type a model name.
                    if (realNames.length === 0 && !chat._autoPullOffered) {
                        chat._autoPullOffered = true
                        chat.startAutoPull()
                    }
                } catch (e) {
                    modelsRetryTimer.start()
                }
            } else {
                modelsRetryTimer.start()
            }
            modelsProc.buffer = ""
        }
    }

    // --- Installing a new model (with progress) ---
    Process {
        id: pullProc
        property string modelName: ""
        property string buffer: ""
        // Set right before running is dropped to false from cancelInstall(),
        // so onExited can tell a user-requested stop from a real failure.
        property bool   cancelled: false

        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var chunk = JSON.parse(line)
                    if (chunk.error) {
                        chat.infoText = "Error installing '" + pullProc.modelName + "': " + chunk.error
                        return
                    }
                    var status = chunk.status || ""
                    if (chunk.total && chunk.completed) {
                        var pct = Math.round((chunk.completed / chunk.total) * 100)
                        chat.infoText = "Installing '" + pullProc.modelName + "': " + status + " (" + pct + "%)"
                    } else {
                        chat.infoText = "Installing '" + pullProc.modelName + "': " + status
                    }
                } catch (e) {}
            }
        }

        onExited: (exitCode) => {
            chat.installing = false
            if (pullProc.cancelled) {
                chat.infoText     = "Cancelled installing '" + pullProc.modelName + "'."
                pullProc.cancelled = false
                infoClearTimer.start()
            } else if (exitCode === 0) {
                chat.infoText   = "'" + pullProc.modelName + "' installed successfully."
                chat.savedModel = pullProc.modelName
                chat._selectPending = true
                infoClearTimer.start()
                modelsProc.running = true
            } else {
                chat.infoText = "Failed to install '" + pullProc.modelName + "' (curl exit code " + exitCode + ")"
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

    // --- Service status ---
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statusProc.running = true
    }

    // "sv status ollama" would need root — runit's supervise dirs are
    // 0700 root:root on this system (true for every service, not just
    // ollama), so a plain user always gets "access denied" and the
    // indicator would read down forever. Hitting the API directly both
    // sidesteps that and is the more meaningful check anyway: it confirms
    // ollama is actually serving requests, not just that a process exists.
    Process {
        id: statusProc
        command: ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "2",
            "http://127.0.0.1:11434/"]
        property string buffer: ""
        stdout: SplitParser {
            onRead: (line) => { statusProc.buffer += line }
        }
        onExited: (exitCode) => {
            var wasDown = !chat.ollamaUp
            chat.ollamaUp = exitCode === 0 && statusProc.buffer.trim() === "200"
            if (wasDown && chat.ollamaUp && !chat.modelsLoaded) {
                modelsProc.running = true
            }
            statusProc.buffer = ""
        }
    }

    Process {
        id: proc
        property string errorBuffer:  ""
        property bool   gotAnyOutput: false
        // Set right before running is dropped to false from stopGeneration(),
        // so onExited can tell a user-requested stop from a real failure
        // (curl's SIGTERM exit code otherwise reads as an error below).
        property bool   cancelled:    false

        stdout: SplitParser {
            onRead: (line) => {
                proc.gotAnyOutput = true
                try {
                    var chunk = JSON.parse(line)
                    if (chunk.error) {
                        chat.history += "\n[model error: " + chunk.error + "]\n"
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
            if (proc.cancelled) {
                chat.history += "\n[stopped]\n"
                proc.cancelled = false
            } else if (exitCode !== 0 || !proc.gotAnyOutput) {
                if (proc.errorBuffer.includes("Connection refused") || exitCode === 7) {
                    chat.history += "\n[Ollama is not running. Check with: sudo sv status ollama]\n"
                } else if (exitCode === 28) {
                    chat.history += "\n[Ollama took too long to respond — timeout]\n"
                } else if (!proc.gotAnyOutput) {
                    chat.history += "\n[no response from Ollama — curl exit code: " + exitCode + "]\n"
                }
            }
        }
    }
}
