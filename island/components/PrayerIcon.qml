import QtQuick
import "."
import "../config"

// The mosque icon of Omarchy's azan plugin, drawn as one glyph.
//
// io.github.ahmadrun.prayer-times (the marketplace entry whose aliases include
// `azan`) puts the bar entry on Material Design Icons' "mosque", U+F1827
// (nf-md-mosque, Apache-2.0, Pictogrammers), and this is that same codepoint
// from the same Nerd Font - the icon the plugin shows, not a redrawing of it.
//
// Its ink is 1000/1000 em wide while its advance is only 600/1000, so the glyph
// overhangs its own cell by a third. Centring the *text box* would therefore
// push the mosque ~3px right inside the 22px slot and clip its right edge, so
// the box is exactly one glyph wide and left-aligned: ink and box then coincide
// and the slot centres the box.
Txt {
  id: root

  width: Theme.pillGlyph
  height: Theme.pillGlyph

  text: "\u{F1827}"
  variant: "body"
  font.pixelSize: Theme.pillGlyph
  color: Theme.foreground

  horizontalAlignment: Text.AlignLeft
  verticalAlignment: Text.AlignVCenter
  elide: Text.ElideNone
}
