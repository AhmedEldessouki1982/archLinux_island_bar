import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property bool connected: false
  property string ipAddress: "..."
  property string ifaceName: ""
  property string type: "wifi"

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
        root.ifaceName = v
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

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.refreshIp()
  }

  Component.onCompleted: root.refreshIp()
}