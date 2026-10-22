import QtQuick
import "."
import "../config"

Txt {
  id: root
  antialiasing: true
  width: Theme.iconSize
  height: Theme.iconSize
  elide: Text.ElideNone

  property bool connected: false
  property string type: "wifi"
  variant: "body"
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter

  text: {
    if (!root.connected) return "󰖪"
    if (root.type === "ethernet") return "󰈀"
    return "󰖩"
  }
}
