import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property real percent: 95
  property int realMaxPercent: 95
  property bool fastPoll: false
  readonly property real displayPercent: Math.max(0, Math.min(100, Math.round(root.percent / root.realMaxPercent * 100)))

  signal externalChangeDetected()

  function refresh() {
    getProc.running = true
  }

  function setPercent(v) {
    var realTarget = Math.round(v / 100 * root.realMaxPercent)
    var p = Math.max(1, Math.min(root.realMaxPercent, realTarget))
    root.percent = p
    setProc.running = true
  }

  function stepPercent(delta) {
    var d = Math.max(1, Math.min(100, root.displayPercent + delta))
    root.setPercent(d)
  }

  Process {
    id: getProc
    command: ["sh", "-c", "echo \"$(brightnessctl get 2>/dev/null) $(brightnessctl max 2>/dev/null)\""]
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
