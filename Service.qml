import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "file:/usr/share/voxtype/quickshell/voxtype-shared" as VT

Item {
    id: root
    property var shell: null
    property var manifest: null
    property bool preview: false
    property string transcript: ""
    property int revealed: 0
    property bool showingResult: false
    property bool audioConnected: false
    property real lastEventTime: Date.now() / 1000
    property real tick: 0
    readonly property string phase: preview ? "transcribing" : reader.state
    readonly property bool listening: phase === "recording" || phase === "streaming"
    readonly property bool active: listening || phase === "transcribing"
    readonly property color background: Color.popups.background
    readonly property color foreground: Color.popups.text
    readonly property color accent: contrast(Color.accent, background) >= 3 ? Color.accent : foreground
    readonly property real energy: listening ? Math.min(1, audio.peak * 5) : 0

    function luminance(c) {
        function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }
    function contrast(a, b) {
        const x = luminance(a), y = luminance(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }

    VT.AudioBridge {
        id: audio
        onConnected: root.audioConnected = true
        onDisconnected: root.audioConnected = false
    }
    VT.StateReader {
        id: reader
        onStateChanged: {
            if (state === "recording" || state === "streaming") {
                root.transcript = ""
                root.showingResult = false
                hide.stop()
            }
        }
    }
    FileView {
        id: transcriptFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/vox-portrait/transcript.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const event = JSON.parse(text())
                if (event.time <= root.lastEventTime || Date.now() / 1000 - event.time > 15) return
                root.lastEventTime = event.time
                root.transcript = event.text
                root.revealed = 0
                root.showingResult = true
                hide.restart()
            } catch (e) {}
        }
    }
    // Also discover the first event when its runtime directory did not exist at login.
    Timer { interval: 750; repeat: true; running: true; onTriggered: transcriptFile.reload() }
    Timer { id: hide; interval: 14000; onTriggered: { root.showingResult = false; root.transcript = "" } }
    Timer {
        interval: 24; repeat: true; running: root.showingResult && root.revealed < root.transcript.length
        onTriggered: root.revealed = Math.min(root.transcript.length, root.revealed + 3)
    }
    Timer {
        interval: 40; repeat: true; running: panel.visible
        onTriggered: { root.tick += 0.04; wave.requestPaint() }
    }
    Timer { id: previewTimeout; interval: 20000; onTriggered: root.preview = false }
    IpcHandler {
        target: "vox-portrait"
        function preview(): string { root.preview = true; previewTimeout.restart(); return "ok" }
        function close(): string { root.preview = false; root.showingResult = false; return "ok" }
        function status(): string { return JSON.stringify({phase: root.phase, visible: panel.visible, imageReady: portrait.status === Image.Ready, audioConnected: root.audioConnected, showingResult: root.showingResult, characters: root.revealed, background: String(root.background), foreground: String(root.foreground), accent: String(root.accent), themeAccent: String(Color.accent), accentContrast: root.contrast(root.accent, root.background)}) }
    }
    PanelWindow {
        id: panel
        visible: !reader.osdSuppressed && (root.active || root.showingResult || root.preview)
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        WlrLayershell.namespace: "vox-portrait"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}

        Rectangle {
            id: surface
            width: Math.min(Style.space(340), panel.width - 32)
            height: Math.min(Style.space(510), panel.height - 80)
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 24
            color: root.background
            border.color: Color.popups.border
            border.width: 1
            radius: Math.min(8, Style.cornerRadius)
            clip: true

            Text {
                x: 18; y: 15; width: parent.width - 36
                text: "VOX  /  NEURAL INTERFACE"
                font.family: Style.font.family; font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                color: root.foreground
            }
            Item {
                id: face
                x: 12; y: 40; width: parent.width - 24
                height: Math.min(width, surface.height * 0.59)
                clip: true
                Image {
                    id: portrait
                    anchors.fill: parent
                    source: "neural-portrait.png"
                    fillMode: Image.PreserveAspectFit
                    visible: false
                    sourceSize.width: 768
                }
                MultiEffect {
                    anchors.fill: portrait
                    source: portrait
                    colorization: 1
                    colorizationColor: root.accent
                    brightness: root.luminance(root.background) > 0.5 ? -0.08 : 0.06
                    opacity: 0.86 + root.energy * 0.14
                    scale: 1 + root.energy * 0.025 + Math.sin(root.tick * 1.1) * 0.004
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }
                Rectangle {
                    x: parent.width * 0.2; width: parent.width * 0.6; height: 1
                    y: (Math.sin(root.tick * 1.3) + 1) * (parent.height - 1) / 2
                    color: root.accent; opacity: root.listening ? 0.08 : 0.25
                }
                Rectangle {
                    x: parent.width * 0.2; width: parent.width * 0.6; height: 18
                    y: (Math.sin(root.tick * 1.3) + 1) * (parent.height - 26) / 2
                    color: root.accent; opacity: 0.025
                }
            }
            Canvas {
                id: wave
                x: 18; y: face.y + face.height + 5
                width: parent.width - 36; height: 32
                property var samples: []
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    samples.push(root.energy)
                    if (samples.length > 64) samples.shift()
                    ctx.strokeStyle = root.accent
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    for (let i = 0; i < samples.length; i++) {
                        const x = i * width / 64
                        const h = Math.max(1, samples[i] * 14)
                        ctx.moveTo(x, height / 2 - h)
                        ctx.lineTo(x, height / 2 + h)
                    }
                    ctx.stroke()
                }
            }
            Text {
                id: label
                x: 18; y: wave.y + wave.height + 8; width: parent.width - 36
                text: root.showingResult ? "TRANSCRIPT" : root.listening ? "LISTENING" : root.preview ? "PREVIEW" : "TRANSCRIBING"
                font.family: Style.font.family; font.pixelSize: Style.font.body
                elide: Text.ElideRight
                color: root.accent
            }
            Flickable {
                x: 18; y: label.y + 27; width: parent.width - 36
                height: Math.max(16, parent.height - y - 18)
                contentHeight: words.height
                contentY: Math.max(0, contentHeight - height)
                clip: true
                Text {
                    id: words
                    width: parent.width
                    textFormat: Text.PlainText
                    text: root.showingResult ? root.transcript.substring(0, root.revealed) : root.listening ? "..." : ""
                    wrapMode: Text.Wrap
                    font.family: Style.font.family
                    font.pixelSize: Style.font.heading; color: root.foreground
                }
            }
        }
    }
}
