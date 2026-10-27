import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

Item {
  id: root
  visible: false

  property int cpuCount: 1
  // CPU utilisation in percent, from two consecutive /proc/stat samples.
  // This is not the load average: loadavg counts runnable and uninterruptible
  // tasks and never exceeds 100 the way utilisation does.
  property real cpuLoad: 0
  property real loadAverage: 0
  // True once a delta exists; before that cpuLoad is meaningless, not zero.
  property bool cpuReady: false
  property real ramUsed: 0
  property real ramTotal: 0
  property real ramPercent: 0
  property bool ramReady: false
  property string kernelVersion: ""
  property string userName: ""
  property string hostName: ""

  property bool _active: false
  property real _lastBusy: 0
  property real _lastTotal: 0

  function start() {
    root._active = true
    root.cpuReady = false
    root._lastBusy = 0
    root._lastTotal = 0
    loadView.watchChanges = true
    memView.watchChanges = true
    statView.watchChanges = true
    loadView.reload()
    memView.reload()
    statView.reload()
    sysInfoProc.running = true
    cpuCountProc.running = true
  }

  function stop() {
    root._active = false
    loadView.watchChanges = false
    memView.watchChanges = false
    statView.watchChanges = false
    root.cpuReady = false
    root._lastBusy = 0
    root._lastTotal = 0
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

  // --- FileView: zero-fork /proc/loadavg watcher (load average only) ---
  FileView {
    id: loadView
    path: "/proc/loadavg"
    watchChanges: false
    onLoaded: {
      var parts = text().trim().split(/\s+/)
      if (parts.length >= 1) {
        var raw = parseFloat(parts[0])
        if (!isNaN(raw)) root.loadAverage = raw
      }
    }
  }

  // --- FileView: zero-fork /proc/stat watcher (real utilisation) ---
  // user nice system idle iowait irq softirq steal; guest/guestnice are already
  // counted inside user/nice, so they are deliberately left out of the total.
  FileView {
    id: statView
    path: "/proc/stat"
    watchChanges: false
    onLoaded: {
      var first = text().trim().split("\n")[0]
      if (!first || first.indexOf("cpu") !== 0) return
      var f = first.trim().split(/\s+/)
      var total = 0
      var idle = 0
      for (var i = 1; i <= 8 && i < f.length; i++) {
        var v = parseInt(f[i], 10) || 0
        if (i === 4 || i === 5) idle += v
        total += v
      }
      if (total <= 0) return
      if (root._lastTotal > 0 && total > root._lastTotal) {
        var dTotal = total - root._lastTotal
        var dBusy = dTotal - (idle - root._lastBusy)
        root.cpuLoad = Math.max(0, Math.min(100, dBusy / dTotal * 100))
        root.cpuReady = true
      }
      root._lastTotal = total
      root._lastBusy = idle
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
        root.ramReady = true
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
      statView.reload()
    }
  }

  Component.onCompleted: {
    cpuCountProc.running = true
    sysInfoProc.running = true
    loadView.reload()
    memView.reload()
    statView.reload()
  }
}
