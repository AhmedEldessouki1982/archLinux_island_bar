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

  Process {
    id: readProc
    command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null && echo PORT && pactl list sinks 2>/dev/null | grep 'Active Port:' | head -1"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim()
        var m = line.match(/Volume:\s+([\d.]+)/)
        var changed = false
        if (m) {
          var vol = parseFloat(m[1].replace(",", ".")) || 0
          var firstRead = !root._initialized
          if (firstRead) {
            root.volume = vol
          } else if (Math.abs(vol - root.volume) > 0.001) {
            root.volume = vol; changed = true
          }
          var isMuted = line.indexOf("MUTED") >= 0
          if (firstRead) {
            root.muted = isMuted
          } else if (isMuted !== root.muted) {
            root.muted = isMuted; changed = true
          }
          root._initialized = true
        }
        if (line.indexOf("Active Port:") >= 0) {
          var hp = line.toLowerCase().indexOf("headphone") >= 0
          if (hp !== root.headphoneConnected) root.headphoneConnected = hp
        }
        if (changed && !setProc.running && !muteProc.running) root.externalChangeDetected()
      }
    }
  }

  Process {
    id: musicProc
    command: ["sh", "-c", "pw-dump 2>/dev/null | python3 -c \"import json,sys; d=json.load(sys.stdin); print(sum(1 for o in d if o.get('type')=='PipeWire:Interface:Node' and o.get('info',{}).get('props',{}).get('media.class')=='Stream/Output/Audio' and o.get('info',{}).get('state')=='running'))\""]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var n = parseInt(data.trim())
        var playing = !isNaN(n) && n > 0
        if (playing !== root.active) root.active = playing
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
    interval: 500
    running: true
    repeat: true
    onTriggered: root.sync()
  }

  Timer {
    id: musicTimer
    interval: 1000
    running: true
    repeat: true
    onTriggered: musicProc.running = true
  }

  Component.onCompleted: { var _ = Pipewire.ready; root.sync(); musicProc.running = true }
}
