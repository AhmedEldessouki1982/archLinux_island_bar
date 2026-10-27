import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import "../config"

// The tray is a row of uniform slots, not a capsule: every item gets the same
// 24x24 hit area with a 16px glyph centred inside it, so a wide icon and a
// narrow one cannot shift their neighbours or change the slot pitch.
RowLayout {
  id: root

  spacing: Theme.pillSlotGap
  Layout.alignment: Qt.AlignVCenter
  visible: repeater.count > 0

  Repeater {
    id: repeater
    model: SystemTray.items

    delegate: Item {
      id: slot
      required property var modelData

      implicitWidth: Theme.pillSlot
      implicitHeight: Theme.pillSlot
      Layout.alignment: Qt.AlignVCenter

      Image {
        anchors.centerIn: parent
        source: slot.modelData.icon
        width: Theme.pillGlyph
        height: Theme.pillGlyph
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Theme.pillGlyph
        sourceSize.height: Theme.pillGlyph
      }

      QsMenuAnchor {
        id: trayMenu
        anchor.item: slot
        menu: slot.modelData.menu
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function(mouse) {
          if (mouse.button === Qt.RightButton) {
            if (slot.modelData.hasMenu)
              trayMenu.open()
          } else {
            slot.modelData.activate()
          }
        }
      }
    }
  }
}
