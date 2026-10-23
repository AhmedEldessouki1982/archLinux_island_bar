import QtQuick
import Quickshell.Io

// `top` provides per-frame CPU activity (ps %CPU is a lifetime average and
// makes short-lived panel helpers look artificially busy). One process runs
// while the panel is open, then is stopped when it closes.
Item {
  id: root
  visible: false

  property bool active: false
  property var cpuTop: []
  property var memoryTop: []
  property var _frameRows: []
  property int _frameCount: 0

  function start() {
    if (root.active) return
    root._frameRows = []
    root._frameCount = 0
    root.active = true
    topProc.running = true
  }
  function stop() {
    root.active = false
    topProc.running = false
    root._frameRows = []
  }

  function finishFrame() {
    root._frameCount++
    if (root._frameCount > 1) {
      var rows = root._frameRows
      root.cpuTop = rows.slice().sort((a, b) => b.cpu - a.cpu).slice(0, 6)
      root.memoryTop = rows.slice().sort((a, b) => b.memory - a.memory).slice(0, 6)
    }
    root._frameRows = []
  }

  Process {
    id: topProc
    command: ["env", "LC_ALL=C", "top", "-b", "-d", "2", "-w", "200"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = String(data)
        if (/^\s*PID\s+USER\s+/.test(line)) {
          if (root._frameCount > 0 || root._frameRows.length > 0) root.finishFrame()
          return
        }
        var match = line.match(/^\s*(\d+)\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+([\d.]+)\s+([\d.]+)\s+\S+\s+(.+)$/)
        if (!match) return
        var command = match[4].trim()
        var executable = command.split(/\s+/)[0].split("/").pop().toLowerCase()
        var excluded = ["nvidia-smi", "top", "df", "asusctl", "supergfxctl", "wpctl", "checkupdates", "ps", "env"]
        if (excluded.indexOf(executable) >= 0) return
        root._frameRows.push({
          pid: Number(match[1]), name: command,
          cpu: Number(match[2]) || 0, memory: Number(match[3]) || 0
        })
      }
    }
  }
}
