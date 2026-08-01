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
  property bool _initialized: false
  property int _activeStreams: 0

  signal externalChangeDetected()

  function sync() {
    readProc.running = true
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
    id: muteProc
    command: ["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null"]
    running: false
  }

  Connections {
    target: Pipewire
    function onDefaultAudioSinkChanged() { root.sync() }
  }

  Timer {
    id: fullSyncTimer
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.sync()
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
