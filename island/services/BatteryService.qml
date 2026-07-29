import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property int capacity: 0
  property bool charging: false
  property real power: 0
  property string label: ""

  function refresh() {
    capProc.running = true
    acProc.running = true
    pwrProc.running = true
  }

  Process {
    id: capProc
    command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        root.capacity = parseInt(data.trim()) || 0
        updateLabel()
      }
    }
  }

  Process {
    id: acProc
    command: ["sh", "-c", "cat /sys/class/power_supply/ADP0/online 2>/dev/null || echo 0"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        root.charging = data.trim() === "1"
        updateLabel()
      }
    }
  }

  Process {
    id: pwrProc
    command: ["sh", "-c", "cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo 0"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        root.power = (parseInt(data.trim()) || 0) / 1000000
        updateLabel()
      }
    }
  }

  function updateLabel() {
    if (root.charging)
      root.label = "CHR:" + root.power.toFixed(0) + "W"
    else
      root.label = "BAT:" + root.capacity + "%"
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
