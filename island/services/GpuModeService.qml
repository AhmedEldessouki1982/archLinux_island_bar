import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Item {
  id: root
  visible: false

  property string gpuMode: ""
  property string gpuPowerStatus: ""
  property string powerProfile: ""

  function start() {
    gfxModeProc.running = true
    pwrProfileProc.running = true
  }

  function stop() {
    // one-shot; no timer to stop
  }

  Process {
    id: gfxModeProc
    command: ["sh", "-c", "echo M:$(supergfxctl -g) && echo S:$(supergfxctl -S)"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim()
        if (line.indexOf("M:") === 0) root.gpuMode = line.substring(2)
        else if (line.indexOf("S:") === 0) root.gpuPowerStatus = line.substring(2)
      }
    }
  }

  Process {
    id: pwrProfileProc
    command: ["sh", "-c", "asusctl profile get 2>/dev/null | head -1 | cut -d: -f2 | xargs"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = data.trim()
        if (v.length > 0) root.powerProfile = v
      }
    }
  }
}