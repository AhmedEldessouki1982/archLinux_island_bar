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

  Row {
    anchors.centerIn: parent
    spacing: Theme.gapTight

    GlyphIcon {
      width: Theme.toggleIconSize
      height: Theme.toggleIconSize
      iconType: root.iconType
      active: root.active
      strokeColor: root.active ? Theme.accent : Theme.label
    }

    Txt {
      width: Math.max(0, root.width - Theme.toggleChipPadX * 2 - Theme.toggleIconSize - Theme.gapTight - (root.badge > 0 ? Theme.toggleBadgeSize : 0))
      height: Theme.fontSizeCaption + 2
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignLeft
      text: root.label
      color: root.active ? Theme.accent : Theme.label
      variant: "caption"
      elide: Text.ElideNone
      clip: true
    }

    Rectangle {
      visible: root.badge > 0
      width: Theme.toggleBadgeSize
      height: Theme.toggleBadgeSize
      radius: Theme.toggleBadgeSize / 2
      color: root.active ? Theme.accent : Theme.selection
      anchors.verticalCenter: parent.verticalCenter
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
