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

  // Health panel bento grid (layout only; tokens defined in Theme).
  // More readable muted text while staying in the Dracula palette.
  property color mutedText: "#a6b0e0"
  property color sectionLabel: "#c9d1ff"
  property color labelText: "#d0d8ff"
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
  // Disk bands read a little tighter than the other telemetry: a nearly full
  // filesystem is a real problem well before 90%.
  readonly property int diskWarning: 70
  readonly property int diskHigh: 85
  readonly property int diskCritical: 93

  // Health panel bento grid
  readonly property int gridUnit: 56
  readonly property int gridGutter: 10
  readonly property int cardRadius: 8
  readonly property int cardPadding: 10
  // 12-column layout widths sum to fit the panel; body width used by DropShape.
  readonly property int bentoBodyWidth: 900

  // Opaque bento palette. The panel surface is one flat colour, so every card
  // is a solid shade lighter than it plus a low-contrast 1px border. Nothing
  // in the panel is translucent, which keeps the layout readable on top of
  // any wallpaper.
  readonly property color cardFill: "#313445"
  readonly property color cardBorderColor: "#3d4258"

  // Storage ring gauges: diameter bounds, in pixels.
  readonly property int ringMinSize: 28
  readonly property int ringMaxSize: 132

  // Storage "used / total" caption: derived from the cell width, clamped.
  readonly property int storageTextMinFont: 9
  readonly property int storageTextMaxFont: 12

  // Narrowest a storage cell may get before the grid drops to two rows.
  readonly property int storageCellMinWidth: 72

  // Weather condition word: normal size, plus the fallback used when the
  // string does not fit the available width.
  readonly property int fontSizeCondition: 14
  readonly property int fontSizeConditionSmall: 11

  // Typography scales (one monospace font; use only these sizes)
  readonly property int fontSizeMicro: 9
  readonly property int fontSizeTiny: 10
  readonly property int fontSizeLabel: 10
  readonly property int fontSizeValue: 15
  readonly property int fontSizeTitle: 15
  readonly property int fontSizeHero: 30

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

  function diskColor(value) {
    if (value < 0) return root.comment
    // spec: green < 70, yellow 70-85, orange 85-93, red > 93
    if (value > root.diskCritical) return root.red
    if (value > root.diskHigh) return root.orange
    if (value >= root.diskWarning) return root.yellow
    return root.green
  }

  // Filesystems shown as ring gauges in display order.
  property var diskMounts: [
    { "mount": "/", "label": "ROOT" },
    { "mount": "/home", "label": "HOME" },
    { "mount": "/mnt/data", "label": "DATA" }
  ]

  property string fontFamily: "JetBrainsMono Nerd Font"
  property int fontSizeIcon: 17

  property real iconLineWidth: 1.5
  property int iconSize: 16
  property int iconFontSize: 17

  property int animDurationFast: 150
  property int animDurationNormal: 250
  property int animDurationSlow: 350

  property color borderA: Qt.rgba(0.2, 0.8, 1.0, 0.35)
  property color borderB: Qt.rgba(0, 1.0, 0.6, 0.35)

  // Drop shapes. Both the island pill and the health panel use the same
  // DropShape component, so their silhouette is identical by construction;
  // only the radii differ. Top corners are concave (inverted) so the surface
  // reads as hanging from the top screen edge; bottom corners are convex.
  property int panelEarRadius: 26
  property int panelBottomRadius: 26
  property int pillEarRadius: 14
  property int pillBottomRadius: 14

  property int panelDropInDuration: 280
  property int panelDropOutDuration: 180

  // One content inset for the panel, applied identically on all four sides.
  // Kept at least earRadius + 8 so no content ever touches the top curves,
  // and so the bottom padding matches the top.
  readonly property int contentPadding: panelEarRadius + 8

  // A ShapePath stroke takes a single colour, so the old cyan->purple gradient
  // is expressed as one low-alpha blend of the two ends of that ramp.
  readonly property color shapeBorder: Qt.rgba(0.64, 0.75, 0.985, 0.30)

  // Kept for any callers that still reference the old gradient pair.
  property color panelBorderA: Qt.rgba(0.55, 0.91, 0.99, 0.28)
  property color panelBorderB: Qt.rgba(0.74, 0.58, 0.98, 0.28)
}
