import QtQuick
import Quickshell
import Quickshell.Io

// Reads the compositor's window-corner rounding once, so the island's shape can
// sit in sympathy with the rest of the desktop instead of using a hardcoded
// radius. One process, fired once at startup, that exits on its own: there is
// no timer here and nothing polls, so the idle rule still holds.
//
// `rounding` is -1 until a successful read. Callers must treat that as "keep
// the design tokens": a missing hyprctl (another compositor, a stripped
// install) is not an error, it just means the drop stays as designed.
Item {
  id: root
  visible: false

  property int rounding: -1
  readonly property bool known: rounding >= 0

  function refresh() {
    if (!proc.running) proc.running = true
  }

  Component.onCompleted: refresh()

  Process {
    id: proc
    command: ["hyprctl", "getoption", "decoration:rounding", "-j"]
    running: false

    stdout: StdioCollector {
      onStreamFinished: {
        var n = -1
        try {
          var o = JSON.parse(this.text)
          if (o && typeof o.int === "number" && o.int >= 0) n = o.int
        } catch (e) {
          n = -1
        }
        if (n >= 0) root.rounding = n
      }
    }
  }
}
