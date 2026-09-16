import Quickshell
import Quickshell.Io
import QtQuick
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

  property bool _active: false

  function start() {
    root._active = true
    loadView.watchChanges = true
    memView.watchChanges = true
    loadView.reload()
    memView.reload()
    sysInfoProc.running = true
    cpuCountProc.running = true
  }

  function stop() {
    root._active = false
    loadView.watchChanges = false
    memView.watchChanges = false
  }

  // --- one-shot shell for uname/whoami (no sysfs equivalent) ---
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

  // --- FileView: zero-fork /proc/loadavg watcher ---
  FileView {
    id: loadView
    path: "/proc/loadavg"
    watchChanges: false
    onLoaded: {
      var parts = text().trim().split(/\s+/)
      if (parts.length >= 3) {
        var raw = parseFloat(parts[0])
        if (!isNaN(raw) && root.cpuCount > 0)
          root.cpuLoad = Math.min(100, raw * 100 / root.cpuCount)
      }
    }
  }

  // --- FileView: zero-fork /proc/meminfo watcher ---
  FileView {
    id: memView
    path: "/proc/meminfo"
    watchChanges: false
    onLoaded: {
      var lines = text().trim().split("\n")
      var memTotalKb = 0
      var memAvailKb = 0
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].indexOf("MemTotal:") === 0)
          memTotalKb = parseInt(lines[i].split(/\s+/)[1]) || 0
        else if (lines[i].indexOf("MemAvailable:") === 0)
          memAvailKb = parseInt(lines[i].split(/\s+/)[1]) || 0
        if (memTotalKb > 0 && memAvailKb > 0) break
      }
      if (memTotalKb > 0) {
        root.ramTotal = memTotalKb * 1024
        root.ramUsed = (memTotalKb - memAvailKb) * 1024
        root.ramPercent = root.ramUsed / root.ramTotal * 100
      }
    }
  }

  // --- read timer replaces the old fork-per-tick ---
  Timer {
    interval: 2000
    running: root._active
    repeat: true
    onTriggered: {
      loadView.reload()
      memView.reload()
    }
  }

  Component.onCompleted: {
    cpuCountProc.running = true
    sysInfoProc.running = true
    loadView.reload()
    memView.reload()
    initTimer.start()
  }

  Timer {
    id: initTimer
    interval: 100
    running: false
    repeat: false
    onTriggered: root._active = true
  }
}
