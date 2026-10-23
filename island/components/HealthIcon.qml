import QtQuick
import "."
import "../config"

Txt {
  id: root
  antialiasing: true
  width: Theme.pillIcon
  height: Theme.pillIcon
  elide: Text.ElideNone

  property color iconColor: Theme.foreground

  text: "󰋑"
  color: root.iconColor
  variant: "body"
  font.pixelSize: Theme.iconFontSize
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
