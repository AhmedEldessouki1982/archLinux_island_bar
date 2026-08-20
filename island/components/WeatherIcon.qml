import QtQuick
import "../config"

Text {
  id: root
  antialiasing: true
  width: Theme.iconSize
  height: Theme.iconSize

  property int weatherCode: 0

  font.family: Theme.fontFamily
  font.pixelSize: Theme.iconFontSize
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter

  text: {
    if (root.weatherCode === 0) return "\uF0651"
    if (root.weatherCode <= 3) return "\uF0625"
    if (root.weatherCode === 45 || root.weatherCode === 48) return "\uF0631"
    if ((root.weatherCode >= 51 && root.weatherCode <= 67) ||
        (root.weatherCode >= 80 && root.weatherCode <= 82)) return "\uF0645"
    if (root.weatherCode >= 71 && root.weatherCode <= 77) return "\uF0649"
    if (root.weatherCode >= 95 && root.weatherCode <= 99) return "\uF0634"
    return "\uF0633"
  }

  color: {
    if (root.weatherCode === 0 || root.weatherCode <= 3) return Theme.yellow
    if (root.weatherCode === 45 || root.weatherCode === 48) return Theme.foreground
    if ((root.weatherCode >= 51 && root.weatherCode <= 67) ||
        (root.weatherCode >= 80 && root.weatherCode <= 82) ||
        (root.weatherCode >= 71 && root.weatherCode <= 77)) return Theme.cyan
    if (root.weatherCode >= 95 && root.weatherCode <= 99) return Theme.yellow
    return Theme.foreground
  }
}