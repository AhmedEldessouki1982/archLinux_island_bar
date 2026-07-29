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

  function sync() {
    readProc.running = true
  }

  function setVolume(v) {
    var pct = Math.round(Math.max(0, Math.min(1, v)) * 100)
    setProc.command = ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + pct + "% 2>/dev/null"]
    setProc.running = true
    root.volume = v
  }

  function toggleMute() {
    muteProc.running = true
    root.muted = !root.muted
  }

  function stepVolume(delta) {
    root.setVolume(Math.max(0, Math.min(1, root.volume + delta)))
  }

  Process {
    id: readProc
    command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null && echo STREAMS && pactl list short sink-inputs 2>/dev/null | wc -l && echo PORT && pactl list sinks 2>/dev/null | grep 'Active Port:' | head -1"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim()
        var m = line.match(/Volume:\s+([\d.]+)/)
        if (m) root.volume = parseFloat(m[1]) || 0
        if (line.indexOf("MUTED") >= 0) root.muted = true
        else if (m) root.muted = false
        var streamMatch = line.match(/^(\d+)$/)
        if (streamMatch) root.active = parseInt(streamMatch[1]) > 0
        if (line.indexOf("Active Port:") >= 0) {
          root.headphoneConnected = line.toLowerCase().indexOf("headphone") >= 0
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
    interval: 200
    running: true
    repeat: true
    onTriggered: root.sync()
  }

  Component.onCompleted: { var _ = Pipewire.ready; root.sync() }
}
