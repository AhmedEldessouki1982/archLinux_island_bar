import QtQuick
import "."
import "../config"

// The battery glyph on its own.
//
// The percentage lives beside it in PillBattery, so the glyph and the number
// can never disagree about the value or the colour — the old component carried
// its own copy of both inside a fixed-width row that clipped "100%".
Txt {
  id: root

  property int percent: 100
  property bool charging: false

  width: Theme.pillGlyph
  height: Theme.pillGlyph

  // ---- glyph selection based on percentage & charging ----
  function batteryGlyph() {
    var pct = root.percent
    if (root.charging) {
      if (pct >= 80) return "󰂅"
      if (pct >= 50) return "󰂂"
      if (pct >= 20) return "󰂁"
      return "󰂃"
    }
    if (pct >= 100) return "󰂎"
    if (pct >= 80) return "󰁹"
    if (pct >= 60) return "󰁺"
    if (pct >= 40) return "󰁻"
    if (pct >= 30) return "󰁼"
    if (pct >= 20) return "󰁾"
    if (pct >= 10) return "󰁿"
    return "󰂠"
  }

  text: root.batteryGlyph()
  color: Theme.batteryColor(root.percent, root.charging)

  variant: "body"
  font.pixelSize: Theme.pillGlyph
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
  elide: Text.ElideNone
}
