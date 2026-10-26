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
  property bool idleInhibitEnabled: false

  // Display cutout on the output this bar landed on (0 on an ordinary panel).
  // Everything vertical derives from it: the window has to be tall enough to
  // hold the pill below the housing, the reserved strip follows the housing,
  // and the pill is pushed down by exactly that much.
  readonly property int cutout: {
    var map = Config.displayCutouts || {}
    var name = root.screen ? root.screen.name : ""
    var v = Number(map[name])
    return isFinite(v) && v > 0 ? Math.round(v) : 0
  }
  // The strip is the bar's own reserved height pushed down by the housing, not
  // max(reserved, cutout): reserving only the cutout would let the pill overlap
  // the first tiled window by the pill's own height.
  readonly property int reservedHeight: Theme.barReservedHeight + root.cutout

  implicitHeight: root.cutout + 60
  exclusiveZone: root.reservedHeight

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

  PrayerPopup {
    id: prayerPopup
    screen: root.screen
    service: prayerService
  }

  NotificationLayer {
    id: notificationLayer
    screen: root.screen
    topOffset: 8
  }

  NotificationCenter {
    id: notificationCenter
    screen: root.screen
    layer: notificationLayer
  }

  // Prayer alarms live outside the panel on purpose: they have to fire with the
  // UI closed. They borrow the weather card's coordinates so the alarm and the
  // forecast can never describe two different cities.
  PrayerService {
    id: prayerService
    location: floatingHealth.weatherService
  }

  IslandPill {
    id: islandPill
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 0
    topInset: root.cutout
    healthWindow: floatingHealth
    batteryLimitWindow: batteryLimitPopup
    prayerWindow: prayerPopup
    prayerService: prayerService
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
