pragma Singleton
import QtQuick

// Design tokens for the Quickshell island.
//
// Everything the health panel draws — every size, every colour, every weight —
// is defined here. No other file is allowed to contain a pixel, a hex literal
// or a font size of its own: the panel is generated from these tokens, so the
// grid, the type scale and the palette cannot drift apart.
//
// The compact health panel is built on a 36px unit grid:
//   * a card that spans n units is n * unit + (n - 1) * gutter tall
//   * every column is exactly `columnUnits` units tall, so all three columns
//     end on the same line by construction
//   * the window is bodyWidth + 2 * panelPadding + 2 * panelEarRadius wide
//     and columnHeight + 2 * panelPadding tall
QtObject {
  id: root

  // ===========================================================================
  // Palette — Dracula, flat and opaque
  // ===========================================================================

  property color background: "#282a36"
  property color foreground: "#f8f8f2"

  // Purple marks an active/selected state and fills sliders;
  // green/yellow/orange/red mark a threshold or a warning. Nothing else.
  property color accent: "#bd93f9"
  property color green: "#50fa7b"
  property color yellow: "#f1fa8c"
  property color orange: "#ffb86c"
  property color red: "#ff5555"
  readonly property color weatherCity: root.red
  readonly property color chargeLimitActive: root.red

  // One muted lavender for every card label in the health panel.
  // Contrast against cardFill: 4.98:1 (WCAG AA needs 4.5:1).
  readonly property color label: "#a49bee"

  // Dimmed text (unavailable values, idle states). This is deliberately a
  // darker step of the same lavender so secondary text stays behind a label
  // instead of reading as one: 3.61:1 on cardFill, 4.18:1 on background.
  // Only values that are absent or inactive use it — never information the
  // reader needs right now.
  readonly property color comment: "#8b85bb"

  // Slider track / inactive chip fill.
  property color selection: "#44475a"

  // Opaque card surface: one flat colour plus a low contrast 1px border.
  readonly property color cardFill: "#313445"
  readonly property color cardBorderColor: "#3d4258"
  readonly property color cardHoverFill: "#3a3e52"
  readonly property color activeTint: "#383548"
  readonly property color chargeLimitActiveTint: "#4b313a"
  readonly property color transparent: "transparent"

  // ===========================================================================
  // Grid — the compact panel is laid out on a 36px unit
  // ===========================================================================

  readonly property int gridUnit: 36
  readonly property int gridGutter: 8

  // Inset of the content inside the panel body, on all four sides.
  readonly property int panelPadding: 12

  // Card insets. Three variants, all declared here so no card invents one:
  //   standard — 10px on both axes
  //   dense    — 4px / 3px, for cards whose content is taller than one unit
  //   flush    — 10px / 0px, for one-unit cards that stack two text lines
  readonly property int cardPadX: 10
  readonly property int cardPadY: 10
  readonly property int cardPadXDense: 4
  readonly property int cardPadYDense: 3
  readonly property int cardPadXFlush: 10
  readonly property int cardPadYFlush: 0

  readonly property int cardRadius: 10
  readonly property int cardBorderWidth: 1

  // Spacing steps. The grid gutter (8px) is the default rhythm; these are
  // the smaller and larger steps used inside a card.
  readonly property int gapTight: 4
  readonly property int gapSmall: 6
  readonly property int gapMedium: 10
  readonly property int gapWide: 14

  // Column widths and the unit count that every column must reach.
  readonly property int columnLeftWidth: 196
  readonly property int columnMiddleWidth: 232
  readonly property int columnRightWidth: 196
  readonly property int columnUnits: 11

  // Derived body geometry: 196 + 232 + 196 + two 8px gutters = 640px of
  // columns, and 11 units + 10 gutters = 476px of height.
  readonly property int bodyWidth: columnLeftWidth + columnMiddleWidth
    + columnRightWidth + gridGutter * 2
  readonly property int columnHeight: columnUnits * gridUnit
    + (columnUnits - 1) * gridGutter
  // DropShape adds one ear radius at each side around the padded card body.
  readonly property int panelWidth: bodyWidth + panelPadding * 2 + panelEarRadius * 2
  readonly property int panelHeight: columnHeight + panelPadding * 2

  // ===========================================================================
  // Typography — one monospace family, exactly four sizes
  // ===========================================================================

  property string fontFamily: "JetBrainsMono Nerd Font"

  // caption: 10px / 600 / uppercase / 1px tracking / muted lavender
  readonly property int fontSizeCaption: 10
  readonly property int fontWeightCaption: 600
  readonly property real letterSpacingCaption: 1.0

  // body: 12px / regular / foreground
  readonly property int fontSizeBody: 12
  readonly property int fontWeightBody: 400

  // value: 15px / 700 / foreground (or a threshold colour)
  readonly property int fontSizeValue: 15
  readonly property int fontWeightValue: 700

  // hero: 24px / 700 — the clock and the battery percentage, nothing else
  readonly property int fontSizeHero: 24
  readonly property int fontWeightHero: 700

  // Every text in the shell draws from the four steps above through the Txt
  // primitive. There is no fifth size.

  // ===========================================================================
  // Component sizes
  // ===========================================================================

  // Storage rings never scale with the card.
  readonly property int ringDiameter: 64
  readonly property int ringThickness: 5

  // Sparkline inside the CPU and GPU cards.
  readonly property int sparklineHeight: 36
  readonly property color graphLow: root.accent
  readonly property int graphSampleCount: 60
  readonly property int graphSampleInterval: 1000
  readonly property int graphBorderWidth: 1
  readonly property int graphInset: 2
  readonly property real graphLineWidth: 1.5
  readonly property color graphGrid: "#263a3e52"

  // Calendar day rows.
  readonly property int calendarRowHeight: 24

  // Slider track.
  readonly property int sliderTrackHeight: 4
  readonly property int sliderTrackRadius: 2

  // Weather glyph and the toggle icons.
  readonly property int weatherGlyphSize: 40
  readonly property int toggleIconSize: 18
  readonly property int toggleChipPadX: 3
  readonly property real toggleIconLineWidth: 1.6
  readonly property int tooltipDelay: 500
  readonly property int hoverCollapseDelay: 180
  readonly property int healthPanelAutoCloseMs: 15000
  readonly property int notificationActionWidth: 84
  readonly property int speakerIconSize: 14
  readonly property int chevronIconSize: 12

  // Toggle chips (DND / AWAKE / BT) and the charge limit chips.
  readonly property int chipRadius: 6
  readonly property int chipPadX: 6
  readonly property int chipHeight: 26
  readonly property int pillGap: 12
  readonly property int pillInnerGap: 8
  readonly property int pillActionGap: 10
  readonly property int pillHeight: 32
  readonly property int pillIcon: 16
  readonly property int pillActionIcon: 19
  readonly property int pillActionSlot: 24
  readonly property int pillPaddingLeft: 12
  readonly property int pillPaddingRight: 12
  readonly property int pillWorkspaceCell: 20
  readonly property int pillWorkspaceHeight: 20
  readonly property int pillWorkspaceGap: 2
  readonly property int pillMinWidth: 150
  readonly property int pillTitleMaxWidth: 300
  readonly property int pillDividerWidth: 1
  readonly property color pillDivider: "#50566b"
  readonly property int trayIconSize: 18
  readonly property int toggleBadgeSize: 12

  // Calendar: a day cell is a square highlight behind the number.
  readonly property int calendarCellSize: 20
  readonly property int calendarCellRadius: 6

  // Segmented battery bar.
  readonly property int batteryBarSegments: 10
  readonly property int batteryBarHeight: 8
  readonly property int batteryBarGap: 2
  readonly property int batteryBarRadius: 2

  // Fixed column widths inside cards.
  readonly property int procCpuColWidth: 38
  readonly property int procRamColWidth: 38
  readonly property int metricValueWidth: 40
  readonly property int compactCaptionWidth: 28
  readonly property int networkGlyphWidth: 16
  readonly property int weatherSunColWidth: 50
  readonly property int monthArrowHitSize: 16
  readonly property int pillWorkspaceWidth: 24
  readonly property int pillTimeWidth: 44
  readonly property int pillDateWidth: 92
  readonly property int pillBatteryWidth: 42
  readonly property int pillIpMaxWidth: 140
  readonly property int pillMeterMaxWidth: 80
  readonly property int chargeLimitLabelWidth: 92
  readonly property int chargeLimitValueWidth: 48
  readonly property int chargePopupWidth: 286
  readonly property int chargePopupRowHeight: 44
  readonly property int chargePopupGap: 8
  readonly property int chargePopupPad: 12
  readonly property int chargePopupOffset: 8
  readonly property int chargeRadioSize: 14
  readonly property int chargeRadioDot: 6
  readonly property int fanLabelWidth: 34
  readonly property int fanHeaderHeight: 12
  readonly property int fanLineHeight: 18
  readonly property int ramBarHeight: 4

  // One control row (VOL / BRI): label slot, icon slot, value slot.
  readonly property int controlRowHeight: 22
  readonly property int controlLabelWidth: 28
  readonly property int controlIconWidth: 20
  readonly property int controlValueWidth: 34

  // Right aligned latency column in the network card ("999ms").
  readonly property int latencyColWidth: 44

  // Icon sizes used by the island pill.
  property int iconSize: 16
  property int iconFontSize: 15
  property real iconLineWidth: 1.5

  // ===========================================================================
  // Thresholds
  // ===========================================================================

  readonly property int loadWarning: 40
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

  // Green for healthy, then yellow / orange / red.
  function ascendingColor(value, warning, high, critical) {
    if (value >= critical) return root.red
    if (value >= high) return root.orange
    if (value >= warning) return root.yellow
    return root.green
  }

  // The same ramp, but a healthy value stays in the foreground colour: text
  // only turns into an accent when there is something to report.
  function stateColor(value, warning, high, critical) {
    if (value >= critical) return root.red
    if (value >= high) return root.orange
    if (value >= warning) return root.yellow
    return root.foreground
  }

  function loadColor(value) {
    return root.stateColor(value, root.loadWarning, root.loadHigh, root.loadCritical)
  }

  function graphColor(value) {
    return value >= root.loadWarning ? root.loadColor(value) : root.accent
  }

  function memoryColor(value) {
    return root.stateColor(value, root.memoryWarning, root.memoryHigh, root.memoryCritical)
  }

  function temperatureColor(value) {
    return root.stateColor(value, root.temperatureWarning, root.temperatureHigh, root.temperatureCritical)
  }

  function latencyColor(value) {
    if (value < 0) return root.comment
    return root.stateColor(value, root.latencyWarning, root.latencyHigh, root.latencyCritical)
  }

  function batteryColor(value, charging) {
    if (charging) return root.green
    if (value <= root.batteryCritical) return root.red
    if (value <= root.batteryLow) return root.orange
    if (value <= root.batteryWarning) return root.yellow
    return root.foreground
  }

  function diskColor(value) {
    if (value < 0) return root.comment
    // spec: green < 70, yellow 70-85, orange 85-93, red > 93
    if (value > root.diskCritical) return root.red
    if (value > root.diskHigh) return root.orange
    if (value >= root.diskWarning) return root.yellow
    return root.green
  }

  // Storage meters follow the same rule as every other value in the panel: a
  // healthy filesystem is plain foreground, and only a filling one turns into
  // an accent. The ring, its label and its numbers all read from this one
  // function so a cell can never disagree with itself.
  function storageColor(value) {
    if (value < 0) return root.comment
    return root.diskColor(value)
  }

  // Filesystems shown as ring gauges in display order.
  property var diskMounts: [
    { "mount": "/", "label": "ROOT" },
    { "mount": "/home", "label": "HOME" },
    { "mount": "/mnt/data", "label": "DATA" }
  ]

  // ===========================================================================
  // Motion and shape
  // ===========================================================================

  property int animDurationFast: 150
  property int animDurationNormal: 250
  property int animDurationSlow: 350

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

  // A ShapePath stroke takes a single colour, so the old cyan->purple gradient
  // is expressed as one low-alpha blend of the two ends of that ramp.
  readonly property color shapeBorder: Qt.rgba(0.64, 0.75, 0.985, 0.30)
}
