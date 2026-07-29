import Quickshell
import Quickshell.Wayland
import QtQuick
import "./modules"

PanelWindow {
  id: root
  anchors.top: true
  anchors.left: true
  anchors.right: true
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  aboveWindows: true
  implicitHeight: 38
  exclusiveZone: 38

  WlrLayershell.layer: WlrLayer.Overlay

  FloatingHealth {
    id: floatingHealth
  }

  IslandPill {
    id: islandPill
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 2
    healthWindow: floatingHealth
  }
}
