import QtQuick
import "../config"

Item {
  id: root
  implicitWidth: 28
  implicitHeight: 12

  property bool active: false

  visible: active
  opacity: active ? 1 : 0

  Behavior on opacity { NumberAnimation { duration: 200 } }

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
          NumberAnimation { duration: 140 }
        }
      }
    }
  }

  Timer {
    interval: 160
    running: root.active
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
