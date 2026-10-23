import QtQuick
import QtQuick.Layouts
import "."
import "../config"

Item {
  id: root
  property int percent: 100
  property bool charging: false
  property int glyphNudge: -2
  property bool showPercent: true

  width: root.showPercent ? Theme.pillBatteryWidth : Theme.pillIcon
  height: Theme.pillIcon

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
    return Theme.batteryColor(pct, root.charging);
  }

  RowLayout {
    anchors.centerIn: parent
    spacing: Theme.pillInnerGap

    Item {
      width: Theme.pillIcon
      height: Theme.pillIcon
      Layout.alignment: Qt.AlignVCenter

      Txt {
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
        anchors.verticalCenterOffset: root.glyphNudge
        text: root.batteryGlyph()
        color: root.batteryColor()
        variant: "body"
        elide: Text.ElideNone
      }
    }

    Txt {
      width: Theme.pillBatteryWidth - Theme.pillIcon - Theme.pillInnerGap
      height: parent.height
      Layout.preferredWidth: width
      Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
      visible: root.showPercent
      text: Format.percent(root.percent)
      color: root.batteryColor()
      variant: "body"
      elide: Text.ElideNone
    }
  }
}
