import Quickshell
import Quickshell.Wayland
import QtQuick
import "./modules"

PanelWindow {
  id: root
  anchors.top: true
  anchors.left: true
  anchors.right: true
  visible: true
  color: "transparent"
  exclusionMode: ExclusionMode.Normal
  aboveWindows: true
  implicitHeight: 60
  exclusiveZone: 38
  property bool idleInhibitEnabled: false

  // Only the visible pill should receive pointer input. Without this mask the
  // transparent remainder of this full-width layer blocks application menus.
  // The drop shape's top corners are cut away, so the rounded region matches
  // the silhouette closely enough for hit-testing.
  mask: Region {
    item: islandPill.inputRegionItem
    radius: islandPill.pillEarRadius
  }

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

  IdleInhibitor {
    window: root
    enabled: root.idleInhibitEnabled
  }

  FloatingHealth {
    id: floatingHealth
    screen: root.screen
    notificationLayer: notificationLayer
    idleInhibitController: root
  }

  BatteryLimitPopup {
    id: batteryLimitPopup
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
    anchors.topMargin: 0
    healthWindow: floatingHealth
    batteryLimitWindow: batteryLimitPopup
    notificationLayer: notificationLayer
    notificationCenter: notificationCenter
  }

  Binding {
    target: floatingHealth
    property: "audioService"
    value: islandPill.audioService
  }

  Binding {
    target: floatingHealth
    property: "batteryService"
    value: islandPill.batteryService
  }

  Binding {
    target: floatingHealth
    property: "brightnessService"
    value: islandPill.sharedBrightnessService
  }

  Binding {
    target: batteryLimitPopup
    property: "batteryService"
    value: islandPill.batteryService
  }

  Binding {
    target: floatingHealth
    property: "networkService"
    value: islandPill.networkService
  }

  Connections {
    target: notificationLayer

    function onMoreClicked() {
      notificationCenter.open()
    }
  }
}
