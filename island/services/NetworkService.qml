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

  // --- stats for HealthPanel (start/stop by panel visibility) ---
  property string iface: ""
  property string ssid: ""
  property real rxRate: 0
  property real txRate: 0
  property int _lastRx: 0
  property int _lastTx: 0

  function startStats() {
    statsTimer.running = true
  }

  function stopStats() {
    statsTimer.running = false
  }

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
        root.iface = v
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

  Timer {
    id: statsTimer
    interval: 2000
    running: false
    repeat: true
    onTriggered: {
      netDataProc.running = true
      ssidProc.running = true
    }
  }

  Process {
    id: netDataProc
    command: ["sh", "-c", "paste -d ' ' /sys/class/net/" + root.iface + "/statistics/rx_bytes /sys/class/net/" + root.iface + "/statistics/tx_bytes 2>/dev/null || echo '0 0'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        if (root.iface.length === 0) return
        var vals = data.trim().split(/\s+/)
        if (vals.length >= 2) {
          var rx = parseInt(vals[0]) || 0
          var tx = parseInt(vals[1]) || 0
          if (root._lastRx > 0) {
            root.rxRate = Math.max(0, (rx - root._lastRx) / 2)
            root.txRate = Math.max(0, (tx - root._lastTx) / 2)
          }
          root._lastRx = rx
          root._lastTx = tx
        }
      }
    }
  }

  Process {
    id: ssidProc
    command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID device wifi 2>/dev/null | grep '^yes:' | cut -d: -f2- | head -1"]
    running: false
    stdout: SplitParser {
      onRead: data => root.ssid = data.trim()
    }
  }

  Component.onCompleted: root.refreshIp()
}