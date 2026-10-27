import QtQuick
import "../config"

// Six-bar audio level indicator.
//
// `active` says whether audio is playing (the bars are visible); `animated`
// says whether the bars are allowed to move. They are deliberately separate:
// the island pill only ever shows these bars while it is collapsed, and the
// shell's standing rule is that nothing animates while the pill is at rest, so
// the bars are drawn static there and the 160 ms timer never runs. When no
// surface is animating the layer is not repainted at all, which is what keeps
// the closed-pill CPU budget.
Item {
  id: root
  implicitWidth: 28
  implicitHeight: 12

  property bool active: false
  property bool animated: false

  visible: active
  opacity: active ? 1 : 0

  Behavior on opacity { NumberAnimation { duration: Theme.animDurationNormal } }

  // Park every bar at the resting height. Called when animation stops so the
  // bars never freeze mid-sweep at whatever random height they last had.
  function resetBars() {
    for (var i = 0; i < barRepeater.count; i++) {
      var item = barRepeater.itemAt(i)
      if (item) item.height = 4
    }
  }

  onAnimatedChanged: {
    if (!root.animated) root.resetBars()
  }

  Row {
    anchors.centerIn: parent
    spacing: 2
    rotation: 180

    Repeater {
      id: barRepeater
      model: 6

      Rectangle {
        width: 3
        height: 4
        radius: 1.5
        color: Theme.accent

        Behavior on height {
          enabled: root.animated
          NumberAnimation { duration: Theme.animDurationFast }
        }
      }
    }
  }

  Timer {
    interval: 160
    running: root.active && root.animated
    repeat: true
    onTriggered: {
      for (var i = 0; i < barRepeater.count; i++) {
        var item = barRepeater.itemAt(i)
        if (item)
          item.height = 3 + Math.random() * (root.height - 4)
      }
    }
  }
}
