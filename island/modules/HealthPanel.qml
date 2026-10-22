import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../config"
import "../components"
import "../services"

// Health panel — 12 column bento grid.
//
// The grid is a single row of three columns whose spans are 3 / 5 / 4 of the
// twelve grid columns. Every card height is derived from the grid unit, and
// the panel height is the height of the tallest column, so all three columns
// always end on exactly the same baseline and no empty strip is left under a
// column. The cards that are allowed to grow (top processes, weather, storage)
// absorb whatever the tallest column leaves over.
Item {
  id: root

  property bool active: false
  signal userActivity()

  property real cpuLoad: 0
  property real cpuTemp: 0
  property int cpuCount: 1
  property real ramUsed: 0
  property real ramTotal: 0
  property real ramPercent: 0
  property real gpuTemp: 0
  property real gpuLoad: 0
  property real cpuFanSpeed: 0
  property real gpuFanSpeed: 0
  property real netRxRate: 0
  property real netTxRate: 0
  property string wifiSsid: ""
  property real batteryPower: 0
  property bool batteryCharging: false
  property bool batteryOnAc: false
  property int batteryCapacity: 0
  property string gpuMode: ""
  property string gpuPowerStatus: ""
  property string powerProfile: ""
  property string kernelVersion: ""
  property string userName: ""
  property string hostName: ""
  property bool gpuConfirming: false
  property string pendingGpuMode: ""

  property var audioService: null
  property var brightnessService: null
  property var batteryService: null
  property var weatherService: null
  property var networkService: null
  property var systemStatsService: null
  property var thermalService: null
  property var gpuModeService: null
  property var processStatsService: null
  property var updateService: null
  property var storageService: null
  property var notificationLayer: null
  property var idleInhibitController: null

  onBatteryServiceChanged: {
    if (root.batteryService) {
      root.batteryCapacity = Qt.binding(() => root.batteryService.capacity)
      root.batteryCharging = Qt.binding(() => root.batteryService.charging)
      root.batteryOnAc = Qt.binding(() => root.batteryService.onAcPower)
      root.batteryPower = Qt.binding(() => root.batteryService.power)
    }
  }
  onSystemStatsServiceChanged: {
    if (root.systemStatsService) {
      root.cpuCount = Qt.binding(() => root.systemStatsService.cpuCount)
      root.cpuLoad = Qt.binding(() => root.systemStatsService.cpuLoad)
      root.ramUsed = Qt.binding(() => root.systemStatsService.ramUsed)
      root.ramTotal = Qt.binding(() => root.systemStatsService.ramTotal)
      root.ramPercent = Qt.binding(() => root.systemStatsService.ramPercent)
      root.kernelVersion = Qt.binding(() => root.systemStatsService.kernelVersion)
      root.userName = Qt.binding(() => root.systemStatsService.userName)
      root.hostName = Qt.binding(() => root.systemStatsService.hostName)
    }
  }
  onThermalServiceChanged: {
    if (root.thermalService) {
      root.cpuTemp = Qt.binding(() => root.thermalService.cpuTemp)
      root.cpuFanSpeed = Qt.binding(() => root.thermalService.cpuFanSpeed)
      root.gpuFanSpeed = Qt.binding(() => root.thermalService.gpuFanSpeed)
      root.gpuTemp = Qt.binding(() => root.thermalService.gpuTemp)
      root.gpuLoad = Qt.binding(() => root.thermalService.gpuLoad)
    }
  }
  onGpuModeServiceChanged: {
    if (root.gpuModeService) {
      root.gpuMode = Qt.binding(() => root.gpuModeService.gpuMode)
      root.gpuPowerStatus = Qt.binding(() => root.gpuModeService.gpuPowerStatus)
      root.powerProfile = Qt.binding(() => root.gpuModeService.powerProfile)
    }
  }
  onNetworkServiceChanged: {
    if (root.networkService) {
      root.netRxRate = Qt.binding(() => root.networkService.rxRate)
      root.netTxRate = Qt.binding(() => root.networkService.txRate)
      root.wifiSsid = Qt.binding(() => root.networkService.ssid)
    }
  }

  // ===========================================================================
  // Grid geometry
  // ===========================================================================

  readonly property real g: Theme.gridUnit
  readonly property real gut: Theme.gridGutter
  readonly property real cp: Theme.cardPadding

  // Twelve grid columns. A column of the bento spans 3 / 5 / 4 of them, so the
  // proportions come from the ratio and never from a pixel constant.
  readonly property int gridCols: 12
  readonly property real bodyW: Theme.bentoBodyWidth
  readonly property real unitW: (bodyW - gut * (gridCols - 1)) / gridCols

  function colW(span) {
    return unitW * span + gut * (span - 1)
  }

  // Integer widths, so the three columns plus their two gutters add up to
  // exactly the body width with no rounding overflow on either side.
  readonly property real colAW: Math.round(colW(3))
  readonly property real colBW: Math.round(colW(5))
  readonly property real colCW: Math.round(colW(4))

  // Half of a two card row (the row keeps the same gutter as the grid).
  readonly property real halfW: (colBW - gut) / 2
  readonly property real halfCW: (colCW - gut) / 2

  // --- card heights, all multiples of the grid unit --------------------------
  readonly property real hToggles: g
  readonly property real hControls: g * 1.5
  readonly property real hGauge: g * 2
  readonly property real hFan: g
  readonly property real hNet: g * 1.5
  readonly property real hWeatherMin: g * 2
  readonly property real hIdentity: g * 1.5
  readonly property real hPowerMin: g * 2
  readonly property real hPair: g
  readonly property real hStorageMin: g * 3
  readonly property real hProcsMin: g * 2.5
  readonly property real hClockMin: g * 4

  // Fixed part of each column (the flexible card excluded).
  readonly property real fixedB: hToggles + hControls + hGauge + hFan + hNet
  readonly property real fixedC: hIdentity + hPowerMin + hPair + hPair

  readonly property real colAMin: hClockMin + gut + hProcsMin
  readonly property real colBMin: fixedB + 5 * gut + hWeatherMin
  readonly property real colCMin: fixedC + 4 * gut + hStorageMin

  // The panel is as tall as its tallest column.
  readonly property real bodyH: Math.max(colAMin, Math.max(colBMin, colCMin))

  // Column A: the clock/calendar card keeps the slack, the process list takes
  // a share of it so both cards grow instead of leaving a strip behind.
  readonly property real aSlack: Math.max(0, bodyH - gut - hClockMin - hProcsMin)
  readonly property real hProcs: Math.round(hProcsMin + Math.min(aSlack * 0.35, g * 2))
  readonly property real hClock: bodyH - gut - hProcs

  // Column B: weather takes everything that is left under the fixed cards.
  readonly property real hWeather: bodyH - fixedB - 5 * gut

  // Column C: the remaining slack is split between the power hero card and
  // the storage card. Both are integers, and the column always sums to bodyH.
  readonly property real cFixed: hIdentity + hPair + hPair + 4 * gut
  readonly property real cFlex: Math.max(0, bodyH - cFixed - hPowerMin - hStorageMin)
  readonly property real hPower: Math.round(hPowerMin + cFlex * 0.4)
  readonly property real hStorage: bodyH - cFixed - hPower

  // The window around the panel (see FloatingHealth): the content is inset by
  // Theme.contentPadding on all four sides.
  readonly property real contentWidth: bodyW
  readonly property real contentHeight: bodyH + Theme.contentPadding * 2

  // ===========================================================================
  // Runtime state
  // ===========================================================================

  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()
  property string clockText: ""
  property var weeks: []
  property var cpuHistory: []
  property var gpuHistory: []
  readonly property int historyMax: 60
  readonly property int procRows: 5
  readonly property real pctW: 34

  readonly property var cpuProcRows: {
    var l = root.processStatsService ? root.processStatsService.cpuTop : []
    if (!l) return []
    return l.length > root.procRows ? l.slice(0, root.procRows) : l
  }
  readonly property var memProcRows: {
    var l = root.processStatsService ? root.processStatsService.memoryTop : []
    if (!l) return []
    return l.length > root.procRows ? l.slice(0, root.procRows) : l
  }

  readonly property var volumes: root.storageService ? root.storageService.volumes : []

  // One cell per mount. A third mount shrinks every cell equally; if the
  // cells would fall below the minimum width the grid drops to two rows.
  function storageCellWidthFor(n) {
    return (colCW - 2 * cp - gut * (n - 1)) / n
  }
  readonly property int storageCols: {
    var n = Math.max(1, volumes.length)
    if (n <= 1) return 1
    for (var c = Math.min(3, n); c >= 2; c--) {
      if (storageCellWidthFor(c) >= Theme.storageCellMinWidth) return c
    }
    return 2
  }
  readonly property int storageRows: Math.ceil(Math.max(1, volumes.length) / storageCols)
  readonly property real storageCellW: storageCellWidthFor(storageCols)
  readonly property real storageCellH: (hStorage - 2 * cp - 12 - 6 - gut * (storageRows - 1)) / storageRows
  // Caption heights: the mount label and the "used / total" line.
  readonly property real storageLabelH: 12
  readonly property real storageValueH: storageFontSize * 1.3
  // The clear space between the two captions is at least a quarter of a
  // gutter, and never eats into the ring.
  readonly property real storageTextGap: Math.max(3,
    Math.min(root.gut,
      (storageCellH - storageLabelH - storageValueH - Theme.ringMinSize) / 2,
      (storageCellH - storageLabelH - storageValueH) * 0.2))
  // The ring takes what the cell allows: the cell width, and the cell height
  // minus the two caption lines and the gaps around them.
  readonly property real storageRing: Math.max(Theme.ringMinSize,
    Math.min(Theme.ringMaxSize, storageCellW - 8,
      storageCellH - storageLabelH - storageValueH - 2 * storageTextGap))
  readonly property real storageFontSize: Math.max(Theme.storageTextMinFont,
    Math.min(Theme.storageTextMaxFont, Math.round(storageCellW / 11)))

  // Weather glyph size follows the card height, with a floor so it never
  // disappears when the column is short.
  readonly property real glyphSize: Math.max(40, Math.min(64, hWeather - 2 * cp))
  // Width left for the text block once the glyph and the optional sunrise
  // block have taken their share of the card.
  readonly property real weatherTextW: colBW - 2 * cp - glyphSize - 12
    - (root.hasSunrise ? 88 + 12 : 0)
  // The condition word steps down through three sizes instead of truncating.
  readonly property int conditionFontSize: {
    var w = root.weatherTextW
    if (w <= 0) return Theme.fontSizeCondition
    if (conditionMetrics14.width <= w) return Theme.fontSizeCondition
    if (conditionMetrics11.width <= w) return Theme.fontSizeConditionSmall
    return Theme.fontSizeMicro
  }

  readonly property string conditionText: root.weatherService && root.weatherService.weatherCode >= 0
    ? root.weatherStatus(root.weatherService.weatherCode) : ""
  readonly property bool hasSunrise: root.weatherService && root.weatherService.sunriseText
    ? root.weatherService.sunriseText.length > 0 : false

  property real entranceProgress: 1
  readonly property real _entranceStep: 0.04
  readonly property real _entranceSpan: 0.22
  function cardAlpha(index) {
    if (root.entranceProgress >= 1) return 1
    return Math.max(0, Math.min(1, (root.entranceProgress - index * root._entranceStep) / root._entranceSpan))
  }
  function playEntrance() { root.entranceProgress = 0; entranceAnim.restart() }
  NumberAnimation { id: entranceAnim; target: root; property: "entranceProgress"; from: 0; to: 1; duration: 780; easing.type: Easing.OutQuad }

  width: contentWidth
  height: bodyH

  function weatherStatus(code) {
    if (code === 0) return "Clear"
    if (code >= 1 && code <= 3) return "Partly Cloudy"
    if (code === 45 || code === 48) return "Foggy"
    if (code >= 51 && code <= 67) return "Rain"
    if (code >= 71 && code <= 77) return "Snow"
    if (code >= 80 && code <= 82) return "Showers"
    if (code >= 95 && code <= 99) return "Storm"
    return "--"
  }

  function formatBytes(b) {
    if (b < 1024) return b.toFixed(0) + " B/s"
    if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
    return (b / 1048576).toFixed(1) + " MB/s"
  }

  function uptimeText() {
    if (!root.storageService || root.storageService.uptimeSeconds <= 0) return "--"
    var totalMinutes = Math.floor(root.storageService.uptimeSeconds / 60)
    var days = Math.floor(totalMinutes / 1440)
    var hours = Math.floor((totalMinutes % 1440) / 60)
    var minutes = totalMinutes % 60
    return (days > 0 ? days + "D " : "") + hours + "H " + minutes + "M"
  }

  // One compact unit format for every disk: values below 1000 GB stay in
  // gigabytes ("157G"), everything above becomes terabytes ("1.8T").
  function toCompactGiB(v) {
    var b = Number(v) || 0
    if (b <= 0) return "0G"
    var gb = b / (1024 * 1024 * 1024)
    if (gb < 1000) {
      if (gb >= 100) return Math.round(gb) + "G"
      if (gb >= 10) return gb.toFixed(0) + "G"
      return gb.toFixed(1).replace(/\.0$/, "") + "G"
    }
    var tb = gb / 1024
    if (tb >= 10) return tb.toFixed(0) + "T"
    if (tb >= 1) return tb.toFixed(1).replace(/\.0$/, "") + "T"
    return Math.round(gb) + "G"
  }
  function usedTotalCompact(used, size) {
    if (!(size > 0)) return ""
    return toCompactGiB(used) + " / " + toCompactGiB(size)
  }

  function batteryColor(pct, charging) { return Theme.batteryColor(pct, charging) }

  function pushSample(arr, v) {
    var a = arr.slice()
    a.push(v)
    if (a.length > root.historyMax) a = a.slice(a.length - root.historyMax)
    return a
  }

  // ===========================================================================
  // Timers (only while the panel is open)
  // ===========================================================================

  Timer {
    interval: 1000
    running: root.active
    repeat: true
    onTriggered: {
      var d = new Date()
      root.clockText = Qt.formatDateTime(d, "HH:mm")
      root.year = d.getFullYear()
      root.month = d.getMonth()
      root.rebuildCalendar()
      root.cpuHistory = root.pushSample(root.cpuHistory, root.cpuLoad)
      root.gpuHistory = root.pushSample(root.gpuHistory, root.gpuLoad)
    }
  }
  Timer {
    interval: 60000
    running: root.active
    repeat: true
    onTriggered: {
      rebuildCalendar()
      if (root.systemStatsService) root.systemStatsService.sample()
      if (root.thermalService) root.thermalService.sample()
      if (root.gpuModeService) root.gpuModeService.sample()
      if (root.updateService) root.updateService.sample()
    }
  }

  function rebuildCalendar() {
    var first = new Date(root.year, root.month, 1)
    var last = new Date(root.year, root.month + 1, 0)
    var startOffset = first.getDay()
    var daysInMonth = last.getDate()
    var today = new Date()
    var isCurrentMonth = today.getFullYear() === root.year && today.getMonth() === root.month
    var cells = []
    for (var i = 0; i < startOffset; i++) cells.push({ label: "", isToday: false, isPast: true })
    for (var d = 1; d <= daysInMonth; d++) {
      var isToday = isCurrentMonth && today.getDate() === d
      var isPast = isCurrentMonth && d < today.getDate()
      cells.push({ label: String(d), isToday: isToday, isPast: isPast })
    }
    while (cells.length % 7 !== 0) cells.push({ label: "", isToday: false, isPast: true })
    var w = []
    for (var k = 0; k < cells.length; k += 7) w.push(cells.slice(k, k + 7))
    // Always six rows: the calendar never changes height when the month does.
    var blank = []
    for (var b = 0; b < 7; b++) blank.push({ label: "", isToday: false, isPast: true })
    while (w.length < 6) w.push(blank.slice())
    root.weeks = w
  }

  function prevMonth() { if (root.month === 0) { root.month = 11; root.year-- } else root.month--; rebuildCalendar(); root.userActivity() }
  function nextMonth() { if (root.month === 11) { root.month = 0; root.year++ } else root.month++; rebuildCalendar(); root.userActivity() }
  function changeGpuMode() { if (root.gpuModeService) root.gpuModeService.requestMode("integrated"); root.userActivity() }
  function cancelGpuModeSwitch() { if (root.gpuModeService) root.gpuModeService.cancelPending(); root.userActivity() }

  function start() {
    if (root.systemStatsService) root.systemStatsService.start()
    if (root.thermalService) root.thermalService.start()
    if (root.gpuModeService) root.gpuModeService.start()
    if (root.networkService) root.networkService.startStats()
    if (root.processStatsService) root.processStatsService.start()
    if (root.updateService) root.updateService.start()
    if (root.storageService) root.storageService.start()
    if (root.weatherService) root.weatherService.active = true
    root.clockText = Qt.formatDateTime(new Date(), "HH:mm")
    rebuildCalendar()
    playEntrance()
  }
  function stop() {
    if (root.systemStatsService) root.systemStatsService.stop()
    if (root.thermalService) root.thermalService.stop()
    if (root.gpuModeService) root.gpuModeService.stop()
    if (root.networkService) root.networkService.stopStats()
    if (root.processStatsService) root.processStatsService.stop()
    if (root.updateService) root.updateService.stop()
    if (root.storageService) root.storageService.stop()
    if (root.weatherService) root.weatherService.active = false
  }

  Component.onCompleted: {
    root.clockText = Qt.formatDateTime(new Date(), "HH:mm")
    root.rebuildCalendar()
  }


  opacity: root.active ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Theme.animDurationFast } }

  // ===========================================================================
  // The bento
  // ===========================================================================

  // The bento is a single row of three columns. Their widths come from the
  // 3 / 5 / 4 split of the twelve grid columns, so the proportions are a
  // ratio and never a pixel constant.
  RowLayout {
    id: grid
    anchors.fill: parent
    spacing: root.gut

    // -----------------------------------------------------------------------
    // Column A — 3 / 12 : clock + calendar, top processes
    // -----------------------------------------------------------------------
    ColumnLayout {
      id: colA
      Layout.preferredWidth: root.colAW
      Layout.minimumWidth: root.colAW
      Layout.fillHeight: true
      spacing: root.gut

      // --- clock + calendar --------------------------------------------------
      BentoCard {
        entranceIndex: 0
        Layout.fillWidth: true
        Layout.preferredHeight: root.hClock
        Layout.minimumHeight: root.hClock

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.cp
          spacing: 4

          Text {
            text: root.clockText
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeHero
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
              text: "\u25c0"
              color: Theme.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeTiny
              Layout.alignment: Qt.AlignVCenter
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.prevMonth() }
            }
            Text {
              text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
              color: Theme.foreground
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeTitle
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text {
              text: "\u25b6"
              color: Theme.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeTiny
              Layout.alignment: Qt.AlignVCenter
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.nextMonth() }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
              model: ["S", "M", "T", "W", "T", "F", "S"]
              Text {
                text: modelData
                color: Theme.sectionLabel
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMicro
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }

          // The grid rows share the leftover height, so the calendar fills the
          // card instead of leaving a gap under the last week.
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2
            Repeater {
              model: root.weeks
              delegate: RowLayout {
                id: weekRow
                required property var modelData
                property var week: modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2
                Repeater {
                  model: weekRow.week
                  delegate: Item {
                    id: dayCell
                    required property var modelData
                    property var day: modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Rectangle {
                      anchors.fill: parent
                      anchors.margins: 1
                      radius: 5
                      color: dayCell.day.isToday ? Theme.accent : "transparent"
                    }
                    Text {
                      anchors.centerIn: parent
                      text: dayCell.day.label
                      color: dayCell.day.isToday ? Theme.background
                        : (dayCell.day.isPast ? Theme.mutedText : Theme.foreground)
                      font.family: Theme.fontFamily
                      font.pixelSize: dayCell.day.isToday ? Theme.fontSizeMicro + 1 : Theme.fontSizeMicro
                      font.bold: dayCell.day.isToday
                    }
                  }
                }
              }
            }
          }
        }
      }

      // --- top processes -----------------------------------------------------
      BentoCard {
        entranceIndex: 1
        Layout.fillWidth: true
        Layout.preferredHeight: root.hProcs
        Layout.minimumHeight: root.hProcs

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.cp
          spacing: 2

          SectionLabel { text: "TOP PROCESSES" }

          RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.gut

            // CPU column: fixed width name column, right aligned percentage.
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 0
              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "CPU"
                  color: Theme.cyan
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSizeMicro
                  font.bold: true
                  Layout.fillWidth: true
                }
                Text {
                  text: "%"
                  color: Theme.mutedText
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSizeMicro
                  Layout.preferredWidth: root.pctW
                  horizontalAlignment: Text.AlignRight
                }
              }
              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 1
                Repeater {
                  model: root.cpuProcRows
                  delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Text {
                      text: modelData.name
                      color: Theme.foreground
                      font.family: Theme.fontFamily
                      font.pixelSize: Theme.fontSizeMicro
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                      Layout.minimumWidth: 0
                    }
                    Text {
                      text: Number(modelData.cpu).toFixed(1) + "%"
                      color: Theme.cyan
                      font.family: Theme.fontFamily
                      font.pixelSize: Theme.fontSizeMicro
                      Layout.preferredWidth: root.pctW
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }
            }

            // RAM column.
            ColumnLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              spacing: 0
              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "RAM"
                  color: Theme.pink
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSizeMicro
                  font.bold: true
                  Layout.fillWidth: true
                }
                Text {
                  text: "%"
                  color: Theme.mutedText
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSizeMicro
                  Layout.preferredWidth: root.pctW
                  horizontalAlignment: Text.AlignRight
                }
              }
              ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 1
                Repeater {
                  model: root.memProcRows
                  delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Text {
                      text: modelData.name
                      color: Theme.foreground
                      font.family: Theme.fontFamily
                      font.pixelSize: Theme.fontSizeMicro
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                      Layout.minimumWidth: 0
                    }
                    Text {
                      text: Number(modelData.memory).toFixed(1) + "%"
                      color: Theme.pink
                      font.family: Theme.fontFamily
                      font.pixelSize: Theme.fontSizeMicro
                      Layout.preferredWidth: root.pctW
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // -----------------------------------------------------------------------
    // Column B — 5 / 12 : toggles, controls, cpu/gpu, ram/fan, net, weather
    // -----------------------------------------------------------------------
    ColumnLayout {
      id: colB
      Layout.preferredWidth: root.colBW
      Layout.minimumWidth: root.colBW
      Layout.fillHeight: true
      spacing: root.gut

      // --- quick toggles -----------------------------------------------------
      BentoCard {
        entranceIndex: 2
        Layout.fillWidth: true
        Layout.preferredHeight: root.hToggles
        Layout.minimumHeight: root.hToggles
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: root.cp
          anchors.rightMargin: root.cp
          spacing: 6
          QuickToggle {
            label: "DND"
            active: root.notificationLayer ? root.notificationLayer.dnd : false
            onTriggered: {
              root.userActivity()
              if (root.notificationLayer) root.notificationLayer.toggleDnd()
            }
          }
          QuickToggle {
            label: "AWAKE"
            active: root.idleInhibitController ? root.idleInhibitController.idleInhibitEnabled : false
            onTriggered: {
              root.userActivity()
              if (root.idleInhibitController)
                root.idleInhibitController.idleInhibitEnabled = !root.idleInhibitController.idleInhibitEnabled
            }
          }
          QuickToggle {
            visible: Bluetooth.defaultAdapter !== null
            label: "BT"
            active: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
            onTriggered: {
              root.userActivity()
              if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
            }
          }
        }
      }

      // --- volume + brightness ------------------------------------------------
      BentoCard {
        entranceIndex: 3
        Layout.fillWidth: true
        Layout.preferredHeight: root.hControls
        Layout.minimumHeight: root.hControls
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.cp
          spacing: 6
          SectionLabel { text: "CONTROLS" }
          RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
              text: "VOL"
              color: Theme.sectionLabel
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              font.bold: true
            }
            SpeakerIcon {
              muted: root.audioService ? root.audioService.muted : false
              strokeColor: root.audioService && root.audioService.muted ? Theme.red : Theme.mutedText
              Layout.alignment: Qt.AlignVCenter
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.userActivity()
                  if (root.audioService) root.audioService.toggleMute()
                }
              }
            }
            SliderBar {
              Layout.fillWidth: true
              minValue: 0
              maxValue: 1
              step: 0.05
              value: root.audioService ? root.audioService.volume : 0
              fillColor: root.audioService && root.audioService.muted ? Theme.red : Theme.cyan
              onChanged: v => {
                if (root.audioService) {
                  root.audioService.requestFastPoll()
                  root.audioService.setVolume(v)
                }
              }
              onInteraction: root.userActivity()
            }
            Text {
              text: root.audioService ? Math.round(root.audioService.volume * 100) + "%" : "--"
              color: root.audioService && root.audioService.muted ? Theme.red : Theme.cyan
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              Layout.preferredWidth: 30
              horizontalAlignment: Text.AlignRight
            }
            Item {
              id: deviceMenuAnchor
              width: 12
              height: 12
              Layout.alignment: Qt.AlignVCenter
              ChevronIcon {
                anchors.fill: parent
                strokeColor: Theme.mutedText
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.userActivity()
                  if (root.audioService) root.audioService.refreshDevices()
                  audioDeviceMenu.open()
                }
              }
            }
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
              text: "BRI"
              color: Theme.sectionLabel
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              font.bold: true
            }
            SliderBar {
              Layout.fillWidth: true
              minValue: 1
              maxValue: 100
              step: 5
              value: root.brightnessService ? root.brightnessService.displayPercent : 50
              fillColor: root.brightnessService && root.brightnessService.displayPercent > 20 ? Theme.yellow : Theme.red
              onChanged: v => {
                if (root.brightnessService) {
                  root.brightnessService.requestFastPoll()
                  root.brightnessService.setPercent(v)
                }
              }
              onInteraction: root.userActivity()
            }
            Text {
              text: root.brightnessService ? Math.round(root.brightnessService.displayPercent) + "%" : "--"
              color: Theme.yellow
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              Layout.preferredWidth: 30
              horizontalAlignment: Text.AlignRight
            }
            Item { width: 12; height: 12 }
          }
        }

        AudioDeviceMenu {
          id: audioDeviceMenu
          x: -(width - deviceMenuAnchor.width)
          y: deviceMenuAnchor.height + 6
          audioService: root.audioService
          onUserActivity: root.userActivity()
        }
      }

      // --- cpu + gpu ----------------------------------------------------------
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: root.hGauge
        Layout.minimumHeight: root.hGauge
        spacing: root.gut

        BentoCard {
          entranceIndex: 4
          Layout.fillWidth: true
          Layout.preferredWidth: root.halfW
          Layout.fillHeight: true
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.cp
            spacing: 4
            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "CPU"
                color: Theme.sectionLabel
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMicro
                font.bold: true
                font.letterSpacing: 1.0
              }
              Item { Layout.fillWidth: true }
              Text {
                text: Math.round(root.cpuLoad) + "%"
                color: Theme.cyan
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeValue
                font.bold: true
              }
            }
            Text {
              text: root.cpuTemp >= 0 ? Math.round(root.cpuTemp) + "\u00b0C" : "--"
              color: Theme.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
            }
            Sparkline {
              Layout.fillWidth: true
              Layout.fillHeight: true
              samples: root.cpuHistory
              lineColor: Theme.cyan
            }
          }
        }

        BentoCard {
          entranceIndex: 5
          Layout.fillWidth: true
          Layout.preferredWidth: root.halfW
          Layout.fillHeight: true
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.cp
            spacing: 4
            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "GPU"
                color: Theme.sectionLabel
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMicro
                font.bold: true
                font.letterSpacing: 1.0
              }
              Item { Layout.fillWidth: true }
              Text {
                text: root.gpuLoad >= 0 ? Math.round(root.gpuLoad) + "%" : "--"
                color: Theme.pink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeValue
                font.bold: true
              }
            }
            Text {
              text: root.gpuTemp >= 0 ? Math.round(root.gpuTemp) + "\u00b0C" : "--"
              color: Theme.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
            }
            Sparkline {
              Layout.fillWidth: true
              Layout.fillHeight: true
              samples: root.gpuHistory
              lineColor: Theme.pink
            }
          }
        }
      }

      // --- ram + fan ----------------------------------------------------------
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: root.hFan
        Layout.minimumHeight: root.hFan
        spacing: root.gut

        BentoCard {
          entranceIndex: 6
          Layout.fillWidth: true
          Layout.preferredWidth: root.halfW
          Layout.fillHeight: true
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.cp
            spacing: 2
            SectionLabel { text: "RAM" }
            RowLayout {
              Layout.fillWidth: true
              spacing: 6
              Text {
                text: Math.round(root.ramPercent) + "%"
                color: Theme.cyan
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeValue
                font.bold: true
              }
              Text {
                text: root.ramTotal > 0
                  ? (root.ramUsed / 1073741824).toFixed(1) + " / " + (root.ramTotal / 1073741824).toFixed(0) + " GiB"
                  : "--"
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMicro
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }

        BentoCard {
          entranceIndex: 7
          Layout.fillWidth: true
          Layout.preferredWidth: root.halfW
          Layout.fillHeight: true
          ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.cp
            spacing: 2
            SectionLabel { text: "FAN" }
            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "CPU"
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMicro
              }
              Item { Layout.fillWidth: true }
              Text {
                text: root.cpuFanSpeed > 0 ? Math.round(root.cpuFanSpeed) + " RPM" : "--"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMicro
              }
            }
            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "GPU"
                color: Theme.mutedText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMicro
              }
              Item { Layout.fillWidth: true }
              Text {
                text: root.gpuFanSpeed > 0 ? Math.round(root.gpuFanSpeed) + " RPM" : "--"
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeMicro
              }
            }
          }
        }
      }

      // --- network ------------------------------------------------------------
      BentoCard {
        entranceIndex: 8
        Layout.fillWidth: true
        Layout.preferredHeight: root.hNet
        Layout.minimumHeight: root.hNet
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.cp
          spacing: 4
          SectionLabel { text: "NETWORK" }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
              text: "\u2193"
              color: Theme.cyan
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeValue
              font.bold: true
            }
            Text {
              text: root.formatBytes(root.netRxRate)
              color: Theme.foreground
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeValue
            }
            Item { Layout.fillWidth: true }
            Text {
              text: "\u2191"
              color: Theme.pink
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeValue
              font.bold: true
            }
            Text {
              text: root.formatBytes(root.netTxRate)
              color: Theme.foreground
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeValue
            }
          }
          Text {
            text: root.wifiSsid.length > 0
              ? root.wifiSsid
              : (root.networkService && root.networkService.iface ? root.networkService.iface : "OFFLINE")
            color: Theme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMicro
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
      }

      // --- weather ------------------------------------------------------------
      // Full middle column width, and it takes whatever height is left under
      // the network card, so the column has no empty strip under it.
      BentoCard {
        entranceIndex: 9
        Layout.fillWidth: true
        Layout.preferredHeight: root.hWeather
        Layout.minimumHeight: root.hWeatherMin

        RowLayout {
          anchors.fill: parent
          anchors.margins: root.cp
          spacing: 12

          WeatherGlyph {
            weatherCode: root.weatherService ? root.weatherService.weatherCode : -1
            isDay: root.weatherService && root.weatherService.isDay !== undefined ? root.weatherService.isDay : true
            Layout.preferredWidth: root.glyphSize
            Layout.preferredHeight: root.glyphSize
            Layout.alignment: Qt.AlignVCenter
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            Text {
              text: root.weatherService && root.weatherService.city.length > 0
                ? root.weatherService.city.toUpperCase() : "WEATHER"
              color: Theme.sectionLabel
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              font.bold: true
              font.letterSpacing: 1.0
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
            Text {
              text: root.weatherService && root.weatherService.weatherCode >= 0
                ? Math.round(root.weatherService.tempC) + "\u00b0C" : "--"
              color: Theme.cyan
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeHero - 4
              font.bold: true
            }
            // The condition word steps down one size instead of truncating.
            TextMetrics {
              id: conditionMetrics14
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeCondition
              text: root.conditionText
            }
            TextMetrics {
              id: conditionMetrics11
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeConditionSmall
              text: root.conditionText
            }
            Text {
              text: root.conditionText
              color: Theme.foreground
              font.family: Theme.fontFamily
              font.pixelSize: root.conditionFontSize
              elide: Text.ElideNone
              Layout.fillWidth: true
            }
            Text {
              text: root.weatherService && root.weatherService.weatherCode >= 0
                ? "H" + Math.round(root.weatherService.highC) + "\u00b0 / L" + Math.round(root.weatherService.lowC)
                  + "\u00b0  \u00b7  Feels " + Math.round(root.weatherService.feelsLikeC) + "\u00b0C"
                : ""
              color: Theme.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          // Optional sunrise / sunset block on the far right.
          ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            visible: root.hasSunrise
            Text {
              text: "SUN"
              color: Theme.sectionLabel
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              font.bold: true
              font.letterSpacing: 1.0
              horizontalAlignment: Text.AlignRight
              Layout.preferredWidth: 88
            }
            Text {
              text: "\u2191 " + root.weatherService.sunriseText
              color: Theme.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              elide: Text.ElideRight
              Layout.preferredWidth: 88
              horizontalAlignment: Text.AlignRight
            }
            Text {
              text: "\u2193 " + root.weatherService.sunsetText
              color: Theme.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              elide: Text.ElideRight
              Layout.preferredWidth: 88
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }
    }

    // -----------------------------------------------------------------------
    // Column C — 4 / 12 : identity, ac power, profile/gpu mode, storage,
    //                    updates/uptime
    // -----------------------------------------------------------------------
    ColumnLayout {
      id: colC
      Layout.preferredWidth: root.colCW
      Layout.minimumWidth: root.colCW
      Layout.fillHeight: true
      spacing: root.gut

      // --- identity -----------------------------------------------------------
      BentoCard {
        entranceIndex: 10
        Layout.fillWidth: true
        Layout.preferredHeight: root.hIdentity
        Layout.minimumHeight: root.hIdentity
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.cp
          spacing: 2
          Item { Layout.fillHeight: true }
          SectionLabel { text: "IDENTITY" }
          Text {
            text: root.userName.length > 0 ? root.userName : "--"
            color: Theme.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeValue
            font.bold: true
            elide: Text.ElideMiddle
            Layout.fillWidth: true
          }
          Text {
            text: (root.hostName.length > 0 ? root.hostName : "--")
              + (root.kernelVersion.length > 0 ? "  \u00b7  " + root.kernelVersion : "")
            color: Theme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMicro
            elide: Text.ElideMiddle
            Layout.fillWidth: true
          }
          Item { Layout.fillHeight: true }
        }
      }

      // --- ac power (hero) ----------------------------------------------------
      BentoCard {
        entranceIndex: 11
        Layout.fillWidth: true
        Layout.preferredHeight: root.hPower
        Layout.minimumHeight: root.hPowerMin
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.cp
          spacing: 4
          Item { Layout.fillHeight: true }
          SectionLabel { text: "AC POWER" }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
              text: root.batteryOnAc ? "AC" : "BATTERY"
              color: root.batteryOnAc ? Theme.green : Theme.orange
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeHero - 8
              font.bold: true
              elide: Text.ElideRight
            }
            Item { Layout.fillWidth: true }
            Text {
              text: root.batteryCapacity >= 0 ? Math.round(root.batteryCapacity) + "%" : "--"
              color: root.batteryColor(root.batteryCapacity, root.batteryCharging)
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeHero
              font.bold: true
            }
          }
          Text {
            text: root.batteryPower >= 0
              ? (root.batteryCharging ? "Charging" : "Discharging") + "  \u00b7  " + root.batteryPower.toFixed(1) + " W"
              : ""
            color: Theme.mutedText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeMicro
            visible: text.length > 0
          }
          Item { Layout.fillHeight: true }
        }
      }

      // --- profile + gpu mode --------------------------------------------------
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: root.hPair
        Layout.minimumHeight: root.hPair
        spacing: root.gut

        BentoCard {
          entranceIndex: 12
          Layout.fillWidth: true
          Layout.preferredWidth: root.halfCW
          Layout.fillHeight: true
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.cp
            anchors.rightMargin: root.cp
            spacing: 6
            SectionLabel { text: "PROFILE" }
            Item { Layout.fillWidth: true }
            Text {
              text: root.powerProfile.length > 0 ? root.powerProfile.toUpperCase() : "--"
              color: Theme.accent
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              font.bold: true
              elide: Text.ElideRight
              Layout.maximumWidth: root.halfCW - 2 * root.cp - 60
            }
          }
        }

        BentoCard {
          entranceIndex: 13
          Layout.fillWidth: true
          Layout.preferredWidth: root.halfCW
          Layout.fillHeight: true
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.cp
            anchors.rightMargin: root.cp
            spacing: 6
            SectionLabel { text: "GPU MODE" }
            Item { Layout.fillWidth: true }
            Text {
              text: root.gpuMode.length > 0 ? root.gpuMode.toUpperCase() : "--"
              color: Theme.pink
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              font.bold: true
              elide: Text.ElideRight
              Layout.maximumWidth: root.halfCW - 2 * root.cp - 70
              horizontalAlignment: Text.AlignRight
            }
          }
        }
      }

      // --- storage -------------------------------------------------------------
      BentoCard {
        entranceIndex: 14
        Layout.fillWidth: true
        Layout.preferredHeight: root.hStorage
        Layout.minimumHeight: root.hStorageMin
        ColumnLayout {
          anchors.fill: parent
          anchors.margins: root.cp
          spacing: 6
          SectionLabel {
            text: "STORAGE"
            // Fixed header height, so the cell height below is exact.
            Layout.preferredHeight: 12
            Layout.minimumHeight: 12
          }

          GridLayout {
            id: storageGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.storageCols
            rowSpacing: root.gut
            columnSpacing: root.gut

            Repeater {
              model: root.volumes
              delegate: Item {
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                  anchors.fill: parent
                  spacing: 0
                  Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                  RingGauge {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.storageRing
                    Layout.preferredHeight: root.storageRing
                    Layout.minimumWidth: root.storageRing
                    Layout.minimumHeight: root.storageRing
                    diameter: Math.round(root.storageRing)
                    thickness: Math.max(4, Math.round(root.storageRing * 0.07))
                    value: modelData.percent
                    label: ""
                    subLabel: ""
                    showGlyph: false
                  }
                  Text {
                    text: modelData.label
                    color: Theme.sectionLabel
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeMicro
                    font.bold: true
                    font.letterSpacing: 1.0
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.storageLabelH
                    Layout.minimumHeight: root.storageLabelH
                    Layout.topMargin: root.storageTextGap
                  }
                  Text {
                    text: root.usedTotalCompact(modelData.used, modelData.size)
                    color: Theme.mutedText
                    font.family: Theme.fontFamily
                    font.pixelSize: root.storageFontSize
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.storageValueH
                    Layout.minimumHeight: root.storageValueH
                    Layout.topMargin: root.storageTextGap
                  }
                  Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
                }
              }
            }
          }
        }
      }

      // --- updates + uptime -----------------------------------------------------
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: root.hPair
        Layout.minimumHeight: root.hPair
        spacing: root.gut

        BentoCard {
          entranceIndex: 15
          Layout.fillWidth: true
          Layout.preferredWidth: root.halfCW
          Layout.fillHeight: true
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.cp
            anchors.rightMargin: root.cp
            spacing: 6
            SectionLabel { text: "UPDATES" }
            Item { Layout.fillWidth: true }
            Text {
              text: root.updateService && root.updateService.count >= 0
                ? String(root.updateService.count) : "--"
              color: (root.updateService && root.updateService.count >= 0 && root.updateService.count > 0)
                ? Theme.green : Theme.mutedText
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeValue
              font.bold: true
            }
          }
        }

        BentoCard {
          entranceIndex: 16
          Layout.fillWidth: true
          Layout.preferredWidth: root.halfCW
          Layout.fillHeight: true
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.cp
            anchors.rightMargin: root.cp
            spacing: 6
            SectionLabel { text: "UPTIME" }
            Item { Layout.fillWidth: true }
            Text {
              text: root.uptimeText()
              color: Theme.cyan
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeMicro
              font.bold: true
              elide: Text.ElideRight
            }
          }
        }
      }
    }
  }

  // ===========================================================================
  // Building blocks
  // ===========================================================================

  component BentoCard: Rectangle {
    property int entranceIndex: 0
    opacity: root.cardAlpha(entranceIndex)
    radius: Theme.cardRadius
    color: Theme.cardFill
    border.width: 1
    border.color: Theme.cardBorderColor
  }

  component SectionLabel: Text {
    color: Theme.sectionLabel
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeMicro
    font.bold: true
    font.letterSpacing: 1.2
  }

  component QuickToggle: Rectangle {
    id: quickToggle
    property string label: ""
    property bool active: false
    signal triggered()

    Layout.fillWidth: true
    Layout.fillHeight: true
    radius: 4
    color: quickToggle.active
      ? Qt.rgba(Theme.cyan.r, Theme.cyan.g, Theme.cyan.b, 0.16)
      : Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.28)
    border.width: 1
    border.color: quickToggle.active ? Theme.cyan : Theme.cardBorderColor

    Text {
      anchors.centerIn: parent
      text: quickToggle.label
      color: quickToggle.active ? Theme.cyan : Theme.foreground
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeMicro
      font.bold: true
      font.letterSpacing: 0.8
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: quickToggle.triggered()
    }
  }

  // Custom stroke icons, painted once per state change.
  component SpeakerIcon: Canvas {
    id: spk
    property bool muted: false
    property color strokeColor: Theme.mutedText

    implicitWidth: 14
    implicitHeight: 14
    renderTarget: Canvas.Image
    antialiasing: true

    onMutedChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var s = Math.min(width, height)
      ctx.strokeStyle = strokeColor
      ctx.lineWidth = Math.max(1, s * 0.1)
      ctx.lineCap = "round"
      ctx.lineJoin = "round"

      // speaker body
      ctx.beginPath()
      ctx.moveTo(s * 0.08, s * 0.36)
      ctx.lineTo(s * 0.26, s * 0.36)
      ctx.lineTo(s * 0.44, s * 0.16)
      ctx.lineTo(s * 0.44, s * 0.84)
      ctx.lineTo(s * 0.26, s * 0.64)
      ctx.lineTo(s * 0.08, s * 0.64)
      ctx.closePath()
      ctx.stroke()

      if (!muted) {
        ctx.beginPath()
        ctx.arc(s * 0.46, s * 0.5, s * 0.2, -0.85, 0.85)
        ctx.stroke()
        ctx.beginPath()
        ctx.arc(s * 0.46, s * 0.5, s * 0.36, -0.85, 0.85)
        ctx.stroke()
      } else {
        ctx.beginPath()
        ctx.moveTo(s * 0.62, s * 0.32)
        ctx.lineTo(s * 0.92, s * 0.68)
        ctx.moveTo(s * 0.92, s * 0.32)
        ctx.lineTo(s * 0.62, s * 0.68)
        ctx.stroke()
      }
    }
  }

  component ChevronIcon: Canvas {
    id: chev
    property color strokeColor: Theme.mutedText

    implicitWidth: 12
    implicitHeight: 12
    renderTarget: Canvas.Image
    antialiasing: true

    onStrokeColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var s = Math.min(width, height)
      ctx.strokeStyle = strokeColor
      ctx.lineWidth = Math.max(1, s * 0.11)
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.beginPath()
      ctx.moveTo(s * 0.22, s * 0.38)
      ctx.lineTo(s * 0.5, s * 0.66)
      ctx.lineTo(s * 0.78, s * 0.38)
      ctx.stroke()
    }
  }

  component SliderBar: Rectangle {
    id: sbar
    property real minValue: 0
    property real maxValue: 1
    property real value: 0
    property real step: 0
    property color fillColor: Theme.accent
    signal changed(real v)
    signal interaction()

    implicitHeight: 4
    radius: 2
    color: Theme.selection

    Rectangle {
      height: parent.height
      radius: parent.radius
      color: sbar.fillColor
      width: sbar.maxValue > sbar.minValue
        ? Math.max(0, Math.min(parent.width, parent.width * (sbar.value - sbar.minValue) / (sbar.maxValue - sbar.minValue)))
        : 0
    }
    MouseArea {
      anchors.fill: parent
      onPressed: mouse => { sbar.interaction(); sbar._set(mouse.x) }
      onPositionChanged: mouse => { if (pressed) { sbar.interaction(); sbar._set(mouse.x) } }
      onWheel: event => {
        sbar.interaction()
        var dir = event.angleDelta.y > 0 ? 1 : -1
        var effStep = sbar.step > 0 ? sbar.step : (sbar.maxValue - sbar.minValue) / 20
        sbar._setValue(sbar.value + dir * effStep)
        event.accepted = true
      }
    }
    function _set(x) {
      if (sbar.width <= 0) return
      var ratio = Math.max(0, Math.min(1, x / sbar.width))
      sbar._setValue(sbar.minValue + ratio * (sbar.maxValue - sbar.minValue))
    }
    function _setValue(v) {
      var clamped = Math.max(sbar.minValue, Math.min(sbar.maxValue, v))
      if (Math.abs(clamped - sbar.value) > 0.001) sbar.changed(clamped)
    }
  }

  // Sparkline scaled to the recent minimum and maximum, so a quiet range is
  // still readable instead of sitting flat on the baseline.
  component Sparkline: Canvas {
    id: spark
    property var samples: []
    property color lineColor: Theme.cyan

    renderTarget: Canvas.Image
    antialiasing: true

    onSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var s = spark.samples
      if (!s || s.length < 2 || width <= 2 || height <= 2) return
      var minv = Infinity
      var maxv = -Infinity
      for (var i = 0; i < s.length; i++) {
        var v = Number(s[i])
        if (!isFinite(v)) continue
        if (v < minv) minv = v
        if (v > maxv) maxv = v
      }
      if (!isFinite(minv) || !isFinite(maxv)) return
      if (maxv - minv < 1) {
        minv = Math.max(0, minv - 1)
        maxv = minv + 2
      }
      var pad = (maxv - minv) * 0.12
      var lo = minv - pad
      var hi = maxv + pad
      var count = s.length
      var dx = width / (count - 1)
      ctx.strokeStyle = spark.lineColor
      ctx.lineWidth = 1.25
      ctx.lineJoin = "round"
      ctx.lineCap = "round"
      ctx.beginPath()
      for (var j = 0; j < count; j++) {
        var x = j * dx
        var y = height - 1 - ((Number(s[j]) - lo) / (hi - lo)) * (height - 2)
        if (j === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }
      ctx.stroke()
    }
  }
}
