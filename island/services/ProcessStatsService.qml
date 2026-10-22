import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property bool active: false
  property var cpuTop: []
  property var memoryTop: []

  function start() {
    root.active = true
    root.sample()
  }

  function stop() {
    root.active = false
  }

  function sample() {
    if (root.active && !psProc.running) psProc.running = true
  }

  Process {
    id: psProc
    command: ["env", "LC_ALL=C", "ps", "-eo", "pid=,comm=,%cpu=,%mem="]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var rows = []
        var lines = this.text.trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          var match = lines[i].trim().match(/^(\d+)\s+(\S+)\s+([\d.]+)\s+([\d.]+)$/)
          if (!match) continue
          rows.push({
            pid: Number(match[1]),
            name: match[2],
            cpu: Number(match[3]) || 0,
            memory: Number(match[4]) || 0
          })
        }
        // The panel shows up to five rows per column, so keep six here.
        root.cpuTop = rows.slice().sort((a, b) => b.cpu - a.cpu).slice(0, 6)
        root.memoryTop = rows.slice().sort((a, b) => b.memory - a.memory).slice(0, 6)
      }
    }
  }

  Timer {
    interval: 1000
    running: root.active
    repeat: true
    onTriggered: root.sample()
  }
}
