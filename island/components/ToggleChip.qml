import QtQuick
import QtQuick.Controls
import "."
import "../config"

Rectangle {
  id: root

  property string iconType: "moon"
  property string label: ""
  property string tooltip: ""
  property int badge: 0
  property bool active: false
  signal toggled()

  radius: Theme.chipRadius
  color: mouseArea.containsMouse ? Theme.cardHoverFill
    : (root.active ? Theme.activeTint : Theme.cardFill)
  border.width: Theme.cardBorderWidth
  border.color: root.active ? Theme.accent : Theme.cardBorderColor
  antialiasing: true

  // One 18px glyph slot on the chip's optical centre line: the icon, the label
  // and the badge are all centred inside it. A bare Text in a Row sits on the
  // row's top edge, which is what put the label 4px above the icon.
  Row {
    anchors.centerIn: parent
    height: Theme.toggleIconSize
    spacing: Theme.gapTight

    GlyphIcon {
      width: Theme.toggleIconSize
      height: Theme.toggleIconSize
      iconType: root.iconType
      active: root.active
      strokeColor: root.active ? Theme.accent : Theme.label
    }

    Item {
      width: Math.max(0, root.width - Theme.toggleChipPadX * 2 - Theme.toggleIconSize
        - Theme.gapTight - (root.badge > 0 ? Theme.toggleBadgeSize : 0))
      height: Theme.toggleIconSize

      Txt {
        width: parent.width
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignLeft
        text: root.label
        color: root.active ? Theme.accent : Theme.label
        variant: "caption"
        elide: Text.ElideNone
        clip: true
      }
    }

    Item {
      visible: root.badge > 0
      width: Theme.toggleBadgeSize
      height: Theme.toggleIconSize

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.toggleBadgeSize
        height: Theme.toggleBadgeSize
        radius: Theme.toggleBadgeSize / 2
        color: root.active ? Theme.accent : Theme.selection

        Txt {
          anchors.fill: parent
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: root.badge > 9 ? "9+" : String(root.badge)
          variant: "caption"
          upper: false
          color: root.active ? Theme.background : Theme.foreground
        }
      }
    }
  }

  HoverHandler {
    id: hoverHandler
  }

  ToolTip.visible: hoverHandler.hovered && root.tooltip.length > 0
  ToolTip.text: root.tooltip
  ToolTip.delay: Theme.tooltipDelay

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: false
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled()
  }
}
