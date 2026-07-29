import QtQuick
import "../config"

Rectangle {
  id: root
  width: 10
  height: 10
  radius: 5

  property bool active: false
  property color activeColor: Theme.accent
  property color inactiveColor: Theme.selection

  color: root.active ? root.activeColor : root.inactiveColor

  Behavior on color {
    ColorAnimation { duration: 150 }
  }
}
