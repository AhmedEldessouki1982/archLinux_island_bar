import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Item {
  id: root
  visible: false

  property int cpuCount: 1
  property real cpuLoad: 0
  property real ramUsed: 0
  property real ramTotal: 0
  property real ramPercent: 0
  property string kernelVersion: ""
  property string userName: ""
  property string hostName: ""

  function start() {
    cpuCountProc.running = true
    sysInfoProc.running = true
    pollTimer.running = true
  }

  function stop() {
    pollTimer.running = false
  }

  Timer {
    id: pollTimer
    interval: 2000
    running: false
    repeat: true
    onTriggered: {
      loadProc.running = true
      memProc.running = true
    }
  }

  Process {
    id: cpuCountProc
    command: ["nproc"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var n = parseInt(data.trim())
        if (!isNaN(n) && n > 0) root.cpuCount = n
      }
    }
  }

  Process {
    id: sysInfoProc
    command: ["sh", "-c", "echo K:$(uname -r) && echo U:$(whoami) && echo H:$(uname -n)"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim()
        if (line.indexOf("K:") === 0) root.kernelVersion = line.substring(2)
        else if (line.indexOf("U:") === 0) root.userName = line.substring(2)
        else if (line.indexOf("H:") === 0) root.hostName = line.substring(2)
      }
    }
  }

  Process {
    id: loadProc
    command: ["sh", "-c", "cat /proc/loadavg"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var parts = data.trim().split(/\s+/)
        if (parts.length >= 3) {
          var raw = parseFloat(parts[0])
          if (!isNaN(raw) && root.cpuCount > 0)
            root.cpuLoad = Math.min(100, raw * 100 / root.cpuCount)
        }
      }
    }
  }

  Process {
    id: memProc
    command: ["sh", "-c", "awk '/MemTotal/ {mt=$2} /MemAvailable/ {ma=$2} END {print mt, ma}' /proc/meminfo"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var vals = data.trim().split(/\s+/)
        if (vals.length >= 2) {
          var memTotalKb = parseInt(vals[0])
          var memAvailKb = parseInt(vals[1])
          if (memTotalKb > 0) {
            root.ramTotal = memTotalKb * 1024
            root.ramUsed = (memTotalKb - memAvailKb) * 1024
            root.ramPercent = root.ramUsed / root.ramTotal * 100
          }
        }
      }
    }
  }
}