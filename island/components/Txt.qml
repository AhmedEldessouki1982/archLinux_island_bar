import QtQuick
import "../config"

Text {
  id: root

  property string variant: "body"
  property bool upper: root.variant === "caption"

  font.family: Theme.fontFamily
  font.pixelSize: root.variant === "caption" ? Theme.fontSizeCaption
    : root.variant === "value" ? Theme.fontSizeValue
    : root.variant === "hero" ? Theme.fontSizeHero : Theme.fontSizeBody
  font.weight: root.variant === "caption" ? Theme.fontWeightCaption
    : root.variant === "hero" || root.variant === "value"
      ? Theme.fontWeightValue : Theme.fontWeightBody
  font.letterSpacing: root.variant === "caption" ? Theme.letterSpacingCaption : 0
  font.capitalization: root.upper ? Font.AllUppercase : Font.MixedCase
  color: root.variant === "caption" ? Theme.label : Theme.foreground
  elide: Text.ElideNone
  clip: true
}
