import QtQuick
import "../config"

Text {
  id: root
  antialiasing: true
  width: Theme.iconSize
  height: Theme.iconSize

  property bool connected: false
  property string type: "wifi"

  font.family: Theme.fontFamily
  font.pixelSize: Theme.iconFontSize
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter

  text: {
    if (!root.connected) return "󰖪"
    if (root.type === "ethernet") return "󰈀"
    return "󰖩"
  }
}