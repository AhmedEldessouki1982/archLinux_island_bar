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
  property real _lastRx: 0
  property real _lastTx: 0
  property real _lastSampleMs: 0

  function startStats() {
    root._resetStatsBaseline()
    statsTimer.running = true
    root._sampleStats()
  }

  function stopStats() {
    statsTimer.running = false
    root._resetStatsBaseline()
  }

  function _resetStatsBaseline() {
    root._lastRx = 0
    root._lastTx = 0
    root._lastSampleMs = 0
    root.rxRate = 0
    root.txRate = 0
  }

  function _sampleStats() {
    if (root.iface.length === 0)
      return
    if (!netDataProc.running) netDataProc.running = true
    if (!ssidProc.running) ssidProc.running = true
  }

  readonly property string qualityStatus: root.latencyMs < 0 ? "Unknown"
    : root.latencyMs <= 30 ? "Good"
    : root.latencyMs <= 80 ? "OK" : "Poor"
  readonly property color qualityColor: root.latencyMs < 0 ? Theme.comment
    : root.latencyMs <= 30 ? Theme.green
    : root.latencyMs <= 80 ? Theme.yellow : Theme.orange

  function refreshIp() {
    if (!routeProcess.running) routeProcess.running = true
  }

  Process {
    id: routeProcess
    command: ["sh", "-c", "iface=$(ip -4 route show default | awk 'NR==1 {print $5}'); addr=$(ip -4 -o addr show dev \"$iface\" scope global 2>/dev/null | awk 'NR==1 {print $4}' | cut -d/ -f1); printf '%s|%s\\n' \"$iface\" \"${addr:-...}\""]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var fields = data.trim().split("|")
        var nextIface = fields.length > 0 ? fields[0] : ""
        if (nextIface !== root.iface) {
          root.iface = nextIface
          root._resetStatsBaseline()
          if (statsTimer.running) root._sampleStats()
        }
        root.ipAddress = fields.length > 1 && fields[1].length > 0 ? fields[1] : "..."
        root.connected = nextIface.length > 0
        root.type = /^wl/.test(nextIface) ? "wifi" : "ethernet"
        if (!root.connected) {
          root.latencyMs = -1
          root.ssid = ""
        }
      }
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
    onTriggered: root._sampleStats()
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
          var rx = Number(vals[0]) || 0
          var tx = Number(vals[1]) || 0
          var now = Date.now()
          if (root._lastSampleMs > 0 && now > root._lastSampleMs) {
            var elapsed = (now - root._lastSampleMs) / 1000
            root.rxRate = Math.max(0, (rx - root._lastRx) / elapsed)
            root.txRate = Math.max(0, (tx - root._lastTx) / elapsed)
          }
          root._lastRx = rx
          root._lastTx = tx
          root._lastSampleMs = now
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
