import QtQuick
import "."
import "../config"

Txt {
  id: root
  antialiasing: true
  width: Theme.pillActionSlot
  height: Theme.pillActionSlot
  elide: Text.ElideNone

  property color iconColor: Theme.foreground

  text: "󰋑"
  color: root.iconColor
  variant: "value"
  font.pixelSize: Theme.pillActionIcon
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
