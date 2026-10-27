import QtQuick
import QtQuick.Layouts
import "../config"

// A 1px rule between two groups of pill slots.
//
// The 12px of air on either side is the parent RowLayout's spacing, so a
// divider is exactly one pixel of ink and never a padded box. It is one
// component for every divider in the pill, which is the only way the gaps in
// the collapsed state and the open state can stay identical.
Item {
  id: root

  Layout.alignment: Qt.AlignVCenter
  Layout.preferredWidth: Theme.pillDividerWidth
  Layout.preferredHeight: Theme.pillSlot
  Layout.fillWidth: false

  Rectangle {
    anchors.centerIn: parent
    width: Theme.pillDividerWidth
    height: Theme.pillDividerHeight
    color: Theme.pillDivider
  }
}
