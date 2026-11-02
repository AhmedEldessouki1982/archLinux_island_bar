import QtQuick
import "../config"

// The AI glyph for the expanded pill's actions zone, drawn the same way as
// PrayerIcon: one Nerd Font codepoint in a box exactly one glyph wide.
//
// U+F06A9 is nf-md-robot (Material Design Icons, Apache-2.0, Pictogrammers).
Txt {
  id: root

  width: Theme.pillGlyph
  height: Theme.pillGlyph

  text: "\u{F06A9}"
  variant: "body"
  font.pixelSize: Theme.pillGlyph
  color: Theme.foreground

  horizontalAlignment: Text.AlignLeft
  verticalAlignment: Text.AlignVCenter
  elide: Text.ElideNone
}
