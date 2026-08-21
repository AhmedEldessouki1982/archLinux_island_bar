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
      if (pct >= 80) return "󰂅";
      if (pct >= 50) return "󰂂";
      if (pct >= 20) return "󰂁";
      return "󰂃";
    } else {
      if (pct >= 100) return "󰂎";
      if (pct >= 80) return "󰁹";
      if (pct >= 60) return "󰁺";
      if (pct >= 40) return "󰁻";
      if (pct >= 30) return "󰁼";
      if (pct >= 20) return "󰁾";
      if (pct >= 10) return "󰁿";
      return "󰂠";
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
    spacing: 4

    Text {
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