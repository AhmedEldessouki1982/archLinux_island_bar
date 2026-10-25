import QtQuick
import QtQuick.Layouts
import "../config"

// Battery group: a 24px slot holding the glyph, then the percentage on the
// same 8px slot gap the tray uses. It is the same component in the collapsed
// and the expanded pill, so the group cannot move or resize when the pill
// opens, and the percentage is content-sized — it is never given a fixed
// width, so "100%" cannot clip.
Item {
  id: root

  property var service: null
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
