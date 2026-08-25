import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Item {
  id: root
  visible: false

  property bool connected: false
  property string ipAddress: "..."
  property string type: "wifi"
  property real latencyMs: -1
  property string pingHost: "8.8.8.8"

  readonly property string qualityStatus: root.latencyMs < 0 ? "Unknown"
    : root.latencyMs <= 30 ? "Good"
    : root.latencyMs <= 80 ? "OK" : "Poor"
  readonly property color qualityColor: root.latencyMs < 0 ? Theme.comment
    : root.latencyMs <= 30 ? Theme.green
    : root.latencyMs <= 80 ? Theme.yellow : Theme.orange

  function refreshIp() {
    ipProcess.running = true
    gwProcess.running = true
    ifaceProcess.running = true
  }

  Process {
    id: gwProcess
    command: ["sh", "-c", "ip -4 route show default | grep -q . && echo up || echo down"]
    running: false
    stdout: SplitParser {
      onRead: data => root.connected = data.trim() === "up"
    }
  }

  Process {
    id: ifaceProcess
    command: ["sh", "-c", "ip -4 route show default | awk '{print $5}' | head -1"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = data.trim()
        root.type = (v.indexOf("eth") === 0 || v.indexOf("enp") === 0 || v.indexOf("enx") === 0) ? "ethernet" : "wifi"
      }
    }
  }

  Process {
    id: ipProcess
    command: ["sh", "-c", "ip -4 addr show | grep -oP 'inet \\K[\\d.]+' | grep -v '127.0.0.1' | head -1 || echo '...'"]
    running: false
    stdout: SplitParser {
      onRead: data => root.ipAddress = data.trim()
    }
  }

  Process {
    id: pingProcess
    command: ["sh", "-c", "ping -c1 -W2 " + root.pingHost + " 2>/dev/null | grep -oP 'time=\\K[\\d.]+'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = parseFloat(data.trim())
        if (!isNaN(v))
          root.latencyMs = v
      }
    }
    onExited: code => {
      if (code !== 0)
        root.latencyMs = -1
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: {
      if (root.connected)
        pingProcess.running = true
      else
        root.latencyMs = -1
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.refreshIp()
  }

  Component.onCompleted: root.refreshIp()
}