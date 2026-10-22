import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property bool active: false
  property int rootPercent: -1
  property int homePercent: -1
  property double uptimeSeconds: 0

  function start() {
    root.active = true
    root.sample()
  }

  function stop() {
    root.active = false
    if (diskProc.running) diskProc.running = false
  }

  function sample() {
    if (!root.active) return
    uptimeView.reload()
    if (!diskProc.running) diskProc.running = true
  }

  FileView {
    id: uptimeView
    path: "/proc/uptime"
    watchChanges: false
    onLoaded: {
      var value = Number(text().trim().split(/\s+/)[0])
      if (isFinite(value)) root.uptimeSeconds = value
    }
  }

  Process {
    id: diskProc
    command: ["env", "LC_ALL=C", "df", "-P", "/", "/home"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = this.text.trim().split("\n").slice(1)
        var values = []
        for (var i = 0; i < lines.length; i++) {
          var match = lines[i].match(/\s([0-9]+)%\s+\S+\s*$/)
          if (match) values.push(Number(match[1]))
        }
        if (values.length > 0) root.rootPercent = values[0]
        if (values.length > 1) root.homePercent = values[1]
      }
    }
  }

  Timer {
    interval: 30000
    running: root.active
    repeat: true
    onTriggered: root.sample()
  }
}
