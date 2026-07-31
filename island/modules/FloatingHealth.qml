import Quickshell
import Quickshell.Wayland
import QtQuick
import "../config"

PanelWindow {
  id: root
  visible: false
  implicitWidth: root.hpW
  implicitHeight: root.hpH
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  aboveWindows: true

  property int hpW: 340
  property int hpH: 205

  WlrLayershell.layer: WlrLayer.Overlay

  anchors.top: true
  margins.top: 44

  property bool panelActive: false
  property real batteryPower: 0
  property bool batteryCharging: false
  property int batteryCapacity: 0

  Item {
    id: container
    anchors.fill: parent
    opacity: 0

    Behavior on opacity {
      NumberAnimation { duration: 200; easing: Easing.OutQuad }
    }

    Rectangle {
      anchors.fill: parent
      radius: 12
      color: Theme.background
      clip: true
      border.width: 1
      border.color: Theme.selection

      HealthPanel {
        id: healthPanel
        anchors.fill: parent
        active: root.panelActive
        batteryPower: root.batteryPower
        batteryCharging: root.batteryCharging
        batteryCapacity: root.batteryCapacity

        Component.onCompleted: {
          root.hpW = healthPanel.contentWidth
          root.hpH = healthPanel.contentHeight
        }
      }
    }
  }

  function open() {
    root.panelActive = true
    root.visible = true
    container.opacity = 0
    container.opacity = 1
    healthPanel.start()
  }

  function close() {
    container.opacity = 0
    healthPanel.stop()
    root.panelActive = false
    root.visible = false
  }
}