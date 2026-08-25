import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io

Item {
  id: root
  visible: false

  property real volume: 0
  property bool muted: false
  property bool active: false
  property bool headphoneConnected: false
  property bool micConnected: false
  property bool _initialized: false
  property int _activeStreams: 0
  property bool fastPoll: false
  property var sinks: []
  property var sources: []
  property string defaultSink: ""
  property string defaultSource: ""

  signal externalChangeDetected()

  function sync() {
    readProc.running = true
    portProc.running = true
    sourcePortProc.running = true
  }

  function refreshDevices() {
    sinkListProc.running = true
    sourceListProc.running = true
  }

  function setDefaultSink(name) {
    if (!name)
      return
    setSinkProc.command = ["pactl", "set-default-sink", name]
    setSinkProc.running = true
  }

  function setDefaultSource(name) {
    if (!name)
      return
    setSourceProc.command = ["pactl", "set-default-source", name]
    setSourceProc.running = true
  }

  function setVolume(v) {
    var pct = Math.round(Math.max(0, Math.min(1, v)) * 100)
    setProc.command = ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + pct + "% 2>/dev/null"]
    setProc.running = true
    root.volume = pct / 100
  }

  function toggleMute() {
    muteProc.running = true
    root.muted = !root.muted
  }

  function stepVolume(delta) {
    root.setVolume(Math.max(0, Math.min(1, root.volume + delta)))
  }

  function _isOutputStream(node) {
    return node && node.isStream && ((node.type & PwNodeType.Sink) !== 0)
  }

  function _scanStreams() {
    var count = 0
    var vals = Pipewire.nodes.values
    for (var i = 0; i < vals.length; i++) {
      if (root._isOutputStream(vals[i])) count++
    }
    if (count !== root._activeStreams) {
      root._activeStreams = count
      root.active = count > 0
    }
  }

  Process {
    id: readProc
    command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim()
        var m = line.match(/Volume:\s+([\d.]+)/)
        if (m) {
          var vol = parseFloat(m[1].replace(",", ".")) || 0
          var isMuted = line.indexOf("MUTED") >= 0
          var firstRead = !root._initialized
          if (firstRead) {
            root.volume = vol
            root.muted = isMuted
            root._initialized = true
          } else {
            var changed = false
            if (Math.abs(vol - root.volume) > 0.001) { root.volume = vol; changed = true }
            if (isMuted !== root.muted) { root.muted = isMuted; changed = true }
            if (changed && !setProc.running && !muteProc.running) root.externalChangeDetected()
          }
        }
      }
    }
  }

  Process {
    id: setProc
    command: ["true"]
    running: false
  }

  Process {
    id: sinkListProc
    command: ["sh", "-c", "pactl list short sinks 2>/dev/null"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        var lines = this.text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].split("\t")
          if (f.length >= 3)
            out.push({name: f[1], desc: f[2]})
        }
        root.sinks = out
        defaultSinkProc.running = true
      }
    }
  }

  Process {
    id: sourceListProc
    command: ["sh", "-c", "pactl list short sources 2>/dev/null"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        var lines = this.text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i].split("\t")
          if (f.length >= 3)
            out.push({name: f[1], desc: f[2]})
        }
        root.sources = out
        defaultSourceProc.running = true
      }
    }
  }

  Process {
    id: defaultSinkProc
    command: ["sh", "-c", "pactl get-default-sink 2>/dev/null"]
    running: false
    stdout: SplitParser {
      onRead: data => root.defaultSink = data.trim()
    }
  }

  Process {
    id: defaultSourceProc
    command: ["sh", "-c", "pactl get-default-source 2>/dev/null"]
    running: false
    stdout: SplitParser {
      onRead: data => root.defaultSource = data.trim()
    }
  }

  Process {
    id: setSinkProc
    command: ["true"]
    running: false
    onExited: root.refreshDevices()
  }

  Process {
    id: setSourceProc
    command: ["true"]
    running: false
    onExited: root.refreshDevices()
  }

  Process {
    id: muteProc
    command: ["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null"]
    running: false
  }

  Process {
    id: portProc
    command: ["sh", "-c", "pactl list sinks 2>/dev/null | awk -v s=\"$(pactl get-default-sink)\" 'index($0, \"Name: \" s) { f=1 } f && /Active Port:/ { print $3; exit }'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var port = data.trim()
        if (!port) return
        var hp = port.indexOf("headphone") >= 0
        if (hp !== root.headphoneConnected) {
          root.headphoneConnected = hp
        }
      }
    }
  }

  Process {
    id: sourcePortProc
    command: ["sh", "-c", "pactl list sources 2>/dev/null | awk -v s=\"$(pactl get-default-source)\" 'index($0, \"Name: \" s) { f=1 } f && /Active Port:/ { print $3; exit }'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var port = data.trim()
        if (!port) return
        // Only treat an *external* mic (headset/front/etc.) as "connected" —
        // the built-in analog-input-internal-mic is always present and must
        // not flip the icon into the headset state.
        var mic = port.indexOf("mic") >= 0 && port.indexOf("internal") < 0
        if (mic !== root.micConnected) {
          root.micConnected = mic
        }
      }
    }
  }

  Connections {
    target: Pipewire
    function onDefaultAudioSinkChanged() {
      root.sync()
      root.refreshDevices()
    }
    function onDefaultAudioSourceChanged() {
      root.refreshDevices()
    }
  }

  Timer {
    id: fullSyncTimer
    interval: root.fastPoll ? 150 : 1000
    running: true
    repeat: true
    onTriggered: root.sync()
  }

  function requestFastPoll() {
    root.fastPoll = true
    fastPollResetTimer.restart()
  }

  Timer {
    id: fastPollResetTimer
    interval: 2000
    onTriggered: root.fastPoll = false
  }

  Timer {
    id: streamScanTimer
    interval: 1000
    running: true
    repeat: true
    onTriggered: root._scanStreams()
  }

  Component.onCompleted: root.sync()
}
