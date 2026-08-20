import QtQuick
import "../config"

Text {
  id: root
  antialiasing: true
  width: Theme.iconSize
  height: Theme.iconSize

  property color iconColor: Theme.foreground

  text: "\uF08D2"
  color: root.iconColor
  font.family: Theme.fontFamily
  font.pixelSize: Theme.iconFontSize
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}