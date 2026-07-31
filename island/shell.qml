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

  screen: {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === "eDP-1") return screens[i]
    }
    return null
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

  CalendarPopup {
    id: calendarPopup
    screen: root.screen
  }

  IslandPill {
    id: islandPill
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: 2
    healthWindow: floatingHealth
    notificationLayer: notificationLayer
    notificationCenter: notificationCenter
    calendarPopup: calendarPopup
  }
}
