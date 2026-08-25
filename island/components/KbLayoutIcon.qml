import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
  id: root

  property string keymap: ""
  readonly property string glyph: {
    var k = root.keymap.toLowerCase()
    if (k.indexOf("english") >= 0 || k === "us")
      return "\uD83C\uDDFA\uD83C\uDDF8"
    if (k.indexOf("arab") >= 0)
      return "\uD83C\uDDE6\uD83C\uDDEA"
    return root.keymap.length >= 2 ? root.keymap.substring(0, 2).toUpperCase() : ""
  }

  width: Math.max(flagText.implicitWidth, 16) + 4
  height: 22

  Text {
    id: flagText
    anchors.centerIn: parent
    text: root.glyph
    font.pixelSize: 18
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: switchProc.running = true
  }

  Process {
    id: switchProc
    command: ["hyprctl", "switchxkblayout", "current", "next"]
    running: false
    onRunningChanged: if (!running) Qt.callLater(() => initProc.running = true)
  }

  Process {
    id: initProc
    command: ["sh", "-c", "hyprctl -j devices"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var ks = JSON.parse(this.text).keyboards || []
          var mains = ks.filter(k => k.main)
          var kb = mains.length > 0 ? mains[0] : (ks.length > 0 ? ks[0] : null)
          if (kb)
            root.keymap = kb.active_keymap || ""
        } catch (e) {}
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 2000
    running: true
    repeat: true
    onTriggered: initProc.running = true
  }

  Connections {
    target: Hyprland
    function onRawEvent(ev) {
      if (ev.name !== "activelayout")
        return
      var parts = ev.data.split(",")
      if (parts.length > 1)
        root.keymap = parts[parts.length - 1].trim()
    }
  }

  Component.onCompleted: initProc.running = true
}
