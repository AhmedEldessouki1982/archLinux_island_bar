import QtQuick
import "."
import "../config"

Txt {
  id: root
  antialiasing: true
  width: Theme.iconSize
  height: Theme.iconSize
  elide: Text.ElideNone

  property color iconColor: Theme.foreground

  text: "󰋑"
  color: root.iconColor
  variant: "body"
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
