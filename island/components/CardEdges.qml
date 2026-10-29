import QtQuick
import "../config"

Item {
  id: root
  anchors.fill: parent
  z: 10
  clip: false

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: Theme.cardRadius
    anchors.rightMargin: Theme.cardRadius
    anchors.topMargin: Theme.cardBorderWidth
    height: Theme.cardBorderWidth
    color: Theme.cardHighlight
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: Theme.cardRadius
    anchors.rightMargin: Theme.cardRadius
    anchors.bottomMargin: Theme.cardBorderWidth
    height: Theme.cardBorderWidth
    color: Theme.cardEdgeDark
  }
}
