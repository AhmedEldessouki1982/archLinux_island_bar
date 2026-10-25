import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../config"

// One workspace slot: a fixed 22x22 cell drawn the same way in the collapsed
// pill (a single slot, showing the workspace you are on) and in the expanded
// pill (slots 1..10).
//
//   * active   — filled accent pill, number in the background colour
//   * occupied — number in the foreground colour plus a dot underneath
//   * empty    — number dimmed to `comment`
//   * hover    — lighter flat fill, never a glow
//
// `activeFill` exists because the expanded strip draws one shared accent pill
// that slides between slots (a per-slot rectangle cannot animate across slot
// boundaries). The idle slot has no strip, so it keeps its own fill.
Item {
  id: root

  required property int workspaceId
  property bool activeFill: true

  implicitWidth: Theme.wsSlot
  implicitHeight: Theme.wsSlot

  readonly property var workspaceObject: {
    if (workspaceId <= 0) return null
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++)
      if (values[i].id === workspaceId) return values[i]
    return null
  }
  readonly property bool occupied: workspaceObject && workspaceObject.toplevels
    ? workspaceObject.toplevels.values.length > 0 : false
  readonly property bool isActive: Hyprland.focusedWorkspace
    && Hyprland.focusedWorkspace.id === workspaceId
  readonly property int slotNumber: workspaceId > 0 ? ((workspaceId - 1) % 10) + 1 : 0
  readonly property string label: slotNumber > 0 ? String(slotNumber) : ""

  // Switching to a workspace that already exists needs no process at all.
  // An empty slot has no workspace object yet, so it is created through
  // Hyprland's own dispatcher (Lua syntax, as Hyprland 0.5x expects).
  function activate() {
    if (workspaceObject) {
      workspaceObject.activate()
      return
    }
    Hyprland.dispatch("hl.dsp.focus({ workspace = \"" + workspaceId + "\" })")
  }

  HoverHandler { id: hover }

  Rectangle {
    anchors.fill: parent
    radius: Theme.wsRadius
    color: Theme.cardHoverFill
    visible: hover.hovered && !root.isActive
  }

  Rectangle {
    anchors.fill: parent
    radius: Theme.wsRadius
    color: Theme.accent
    visible: root.activeFill && root.isActive
  }

  Txt {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: root.occupied ? -1 : 0
    width: parent.width
    text: root.label
    variant: "body"
    color: root.isActive ? Theme.background
      : root.occupied ? Theme.foreground : Theme.comment
    opacity: root.isActive || root.occupied ? 1 : 0.55
    font.letterSpacing: root.slotNumber === 10 ? Theme.wsCondensedTracking : 0
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideNone
  }

  Rectangle {
    visible: root.occupied
    width: Theme.wsDotSize
    height: Theme.wsDotSize
    radius: width / 2
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 3
    color: root.isActive ? Theme.background : Theme.accent
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activate()
  }
}
