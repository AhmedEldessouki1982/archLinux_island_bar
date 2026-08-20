import QtQuick
import QtQuick.Layouts
import "../config"

Item {
  id: root
  width: 56
  height: Theme.iconSize

  property int percent: 100
  property bool charging: false

  // ---- battery glyph selection based on percentage & charging ----
  function batteryGlyph() {
    var pct = root.percent;
    if (root.charging) {
      // charging state glyphs
      if (pct >= 80) return "󰂅";   // charging high
      if (pct >= 50) return "󰂂";   // charging medium
      if (pct >= 20) return "󰂁";   // charging low
      return "󰂃";                   // charging critical
    } else {
      // discharging state glyphs
      if (pct >= 100) return "󰂎";  // battery full
      if (pct >= 80) return "󰁹";   // battery high
      if (pct >= 60) return "󰁺";   // battery medium-high
      if (pct >= 40) return "󰁻";   // battery medium
      if (pct >= 30) return "󰁼";   // battery medium-low
      if (pct >= 20) return "󰁾";   // battery low
      if (pct >= 10) return "󰁿";   // battery almost empty
      return "󰂠";                   // battery empty
    }
  }

  function batteryColor() {
    var pct = root.percent;
    if (root.charging) return Theme.green;
    if (pct <= 10) return Theme.red;
    if (pct <= 20) return Theme.orange;
    return Theme.foreground;
  }

  RowLayout {
    anchors.fill: parent
    spacing: 6

    Text {
      id: batteryGlyphText
      width: Theme.iconSize
      height: Theme.iconSize
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      Layout.alignment: Qt.AlignVCenter
      text: root.batteryGlyph()
      color: root.batteryColor()
      font.family: Theme.fontFamily
      font.pixelSize: Theme.iconFontSize
    }

    Text {
      id: percentageText
      width: Theme.iconSize
      height: Theme.iconSize
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      Layout.alignment: Qt.AlignVCenter
      text: Math.round(root.percent) + "%"
      color: root.batteryColor()
      font.family: Theme.fontFamily
      font.pixelSize: 15
    }
  }
}