import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  visible: false

  property bool capsOn: false
  property bool numOn: false

  signal capsChanged(bool on)
  signal numChanged(bool on)

  Process {
    id: lockProc
    command: ["sh", "-c", "if [ \"$(head -1 /sys/class/leds/*:capslock/brightness 2>/dev/null)\" = \"1\" ]; then echo C1; else echo C0; fi; if [ \"$(head -1 /sys/class/leds/*:numlock/brightness 2>/dev/null)\" = \"1\" ]; then echo N1; else echo N0; fi"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = data.trim()
        if (v === "C1") {
          if (!root.capsOn) {
            root.capsOn = true
            root.capsChanged(true)
          }
        } else if (v === "C0") {
          if (root.capsOn) {
            root.capsOn = false
            root.capsChanged(false)
          }
        } else if (v === "N1") {
          if (!root.numOn) {
            root.numOn = true
            root.numChanged(true)
          }
        } else if (v === "N0") {
          if (root.numOn) {
            root.numOn = false
            root.numChanged(false)
          }
        }
      }
    }
  }

  Timer {
    id: lockTimer
    interval: 500
    running: true
    repeat: true
    onTriggered: lockProc.running = true
  }

  Component.onCompleted: lockProc.running = true
}
