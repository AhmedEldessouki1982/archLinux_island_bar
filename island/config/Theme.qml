pragma Singleton
import QtQuick

QtObject {
  id: root
  property color background: "#282a36"
  property color foreground: "#f8f8f2"
  property color accent: "#bd93f9"
  property color selection: "#44475a"
  property color comment: "#6272a4"
  property color cyan: "#8be9fd"
  property color green: "#50fa7b"
  property color orange: "#ffb86c"
  property color pink: "#ff79c6"
  property color red: "#ff5555"
  property color yellow: "#f1fa8c"

  // Shared telemetry thresholds. Ascending values progress green -> yellow ->
  // orange -> red; battery thresholds are evaluated in reverse.
  readonly property int loadWarning: 55
  readonly property int loadHigh: 75
  readonly property int loadCritical: 90
  readonly property int memoryWarning: 60
  readonly property int memoryHigh: 78
  readonly property int memoryCritical: 90
  readonly property int temperatureWarning: 60
  readonly property int temperatureHigh: 75
  readonly property int temperatureCritical: 88
  readonly property int latencyWarning: 30
  readonly property int latencyHigh: 80
  readonly property int latencyCritical: 150
  readonly property int batteryWarning: 35
  readonly property int batteryLow: 20
  readonly property int batteryCritical: 10

  function ascendingColor(value, warning, high, critical) {
    if (value >= critical) return root.red
    if (value >= high) return root.orange
    if (value >= warning) return root.yellow
    return root.green
  }

  function loadColor(value) {
    return root.ascendingColor(value, root.loadWarning, root.loadHigh, root.loadCritical)
  }

  function memoryColor(value) {
    return root.ascendingColor(value, root.memoryWarning, root.memoryHigh, root.memoryCritical)
  }

  function temperatureColor(value) {
    return root.ascendingColor(value, root.temperatureWarning, root.temperatureHigh, root.temperatureCritical)
  }

  function latencyColor(value) {
    if (value < 0) return root.comment
    return root.ascendingColor(value, root.latencyWarning, root.latencyHigh, root.latencyCritical)
  }

  function batteryColor(value, charging) {
    if (charging) return root.green
    if (value <= root.batteryCritical) return root.red
    if (value <= root.batteryLow) return root.orange
    if (value <= root.batteryWarning) return root.yellow
    return root.green
  }

  function systemColor(load, temperature) {
    var loadSeverity = load >= root.loadCritical ? 3 : load >= root.loadHigh ? 2 : load >= root.loadWarning ? 1 : 0
    var tempSeverity = temperature >= root.temperatureCritical ? 3 : temperature >= root.temperatureHigh ? 2 : temperature >= root.temperatureWarning ? 1 : 0
    var severity = Math.max(loadSeverity, tempSeverity)
    return severity === 3 ? root.red : severity === 2 ? root.orange : severity === 1 ? root.yellow : root.green
  }

  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontSizeLabel: 12
  property int fontSizeTitle: 15
  property int fontSizeValue: 14
  property int fontSizeHero: 20

  property real iconLineWidth: 1.5
  property int iconSize: 16
  property int iconFontSize: 17

  property int animDurationFast: 150
  property int animDurationNormal: 250
  property int animDurationSlow: 350

  property color borderA: Qt.rgba(0.2, 0.8, 1.0, 0.35)
  property color borderB: Qt.rgba(0, 1.0, 0.6, 0.35)

  // Health panel: flat drop-down shape. The top corners are inverted (concave)
  // radii so the surface reads as growing out of the top screen edge; the
  // bottom corners are normal convex radii.
  property int panelEarRadius: 26
  property int panelBottomRadius: 26
  property int panelDropInDuration: 280
  property int panelDropOutDuration: 180
  property color panelBorderA: Qt.rgba(0.55, 0.91, 0.99, 0.28)
  property color panelBorderB: Qt.rgba(0.74, 0.58, 0.98, 0.28)
}
