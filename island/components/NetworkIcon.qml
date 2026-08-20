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
    if (!root.connected) return "\uF06B4"
    if (root.type === "ethernet") return "\uF0333"
    return "\uF06A9"
  }
}