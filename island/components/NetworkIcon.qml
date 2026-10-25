import QtQuick
import QtQuick.Layouts
import "."
import "../config"

Txt {
  id: root
  antialiasing: true
  width: Theme.pillGlyph
  height: Theme.pillGlyph
  Layout.preferredWidth: Theme.pillGlyph
  Layout.preferredHeight: Theme.pillGlyph
  elide: Text.ElideNone

  property bool connected: false
  property string type: "wifi"
  variant: "body"
  font.pixelSize: Theme.pillGlyph
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter

  text: {
    if (!root.connected) return "󰖪"
    if (root.type === "ethernet") return "󰈀"
    return "󰖩"
  }
}
