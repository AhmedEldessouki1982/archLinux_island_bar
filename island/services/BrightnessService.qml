import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property real percent: 100
  property bool fastPoll: false

  signal externalChangeDetected()

  function refresh() {
    getProc.running = true
  }

  function setPercent(v) {
    var p = Math.max(1, Math.min(100, Math.round(v)))
    root.percent = p
    setProc.running = true
  }

  function stepPercent(delta) {
    root.setPercent(root.percent + delta)
  }

  Process {
    id: getProc
    command: ["sh", "-c", "brightnessctl get 2>/dev/null && echo ' ' && brightnessctl max 2>/dev/null"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var parts = data.trim().split(/\s+/)
        if (parts.length >= 2) {
          var cur = parseInt(parts[0])
          var max = parseInt(parts[1])
          if (max > 0) {
            var pct = Math.round(cur / max * 100)
            if (pct !== root.percent) {
              root.percent = pct
              root.externalChangeDetected()
            }
          }
        }
      }
    }
  }

  Process {
    id: setProc
    command: ["sh", "-c", "brightnessctl set " + root.percent + "% 2>/dev/null"]
    running: false
  }

  Timer {
    id: pollTimer
    interval: root.fastPoll ? 150 : 2000
    running: true
    repeat: true
    onTriggered: root.refresh()
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

  Component.onCompleted: root.refresh()
}
