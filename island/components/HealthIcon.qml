import QtQuick
import QtQuick.Layouts
import "."
import "../config"

// Health-panel action glyph: one 16px glyph centred in a 24px slot, like every
// other slot in the pill. The slot size is declared to the layout, not just to
// the text, otherwise the row would be laid out from the glyph's advance
// width and the action icons would drift apart.
Txt {
  id: root
  antialiasing: true
  width: Theme.pillSlot
  height: Theme.pillSlot
  Layout.preferredWidth: Theme.pillSlot
  Layout.preferredHeight: Theme.pillSlot
  elide: Text.ElideNone

  property color iconColor: Theme.foreground

  text: "󰋑"
  color: root.iconColor
  variant: "value"
  font.pixelSize: Theme.pillGlyph
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
}
