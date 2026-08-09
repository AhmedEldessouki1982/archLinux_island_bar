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
  implicitHeight: 60
  exclusiveZone: 38

  screen: {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === "eDP-1") return screens[i]
    }
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === "eDP-2") return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  WlrLayershell.layer: WlrLayer.Overlay

  FloatingHealth {
    id: floatingHealth
    screen: root.screen
  }

  NotificationLayer {
    id: notificationLayer
    screen: root.screen
  }

  NotificationCenter {
    id: notificationCenter
    screen: root.screen
    layer: notificationLayer
  }

  IslandPill {
    id: islandPill
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 2
    healthWindow: floatingHealth
    notificationLayer: notificationLayer
    notificationCenter: notificationCenter
  }

  Binding {
    target: floatingHealth
    property: "brightnessService"
    value: islandPill.sharedBrightnessService
  }
}
