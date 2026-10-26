import Quickshell
import Quickshell.Wayland
import QtQuick
import "./modules"
import "./config"
import "./services"

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

  // Output preference comes from Config, so the bar is not tied to one
  // machine's connector names. Unknown names fall through to the next
  // preference, then to whatever output exists.
  screen: {
    var screens = Quickshell.screens
    var prefs = Config.preferredScreens || []
    for (var p = 0; p < prefs.length; p++) {
      for (var i = 0; i < screens.length; i++) {
        if (screens[i].name === prefs[p]) return screens[i]
      }
    }
    return screens.length > 0 ? screens[0] : null
  }

  WlrLayershell.layer: WlrLayer.Overlay

  IdleInhibitor {
    window: root
    enabled: root.idleInhibitEnabled
  }

  // The compositor's corner rounding, read once at startup. Assignments below
  // only exist while the flag is on and the read succeeded, so a machine
  // without hyprctl keeps the tokens exactly as Theme.qml declares them.
  HyprStyleService {
    id: hyprStyle
  }

  Binding {
    target: Theme
    property: "pillEarRadius"
    when: Config.followHyprlandRounding && hyprStyle.known
    value: Math.max(14, Math.min(Theme.pillHeight / 2, hyprStyle.rounding + 4))
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: Theme
    property: "pillBottomRadius"
    when: Config.followHyprlandRounding && hyprStyle.known
    value: Math.max(14, Math.min(Theme.pillHeight / 2, hyprStyle.rounding + 4))
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: Theme
    property: "panelEarRadius"
    when: Config.followHyprlandRounding && hyprStyle.known
    value: Math.max(26, Math.min(44, hyprStyle.rounding * 2 + 6))
    restoreMode: Binding.RestoreNone
  }

  Binding {
    target: Theme
    property: "panelBottomRadius"
    when: Config.followHyprlandRounding && hyprStyle.known
    value: Math.max(26, Math.min(44, hyprStyle.rounding * 2 + 6))
    restoreMode: Binding.RestoreNone
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
