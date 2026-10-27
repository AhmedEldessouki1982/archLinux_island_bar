import QtQuick
import QtQuick.Layouts
import "../config"

// Battery group: a 24px slot holding the glyph, then the percentage on the
// same 8px slot gap the tray uses. The same component draws both pill states,
// so the glyph, its slot and its colour cannot drift between them, and the
// percentage is content-sized — it is never given a fixed width, so "100%"
// cannot clip.
//
// The collapsed pill asks for the number alone (`showGlyph: false`). The idle
// body is sized 2 x max(left, right) + clock, so an arm that is wider than the
// other one turns the difference into dead air beside the clock; the workspace
// chip is 22px, the percentage is ~22px, and the glyph pushes the group to
// 53px — which is exactly the gap that used to sit between the chip and the
// time. Hiding the glyph at rest keeps the two arms equal, and it costs
// nothing: the colour still carries the level (red <=10, orange <=20, yellow
// <=35, foreground above, green while charging), and the glyph is back the
// moment the pill opens on hover.
Item {
  id: root

  property var service: null
  property bool showGlyph: true
  property bool showPercent: true
  signal clicked()

  Layout.alignment: Qt.AlignVCenter
  implicitWidth: row.implicitWidth
  implicitHeight: Theme.pillSlot
  // No battery, no group: a desktop or a VM must not read "0%".
  visible: root.service !== null && root.service.battery !== null

  RowLayout {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    spacing: Theme.pillSlotGap

    Item {
      visible: root.showGlyph
      implicitWidth: Theme.pillSlot
      implicitHeight: Theme.pillSlot
      Layout.alignment: Qt.AlignVCenter

      BatteryIcon {
        anchors.centerIn: parent
        width: Theme.pillGlyph
        height: Theme.pillGlyph
        percent: root.service ? root.service.capacity : 0
        charging: root.service ? root.service.charging : false
      }
    }

    Txt {
      visible: root.showPercent
      text: root.service ? Math.round(root.service.capacity) + "%" : ""
      color: root.service
        ? Theme.batteryColor(root.service.capacity, root.service.charging)
        : Theme.comment
      variant: "body"
      Layout.alignment: Qt.AlignVCenter
      elide: Text.ElideNone
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
