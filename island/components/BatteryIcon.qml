import QtQuick
import QtQuick.Layouts
import "../config"

Item {
  id: root
  width: 56
  height: Theme.iconSize

  property int percent: 100
  property bool charging: false
  property color fillColor: root.charging ? Theme.green : (root.percent > 20 ? Theme.foreground : Theme.red)

  RowLayout {
    anchors.fill: parent
    spacing: 6

    Text {
      width: Theme.iconSize
      height: Theme.iconSize
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      Layout.alignment: Qt.AlignVCenter
      text: root.charging ? "󰂄" : "󰁹"
      color: root.fillColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconFontSize
    }

    Text {
      width: Theme.iconSize
      height: Theme.iconSize
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      Layout.alignment: Qt.AlignVCenter
      text: Math.round(root.percent) + "%"
      color: root.fillColor
      font.family: Theme.fontFamily
      font.pixelSize: 15
    }
  }
}