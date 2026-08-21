import QtQuick
import QtQuick.Layouts
import "../config"

Item {
  id: root
  width: 56
  height: Theme.iconSize

  property int percent: 100
  property bool charging: false

  RowLayout {
    anchors.fill: parent
    spacing: 4

    Text {
      width: Theme.iconSize
      height: Theme.iconSize
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      Layout.alignment: Text.AlignVCenter
      text: root.charging ? "󰂄" : "󰁹"
      color: root.charging ? Theme.green : (root.percent > 20 ? Theme.foreground : Theme.red)
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconFontSize
    }

    Text {
      width: Theme.iconSize
      height: Theme.iconSize
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      text: Math.round(root.percent) + "%"
      color: root.charging ? Theme.green : root.batteryColor()
      font.family: Theme.fontFamily
      font.pixelSize: 15
      font.bold: true
    }
  }
}