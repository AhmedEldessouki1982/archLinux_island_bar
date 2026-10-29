import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import "../config"
import "../components"
import "../services"

// Health panel — compact three column grid.
//
// The panel is built on a 36px unit and an 8px gutter:
//
//   a card spanning n units is  n * 36 + (n - 1) * 8  pixels tall
//   a column is exactly ten units:  10 * 36 + 9 * 8 = 432 px
//
// Every column is laid out as a Column of fixed height cards, so all three
// columns end on the same line by construction and no card is ever stretched
// to eat leftover space.
//
//   LEFT   196px   clock + calendar (7u) · top processes (4u)
//   MIDDLE 232px   toggles (1u) · controls (2u) · cpu|gpu (2u) · ram|fan (2u)
//                  network (2u) · weather (2u)
//   RIGHT  196px   identity (1u) · power (4u) · profile|gpu mode (1u)
//                  storage (4u) · updates|uptime (1u)
//
// Only Theme.qml may define a size, a colour or a weight; only Format.qml may
// turn a number into a string. This file describes the grid.
Item {
  id: root

  property bool active: false
  signal userActivity()

  // ===========================================================================
  // Mirrored service state
  // ===========================================================================

  property real cpuLoad: 0
  property bool cpuReady: false
  property real cpuTemp: 0
  property int cpuCount: 1
  property real ramUsed: 0
  property real ramTotal: 0
  property real ramPercent: 0
  property bool ramReady: false
  property real gpuTemp: 0
  property real gpuLoad: 0
  // GPU utilisation as the panel prints it: zero when the dGPU is suspended.
  property real gpuLoadNow: 0
  property real cpuFanSpeed: 0
  property real gpuFanSpeed: 0
  property real netRxRate: 0
  property real netTxRate: 0
  property real netLatency: -1
  property bool netConnected: false
  property string wifiSsid: ""
  property int batteryCapacity: 0
  property real batteryPower: 0
  property bool batteryCharging: false
  property bool batteryOnAc: false
  property bool hasBattery: false
  property string gpuMode: ""
  property string gpuPowerStatus: ""
  property string powerProfile: ""
  property string kernelVersion: ""
  property string userName: ""
  property string hostName: ""
  property bool gpuConfirming: false
  property string pendingGpuMode: ""

  // ===========================================================================
  // Services
  // ===========================================================================

  property var audioService: null
  property var brightnessService: null
  property var batteryService: null
  property var weatherService: null
  property var networkService: null
  property var systemStatsService: null
  property var thermalService: null
  property var gpuModeService: null
  property var storageService: null
  property var processStatsService: null
  property var updateService: null
  property var notificationLayer: null
  property var idleInhibitController: null

  onBatteryServiceChanged: {
    if (root.batteryService) {
      root.hasBattery = Qt.binding(() => root.batteryService.battery !== null)
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
      root.cpuReady = Qt.binding(() => root.systemStatsService.cpuReady)
      root.ramUsed = Qt.binding(() => root.systemStatsService.ramUsed)
      root.ramTotal = Qt.binding(() => root.systemStatsService.ramTotal)
      root.ramPercent = Qt.binding(() => root.systemStatsService.ramPercent)
      root.ramReady = Qt.binding(() => root.systemStatsService.ramReady)
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
      root.gpuLoadNow = Qt.binding(() => root.thermalService.gpuReading
        ? root.thermalService.gpuLoadOut : 0)
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
      root.netLatency = Qt.binding(() => root.networkService.latencyMs)
      root.netConnected = Qt.binding(() => root.networkService.connected)
      root.wifiSsid = Qt.binding(() => root.networkService.ssid)
    }
  }

  // ===========================================================================
  // Grid
  // ===========================================================================

  readonly property int gut: Theme.gridGutter
  readonly property int colAW: Theme.columnLeftWidth
  readonly property int colBW: Theme.columnMiddleWidth
  readonly property int colCW: Theme.columnRightWidth
  readonly property int bodyW: Theme.bodyWidth
  readonly property int bodyH: Theme.columnHeight

  // Content the floating window has to host (the window adds the padding).
  readonly property int contentWidth: root.bodyW
  readonly property int contentHeight: root.bodyH

  // Height of a card that spans n units.
  function cardH(n) {
    return n * Theme.gridUnit + (n - 1) * Theme.gridGutter
  }
  readonly property int h1: root.cardH(1)   // 36
  readonly property int h2: root.cardH(2)   // 80
  readonly property int h3: root.cardH(3)   // 124
  readonly property int h4: root.cardH(4)   // 168
  readonly property int h7: root.cardH(7)   // 300

  // Half of a two card row inside a column.
  readonly property real halfBW: (root.colBW - root.gut) / 2   // 112
  readonly property real halfCW: (root.colCW - root.gut) / 2   // 94

  // Real font metrics, so every fit decision uses the font that is actually
  // loaded instead of a guessed line height.
  TextMetrics {
    id: mHero
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeHero
    font.weight: Theme.fontWeightHero
    text: "00:00"
  }
  TextMetrics {
    id: mValue
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeValue
    font.weight: Theme.fontWeightValue
    text: "MMMM yyyy"
  }
  TextMetrics {
    id: mBody
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeBody
    font.weight: Theme.fontWeightBody
    text: "0000000"
  }
  TextMetrics {
    id: mCaption
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeCaption
    font.weight: Theme.fontWeightCaption
    text: "MMMMM"
  }
  readonly property real mHeroH: mHero.height
  readonly property real mValueH: mValue.height
  readonly property real mBodyH: mBody.height
  readonly property real mCaptionH: mCaption.height

  // ===========================================================================
  // Clock and calendar
  // ===========================================================================

  // Navigation state is independent of the clock and reset only when opened.
  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  property string calendarDayKey: ""
  property var weeks: []

  // The panel prints a "HH:mm" clock, so it wakes once a minute instead of the
  // per-second timer this used to carry. Midnight rolls the calendar over.
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
  readonly property date now: clock.date
  onNowChanged: {
    if (!root.active) return
    var key = root.now.getFullYear() + "-" + root.now.getMonth() + "-" + root.now.getDate()
    if (key !== root.calendarDayKey) root.rebuildCalendar()
  }

  readonly property string monthTitle: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")

  // 7 day cells of 25px inside the 176px card.
  readonly property int calendarCellW: Math.floor((root.colAW - 2 * Theme.cardPadX) / 7)
  readonly property int calendarW: root.calendarCellW * 7

  // Clock, month header, weekday letters and six day rows, with the three
  // remaining gaps sharing what the card has left over.
  readonly property real clockContentH: root.mHeroH + root.mValueH + root.mCaptionH
    + 6 * Theme.calendarRowHeight
  readonly property real clockGap: Math.max(0,
    Math.floor((root.h7 - 2 * Theme.cardPadY - root.clockContentH) / 3))

  // Six weeks of real days: the leading and trailing cells carry the adjacent
  // months, dimmed. Blank cells used to leave the last row empty in a five week
  // month, which pushed the whole clock block 12px up inside its card; a full
  // six week grid keeps the block optically centred and the height constant.
  function rebuildCalendar() {
    var first = new Date(root.viewYear, root.viewMonth, 1)
    var daysInMonth = new Date(root.viewYear, root.viewMonth + 1, 0).getDate()
    var daysInPrevMonth = new Date(root.viewYear, root.viewMonth, 0).getDate()
    var startOffset = first.getDay()
    var today = new Date()
    root.calendarDayKey = today.getFullYear() + "-" + today.getMonth() + "-" + today.getDate()
    var isCurrentMonth = today.getFullYear() === root.viewYear && today.getMonth() === root.viewMonth

    var cells = []
    for (var p = startOffset - 1; p >= 0; p--)
      cells.push({ label: String(daysInPrevMonth - p), isToday: false, isPast: true, outside: true })
    for (var d = 1; d <= daysInMonth; d++) {
      cells.push({
        label: String(d),
        isToday: isCurrentMonth && today.getDate() === d,
        isPast: isCurrentMonth && d < today.getDate(),
        outside: false
      })
    }
    var nextDay = 1
    while (cells.length < 42)
      cells.push({ label: String(nextDay++), isToday: false, isPast: false, outside: true })

    var w = []
    for (var k = 0; k < 42; k += 7) w.push(cells.slice(k, k + 7))
    root.weeks = w
  }

  function prevMonth() {
    if (root.viewMonth === 0) { root.viewMonth = 11; root.viewYear-- } else root.viewMonth--
    rebuildCalendar()
    root.userActivity()
  }
  function nextMonth() {
    if (root.viewMonth === 11) { root.viewMonth = 0; root.viewYear++ } else root.viewMonth++
    rebuildCalendar()
    root.userActivity()
  }

  // ===========================================================================
  // Processes — the top CPU and memory lists merged into the rows that fit
  // ===========================================================================

  readonly property var procRows: {
    var svc = root.processStatsService
    if (!svc) return []
    var seen = {}
    var rows = []
    var cpu = svc.cpuTop || []
    var mem = svc.memoryTop || []
    for (var i = 0; i < cpu.length; i++) {
      var c = cpu[i]
      seen[c.pid] = c
      rows.push(c)
    }
    for (var j = 0; j < mem.length; j++) {
      var m = mem[j]
      if (seen[m.pid]) continue
      rows.push(m)
    }
    rows.sort(function (a, b) {
      return Math.max(b.cpu, b.memory) - Math.max(a.cpu, a.memory)
    })
    return rows.slice(0, root.procRowCount)
  }
  // The card is four units tall. How many rows it holds is measured from the
  // real line height, not assumed: a fixed four left a 40px hole at the bottom.
  readonly property real procBodyH: root.h4 - 2 * Theme.cardPadY
    - root.mCaptionH - Theme.gapMedium - root.mCaptionH - Theme.gapSmall
  readonly property int procRowCount: Math.max(1,
    Math.floor((root.procBodyH + Theme.gapTight) / (root.mBodyH + Theme.gapTight)))
  // Whatever height the rows do not use becomes the space between them, so the
  // list ends on the card's bottom padding instead of stopping short.
  readonly property real procRowGap: root.procRowCount > 1
    ? Math.max(0, Math.floor((root.procBodyH - root.procRowCount * root.mBodyH)
      / (root.procRowCount - 1)))
    : 0
  readonly property real procNameW: root.colAW - 2 * Theme.cardPadX
    - Theme.procCpuColWidth - Theme.procRamColWidth

  // ===========================================================================
  // Weather
  // ===========================================================================

  readonly property string conditionText: root.weatherService && root.weatherService.weatherCode >= 0
    ? root.weatherStatus(root.weatherService.weatherCode) : "--"
  // The city is whatever the geolocation service resolved, never a fixture.
  readonly property string weatherCityText: {
    var city = root.weatherService ? String(root.weatherService.city) : ""
    return city.length > 0 ? city.toUpperCase() : "--"
  }
  readonly property bool weatherHasSun: root.weatherService
    && root.weatherService.sunriseText.length > 0 && root.weatherService.sunsetText.length > 0
  readonly property real weatherInnerW: root.colBW - 2 * Theme.cardPadX
  readonly property real weatherTextW: root.weatherInnerW - Theme.weatherGlyphSize
    - 2 * root.gut
  readonly property bool weatherShowSun: mCondBody.advanceWidth <= root.weatherTextW
    - Theme.weatherSunColWidth
  readonly property real weatherTextActualW: root.weatherTextW
    - (root.weatherShowSun ? Theme.weatherSunColWidth : 0)
  // The condition steps down one size instead of being cut off.
  readonly property int conditionSize: mCondBody.advanceWidth <= root.weatherTextActualW
    ? Theme.fontSizeBody : Theme.fontSizeCaption
  readonly property string highLowText: "H" + Format.temp(root.weatherService ? root.weatherService.highC : 0)
    + " / L" + Format.temp(root.weatherService ? root.weatherService.lowC : 0)
    + " \u00b7 feels " + Format.temp(root.weatherService ? root.weatherService.feelsLikeC : 0)
  readonly property string highLowShortText: "H" + Format.temp(root.weatherService ? root.weatherService.highC : 0)
    + "/L" + Format.temp(root.weatherService ? root.weatherService.lowC : 0)
    + " \u00b7 F" + Format.temp(root.weatherService ? root.weatherService.feelsLikeC : 0)
  readonly property string weatherSummaryText: mWeatherSummary.advanceWidth <= root.weatherTextActualW
    ? root.highLowText : root.highLowShortText

  TextMetrics {
    id: mCondBody
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeBody
    font.weight: Theme.fontWeightBody
    text: root.conditionText
  }

  TextMetrics {
    id: mWeatherSummary
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeCaption
    font.weight: Theme.fontWeightCaption
    font.letterSpacing: Theme.letterSpacingCaption
    text: root.highLowText
  }

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

  // ===========================================================================
  // Battery, power profile, storage, updates
  // ===========================================================================

  readonly property int batteryFillSegments: Math.round(
    Math.max(0, Math.min(100, root.batteryCapacity)) / 100 * Theme.batteryBarSegments)
  // The presets live in Config, not in the panel: the popup and the chips read
  // the same three values, so they cannot disagree about what a preset is.
  readonly property var chargeLimitPresets: Config.chargeLimitPresets
  readonly property string batteryStateText: root.batteryCharging ? "Charging"
    : (root.batteryOnAc ? "AC" : "Discharging")
  readonly property string batteryStatusText: root.hasBattery
    ? root.batteryStateText + " \u00b7 " + Format.watts(Math.abs(root.batteryPower))
    : "No battery"

  // Counts above 0, up to date, or unknown.
  readonly property int updateCount: root.updateService ? root.updateService.count : -1
  readonly property string updateText: root.updateCount > 0 ? String(root.updateCount)
    : (root.updateCount === 0 ? "UP TO DATE" : "?")
  readonly property bool updateIsCount: root.updateCount > 0

  // Bluetooth: the badge counts live connections, not the BlueZ device tree.
  // `Bluetooth.devices` holds every device the adapter has ever paired with or
  // merely seen, so its length is a "known" count and would read 6 with
  // nothing connected. Paired-but-idle mice are not connected devices.
  readonly property var bluetoothDevices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property int bluetoothConnected: root.bluetoothDevices.filter(d => d.connected).length
  readonly property int bluetoothKnown: root.bluetoothDevices.length

  readonly property var volumes: root.storageService ? root.storageService.volumes : []
  readonly property int storageRingSize: Theme.ringDiameter
  readonly property real storageCellW: (root.colCW - 2 * Theme.cardPadX - root.gut) / 2
  readonly property string uptimeText: root.storageService && root.storageService.uptimeSeconds > 0
    ? Format.uptime(root.storageService.uptimeSeconds) : "--"
  readonly property string batteryTimeText: {
    if (!root.batteryService || !root.batteryService.battery) return ""
    var seconds = root.batteryCharging
      ? root.batteryService.battery.timeToFull
      : root.batteryService.battery.timeToEmpty
    return seconds > 0 ? Format.uptime(seconds) + (root.batteryCharging ? " to full" : " remaining") : ""
  }

  // "foxware · 7.2.11": the release part of the kernel fits the caption line.
  readonly property string hostLine: {
    var host = root.hostName.length > 0 ? root.hostName : "\u2014"
    var rel = root.kernelVersion.split("-")[0]
    return rel.length > 0 ? host + " \u00b7 " + rel : host
  }
  // The two ASUS cards are only meaningful where their tool is installed.
  // GpuModeService answers that once at startup; here it decides whether the
  // row exists at all, so a non-ASUS machine sees a shorter right column
  // rather than two cards stuck on "--".
  readonly property bool profileToolAvailable: root.gpuModeService
    ? root.gpuModeService.asusctlAvailable : false
  readonly property bool gpuToolAvailable: root.gpuModeService
    ? root.gpuModeService.supergfxctlAvailable : false
  readonly property bool asusRowVisible: root.profileToolAvailable || root.gpuToolAvailable
  readonly property bool chargeLimitSupported: root.batteryService
    ? root.batteryService.chargeLimitSupported : false
  readonly property bool chargeLimitRead: root.batteryService
    ? root.batteryService.chargeLimitRead : false

  readonly property string profileText: root.powerProfile.length > 0
    ? root.powerProfile : "--"
  readonly property string gpuModeText: root.gpuMode.length > 0
    ? root.gpuMode.toUpperCase() : "--"
  readonly property string gpuStateText: {
    var state = root.gpuPowerStatus.toLowerCase()
    if (state.indexOf("suspend") >= 0 || state.indexOf("off") >= 0) return "SUSPENDED"
    if (state.length > 0) return "ACTIVE"
    return "GPU"
  }
  readonly property string nextGpuMode: {
    var modes = root.gpuModeService ? root.gpuModeService.availableGpuModes : []
    for (var i = 0; i < modes.length; i++)
      if (modes[i] !== root.gpuMode) return modes[i]
    return ""
  }

  // ===========================================================================
  // Animation and sampling
  // ===========================================================================

  property real entranceProgress: 1
  readonly property real _entranceStep: 0.04
  readonly property real _entranceSpan: 0.22
  function cardAlpha(index) {
    if (root.entranceProgress >= 1) return 1
    return Math.max(0, Math.min(1,
      (root.entranceProgress - index * root._entranceStep) / root._entranceSpan))
  }
  function playEntrance() { root.entranceProgress = 0; entranceAnim.restart() }
  NumberAnimation {
    id: entranceAnim
    target: root
    property: "entranceProgress"
    from: 0
    to: 1
    duration: 350
    easing.type: Easing.OutQuad
  }

  property var cpuHistory: []
  property var gpuHistory: []
  readonly property int historyMax: Theme.graphSampleCount

  function pushSample(arr, v) {
    var a = arr.slice()
    var next = Number(v)
    if (!isFinite(next) || next < 0 || next > 100)
      next = a.length ? a[a.length - 1] : 0
    a.push(next)
    if (a.length > root.historyMax) a = a.slice(a.length - root.historyMax)
    return a
  }

  width: root.contentWidth
  height: root.contentHeight
  opacity: root.active ? 1 : 0

  onActiveChanged: {
    if (root.active) {
      var today = new Date()
      root.viewYear = today.getFullYear()
      root.viewMonth = today.getMonth()
      root.rebuildCalendar()
    }
  }

  // The graphs advance on the service read (2 s), not on a timer of their own.
  // The old 1 s timer pushed the same CPU value twice between two reads and
  // forced a repaint of both sparklines for no new information.
  onCpuLoadChanged: {
    if (root.active && root.cpuReady)
      root.cpuHistory = root.pushSample(root.cpuHistory, root.cpuLoad)
  }
  onGpuLoadNowChanged: {
    if (root.active) root.gpuHistory = root.pushSample(root.gpuHistory, root.gpuLoadNow)
  }

  function start() {
    root.cpuHistory = Array(root.historyMax - 1).fill(0)
    root.gpuHistory = Array(root.historyMax - 1).fill(0)
    if (root.systemStatsService) root.systemStatsService.start()
    if (root.thermalService) root.thermalService.start()
    if (root.gpuModeService) root.gpuModeService.start()
    if (root.networkService) root.networkService.startStats()
    if (root.processStatsService) root.processStatsService.start()
    if (root.updateService) root.updateService.start()
    if (root.storageService) root.storageService.start()
    if (root.weatherService) root.weatherService.active = true
    // The EC's charge threshold changes outside the shell (BIOS, another
    // tool), and the chips must not show yesterday's answer. One read per
    // panel open; the service re-reads after every write.
    if (root.batteryService) root.batteryService.refreshChargeLimit()
    var today = new Date()
    root.viewYear = today.getFullYear()
    root.viewMonth = today.getMonth()
    rebuildCalendar()
    playEntrance()
  }
  function stop() {
    root.cpuHistory = []
    root.gpuHistory = []
    if (root.systemStatsService) root.systemStatsService.stop()
    if (root.thermalService) root.thermalService.stop()
    if (root.gpuModeService) root.gpuModeService.stop()
    if (root.networkService) root.networkService.stopStats()
    if (root.processStatsService) root.processStatsService.stop()
    if (root.updateService) root.updateService.stop()
    if (root.storageService) root.storageService.stop()
    if (root.weatherService) root.weatherService.active = false
  }

  // ===========================================================================
  // Layout — three columns, ten units each
  // ===========================================================================

  Row {
    id: grid
    width: root.bodyW
    height: root.bodyH
    spacing: root.gut

    // -------------------------------------------------------------------------
    // LEFT — 196px — clock + calendar (7u) · top processes (3u)
    // -------------------------------------------------------------------------
    Column {
      id: colA
      width: root.colAW
      height: grid.height
      spacing: root.gut

      // --- clock + calendar (7u) ---------------------------------------------
      Card {
        width: colA.width
        height: root.h7
        entranceIndex: 0

        Column {
          id: clockCol
          width: colA.width - 2 * Theme.cardPadX
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: root.clockGap

          Hero {
            width: parent.width
            height: root.mHeroH
            text: Qt.formatDateTime(root.now, "HH:mm")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideNone
          }

          Item {
            width: parent.width
            height: root.mValueH

            Row {
              width: parent.width
              anchors.centerIn: parent
              spacing: Theme.gapSmall

              Item {
                width: Theme.monthArrowHitSize
                height: root.mValueH
                Txt {
                  anchors.centerIn: parent
                  width: parent.width
                  text: "\u25c0"
                  color: Theme.label
                  variant: "body"
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideNone
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.prevMonth()
                }
              }

              Value {
                width: parent.width - 2 * Theme.monthArrowHitSize - 2 * Theme.gapSmall
                height: root.mValueH
                verticalAlignment: Text.AlignVCenter
                text: root.monthTitle

                TapHandler {
                  onTapped: {
                    var today = new Date()
                    root.viewYear = today.getFullYear()
                    root.viewMonth = today.getMonth()
                    root.rebuildCalendar()
                    root.userActivity()
                  }
                }
              }

              Item {
                width: Theme.monthArrowHitSize
                height: root.mValueH
                Txt {
                  anchors.centerIn: parent
                  width: parent.width
                  text: "\u25b6"
                  color: Theme.label
                  variant: "body"
                  horizontalAlignment: Text.AlignHCenter
                  elide: Text.ElideNone
                }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.nextMonth()
                }
              }
            }
          }

          Row {
            width: parent.width
            height: root.mCaptionH
            Repeater {
              model: ["S", "M", "T", "W", "T", "F", "S"]
              delegate: Caption {
                required property var modelData
                width: root.calendarCellW
                height: root.mCaptionH
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                elide: Text.ElideNone
              }
            }
          }

          Column {
            width: parent.width
            spacing: 0
            Repeater {
              model: root.weeks
              delegate: Item {
                id: weekRow
                required property var modelData
                width: clockCol.width
                height: Theme.calendarRowHeight

                Row {
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: root.calendarW
                  height: Theme.calendarRowHeight
                  Repeater {
                    model: weekRow.modelData
                    delegate: Item {
                      id: dayCell
                      required property var modelData
                      width: root.calendarCellW
                      height: Theme.calendarRowHeight

                      Rectangle {
                        anchors.centerIn: parent
                        width: Theme.calendarCellSize
                        height: Theme.calendarCellSize
                        radius: Theme.calendarCellRadius
                        color: Theme.accent
                        visible: dayCell.modelData.isToday
                      }
                      Txt {
                        anchors.centerIn: parent
                        width: parent.width
                        text: dayCell.modelData.label
                        color: dayCell.modelData.isToday ? Theme.background
                          : ((dayCell.modelData.isPast || dayCell.modelData.outside)
                            ? Theme.comment : Theme.foreground)
                        // Today is the only emphasised cell; `variant` selects a
                        // size, so the weight is set on the font directly.
                        font.weight: dayCell.modelData.isToday
                          ? Theme.fontWeightValue : Theme.fontWeightBody
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideNone
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      // --- top processes (4u) ------------------------------------------------
      Card {
        width: colA.width
        height: root.h4
        entranceIndex: 1

        Item {
          anchors.fill: parent
          anchors.leftMargin: Theme.cardPadX
          anchors.rightMargin: Theme.cardPadX
          anchors.topMargin: Theme.cardPadY
          anchors.bottomMargin: Theme.cardPadY

          Caption {
            id: procCaption
            width: parent.width
            height: root.mCaptionH
            verticalAlignment: Text.AlignVCenter
            text: "TOP PROCESSES"
          }

          Item {
            id: procBody
            anchors.top: procCaption.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.gapMedium

            Row {
              id: procHeader
              width: parent.width
              height: root.mCaptionH
              spacing: 0

              Caption {
                width: root.procNameW
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                text: "NAME"
              }
              Caption {
                width: Theme.procCpuColWidth
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: "CPU"
              }
              Caption {
                width: Theme.procRamColWidth
                height: parent.height
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: "RAM"
              }
            }

            Column {
              anchors.top: procHeader.bottom
              anchors.topMargin: Theme.gapSmall
              width: parent.width
              spacing: root.procRowGap

              Repeater {
                model: root.procRows
                delegate: Item {
                  id: procRow
                  required property var modelData
                  required property int index
                  width: procBody.width
                  height: root.mBodyH

                  Row {
                    width: parent.width
                    height: root.mBodyH
                    spacing: 0

                    Body {
                      width: root.procNameW
                      height: parent.height
                      verticalAlignment: Text.AlignVCenter
                      elide: Text.ElideNone
                      clip: true
                      text: procRow.modelData.name
                    }
                    Body {
                      width: Theme.procCpuColWidth
                      height: parent.height
                      horizontalAlignment: Text.AlignRight
                      verticalAlignment: Text.AlignVCenter
                      elide: Text.ElideNone
                      clip: true
                      text: Format.percent1(procRow.modelData.cpu)
                    }
                    Body {
                      width: Theme.procRamColWidth
                      height: parent.height
                      horizontalAlignment: Text.AlignRight
                      verticalAlignment: Text.AlignVCenter
                      elide: Text.ElideNone
                      clip: true
                      text: Format.percent1(procRow.modelData.memory)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // MIDDLE — 232px — toggles (1u) · controls (2u) · cpu|gpu (2u) ·
    // ram|fan (2u) · network (2u) · weather (2u)
    // -------------------------------------------------------------------------
    Column {
      id: colB
      width: root.colBW
      height: grid.height
      spacing: root.gut

      // --- quick toggles (1u) ------------------------------------------------
      Card {
        width: colB.width
        height: root.h1
        entranceIndex: 2

        Row {
          anchors.fill: parent
          anchors.leftMargin: Theme.cardPadX
          anchors.rightMargin: Theme.cardPadX
          anchors.topMargin: Theme.cardPadYDense
          anchors.bottomMargin: Theme.cardPadYDense
          spacing: Theme.gapSmall

          ToggleChip {
            width: (parent.width - 2 * Theme.gapSmall) / 3
            height: parent.height
            label: "DND"
            iconType: "moon"
            tooltip: "Do Not Disturb"
            active: root.notificationLayer ? root.notificationLayer.dnd : false
            onToggled: {
              root.userActivity()
              if (root.notificationLayer) root.notificationLayer.toggleDnd()
            }
          }
          ToggleChip {
            width: (parent.width - 2 * Theme.gapSmall) / 3
            height: parent.height
            label: "AWAKE"
            iconType: "eye"
            tooltip: "Keep awake"
            active: root.idleInhibitController
              ? root.idleInhibitController.idleInhibitEnabled : false
            onToggled: {
              root.userActivity()
              if (root.idleInhibitController)
                root.idleInhibitController.idleInhibitEnabled =
                  !root.idleInhibitController.idleInhibitEnabled
            }
          }
          ToggleChip {
            width: (parent.width - 2 * Theme.gapSmall) / 3
            height: parent.height
            label: "BT"
            badge: root.bluetoothConnected
            iconType: "bluetooth"
            tooltip: "Bluetooth · " + root.bluetoothConnected + " connected · "
              + root.bluetoothKnown + " known"
            active: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
            onToggled: {
              root.userActivity()
              if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
            }
          }
        }
      }

      // --- volume + brightness (2u) ------------------------------------------
      Card {
        width: colB.width
        height: root.h2
        entranceIndex: 3

        Column {
          width: colB.width - 2 * Theme.cardPadX
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: Theme.gapMedium

          Row {
            width: parent.width
            height: Theme.controlRowHeight
            spacing: 0

            Caption {
              width: Theme.controlLabelWidth
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: "VOL"
            }
            Item {
              width: Theme.controlIconWidth
              height: parent.height
              SpeakerIcon {
                anchors.centerIn: parent
                width: Theme.speakerIconSize
                height: Theme.speakerIconSize
                muted: root.audioService ? root.audioService.muted : false
                strokeColor: root.audioService && root.audioService.muted
                  ? Theme.red : Theme.label
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.userActivity()
                  if (root.audioService) root.audioService.toggleMute()
                }
              }
            }
            Item {
              width: parent.width - (Theme.controlLabelWidth + Theme.controlIconWidth
                + root.gut + Theme.controlValueWidth + Theme.gapTight
                + Theme.chevronIconSize)
              height: parent.height
              SliderBar {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                minValue: 0
                maxValue: 1
                step: 0.05
                value: root.audioService ? root.audioService.volume : 0
                fillColor: root.audioService && root.audioService.muted
                  ? Theme.red : Theme.accent
                onChanged: v => {
                  if (root.audioService) {
                    root.audioService.requestFastPoll()
                    root.audioService.setVolume(v)
                  }
                }
                onInteraction: root.userActivity()
              }
            }
            Item {
              width: root.gut
              height: parent.height
            }
            Body {
              width: Theme.controlValueWidth
              height: parent.height
              horizontalAlignment: Text.AlignRight
              verticalAlignment: Text.AlignVCenter
              color: root.audioService && root.audioService.muted
                ? Theme.red : Theme.foreground
              text: root.audioService
                ? Format.percent(root.audioService.volume * 100) : "--"
            }
            Item {
              width: Theme.gapTight
              height: parent.height
            }
            Item {
              id: deviceMenuAnchor
              width: Theme.chevronIconSize
              height: parent.height
              ChevronIcon {
                anchors.centerIn: parent
                width: Theme.chevronIconSize
                height: Theme.chevronIconSize
                strokeColor: Theme.label
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

          Row {
            width: parent.width
            height: Theme.controlRowHeight
            spacing: 0

            Caption {
              width: Theme.controlLabelWidth
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              text: "BRI"
            }
            Item {
              width: Theme.controlIconWidth
              height: parent.height
              SunIcon {
                anchors.centerIn: parent
                width: Theme.speakerIconSize
                height: Theme.speakerIconSize
                strokeColor: Theme.label
              }
            }
            Item {
              width: parent.width - (Theme.controlLabelWidth + Theme.controlIconWidth
                + root.gut + Theme.controlValueWidth + Theme.gapTight
                + Theme.chevronIconSize)
              height: parent.height
              SliderBar {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                minValue: 1
                maxValue: 100
                step: 5
                value: root.brightnessService ? root.brightnessService.displayPercent : 50
                fillColor: root.brightnessService && root.brightnessService.displayPercent > 20
                  ? Theme.accent : Theme.red
                onChanged: v => {
                  if (root.brightnessService) {
                    root.brightnessService.requestFastPoll()
                    root.brightnessService.setPercent(v)
                  }
                }
                onInteraction: root.userActivity()
              }
            }
            Item {
              width: root.gut
              height: parent.height
            }
            Body {
              width: Theme.controlValueWidth
              height: parent.height
              horizontalAlignment: Text.AlignRight
              verticalAlignment: Text.AlignVCenter
              text: root.brightnessService
                ? Format.percent(root.brightnessService.displayPercent) : "--"
            }
            Item {
              width: Theme.gapTight
              height: parent.height
            }
            Item {
              width: Theme.chevronIconSize
              height: parent.height
            }
          }
        }

        AudioDeviceMenu {
          id: audioDeviceMenu
          x: -(width - deviceMenuAnchor.width)
          y: deviceMenuAnchor.y + deviceMenuAnchor.height
          audioService: root.audioService
          onUserActivity: root.userActivity()
        }
      }

      // --- cpu | gpu (2u) ----------------------------------------------------
      Row {
        width: colB.width
        height: root.h2
        spacing: root.gut

        Card {
          width: root.halfBW
          height: parent.height
          entranceIndex: 4

          Column {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadXDense
            anchors.rightMargin: Theme.cardPadXDense
            anchors.topMargin: Theme.cardPadYDense
            anchors.bottomMargin: Theme.cardPadYDense
            spacing: Theme.gapTight

            Caption {
              width: parent.width
              height: root.mCaptionH
              verticalAlignment: Text.AlignVCenter
              text: "CPU"
            }
            Row {
              width: parent.width
              height: root.mValueH
              spacing: 0
              Value {
                width: Theme.metricValueWidth
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                color: root.cpuReady ? Theme.loadColor(root.cpuLoad) : Theme.comment
                text: root.cpuReady ? Format.percent(root.cpuLoad) : "--"
              }
              Item {
                width: Theme.gapSmall
                height: parent.height
              }
              Body {
                width: parent.width - Theme.metricValueWidth - Theme.gapSmall
                height: parent.height
                verticalAlignment: Text.AlignBottom
                color: root.cpuTemp > 0 ? Theme.temperatureColor(root.cpuTemp) : Theme.comment
                text: root.cpuTemp > 0 ? Format.temp(root.cpuTemp) : "--"
              }
            }
            LineGraph {
              width: parent.width
              // The graph takes whatever the two text lines leave behind, so
              // the card never overflows and nothing sits on the border.
              height: parent.height - root.mCaptionH - root.mValueH - 2 * Theme.gapTight
              samples: root.cpuHistory
              color: root.cpuReady ? Theme.graphColor(root.cpuLoad) : Theme.comment
              maxValue: 100
            }
          }
        }

        Card {
          width: root.halfBW
          height: parent.height
          entranceIndex: 5

          Column {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadXDense
            anchors.rightMargin: Theme.cardPadXDense
            anchors.topMargin: Theme.cardPadYDense
            anchors.bottomMargin: Theme.cardPadYDense
            spacing: Theme.gapTight

            Caption {
              width: parent.width
              height: root.mCaptionH
              verticalAlignment: Text.AlignVCenter
              text: {
                var t = root.thermalService
                if (!t) return "GPU"
                if (t.showIgpu) return "GPU . IGPU"
                return t.gpuReading ? "GPU" : "GPU . SUSPENDED"
              }
            }
            Row {
              width: parent.width
              height: root.mValueH
              spacing: 0
              Value {
                width: Theme.metricValueWidth
                height: parent.height
                verticalAlignment: Text.AlignVCenter
                color: root.thermalService && root.thermalService.gpuReading
                  ? Theme.loadColor(root.thermalService.gpuLoadOut) : Theme.comment
                text: root.thermalService && root.thermalService.gpuReading
                  ? Format.percent(root.thermalService.gpuLoadOut) : "--"
              }
              Item {
                width: Theme.gapSmall
                height: parent.height
              }
              Body {
                width: parent.width - Theme.metricValueWidth - Theme.gapSmall
                height: parent.height
                verticalAlignment: Text.AlignBottom
                color: root.thermalService && root.thermalService.gpuReading
                  ? Theme.temperatureColor(root.thermalService.gpuTempOut) : Theme.comment
                text: root.thermalService && root.thermalService.gpuReading
                  ? Format.temp(root.thermalService.gpuTempOut) : "--"
              }
            }
            LineGraph {
              width: parent.width
              height: parent.height - root.mCaptionH - root.mValueH - 2 * Theme.gapTight
              samples: root.gpuHistory
              color: (root.thermalService && !root.thermalService.gpuReading)
                ? Theme.comment : Theme.graphColor(root.thermalService
                    ? root.thermalService.gpuLoadOut : 0)
              maxValue: 100
            }
          }
        }
      }

      // --- ram | fan (2u) ----------------------------------------------------
      Row {
        width: colB.width
        height: root.h2
        spacing: root.gut

        Card {
          width: root.halfBW
          height: parent.height
          entranceIndex: 6

          Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadXDense
            anchors.rightMargin: Theme.cardPadXDense

            Column {
              id: ramRow
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: Theme.gapMedium

              Column {
                width: parent.width
                spacing: Theme.gapTight
                Caption {
                  width: parent.width
                  height: root.mCaptionH
                  verticalAlignment: Text.AlignBottom
                  text: "RAM"
                }
                // The percentage is the alarm signal, so it leads the card and
                // takes the memory ramp: yellow from 60%, orange from 78%, red
                // from 90% (Theme.memoryColor, shared with the bar below).
                Value {
                  id: ramValue
                  width: parent.width
                  height: root.mValueH
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                  color: root.ramReady ? Theme.memoryColor(root.ramPercent) : Theme.comment
                  text: root.ramReady ? Format.percent(root.ramPercent) : "--"
                  elide: Text.ElideNone
                }
                Caption {
                  width: parent.width
                  height: root.mCaptionH
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                  color: root.ramReady ? Theme.label : Theme.comment
                  text: Format.usedTotal(root.ramUsed, root.ramTotal)
                  elide: Text.ElideNone
                }
              }

              Row {
                width: parent.width
                height: Theme.ramBarHeight
                spacing: Theme.batteryBarGap
                Repeater {
                  model: Theme.batteryBarSegments
                  delegate: Rectangle {
                    required property int index
                    width: (parent.width - (Theme.batteryBarSegments - 1) * Theme.batteryBarGap)
                      / Theme.batteryBarSegments
                    height: Theme.ramBarHeight
                    radius: Theme.batteryBarRadius
                    color: index < Math.round(root.ramPercent / 10)
                      ? Theme.memoryColor(root.ramPercent) : Theme.selection
                  }
                }
              }
            }
          }
        }

        Card {
          width: root.halfBW
          height: parent.height
          entranceIndex: 7

          Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadXDense
            anchors.rightMargin: Theme.cardPadXDense

            Column {
              id: fanRow
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: Theme.gapTight

              Caption {
                width: parent.width
                height: Theme.fanHeaderHeight
                verticalAlignment: Text.AlignVCenter
                text: "FAN . RPM"
              }
              Row {
                width: parent.width
                height: Theme.fanLineHeight
                Caption { width: Theme.fanLabelWidth; height: parent.height; verticalAlignment: Text.AlignVCenter; text: "CPU" }
                Value {
                  width: parent.width - Theme.fanLabelWidth
                  height: parent.height
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                  color: root.cpuFanSpeed > 0 ? Theme.foreground : Theme.comment
                  text: root.cpuFanSpeed >= 0 ? String(Math.round(root.cpuFanSpeed)) : "N/A"
                }
              }
              Row {
                width: parent.width
                height: Theme.fanLineHeight
                Caption { width: Theme.fanLabelWidth; height: parent.height; verticalAlignment: Text.AlignVCenter; text: "GPU" }
                Value {
                  width: parent.width - Theme.fanLabelWidth
                  height: parent.height
                  horizontalAlignment: Text.AlignRight
                  verticalAlignment: Text.AlignVCenter
                  color: root.gpuFanSpeed > 0 ? Theme.foreground : Theme.comment
                  text: root.gpuFanSpeed >= 0 ? String(Math.round(root.gpuFanSpeed)) : "N/A"
                }
              }
            }
          }
        }
      }

      // --- network (2u) ------------------------------------------------------
      Card {
        width: colB.width
        height: root.h2
        entranceIndex: 8

        Column {
          width: colB.width - 2 * Theme.cardPadX
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: root.gut

          Row {
            width: parent.width
            height: root.mValueH
            spacing: Theme.gapSmall
            Value {
              width: Theme.networkGlyphWidth
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              color: Theme.label
              text: "\u2193"
            }
            Value {
              width: parent.width - Theme.networkGlyphWidth - Theme.gapSmall
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              color: root.netConnected ? Theme.foreground : Theme.comment
              text: root.netConnected ? Format.rate(root.netRxRate) : "--"
            }
          }
          Row {
            width: parent.width
            height: root.mValueH
            spacing: Theme.gapSmall
            Value {
              width: Theme.networkGlyphWidth
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              color: Theme.label
              text: "\u2191"
            }
            Value {
              width: parent.width - Theme.networkGlyphWidth - Theme.gapSmall
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              color: root.netConnected ? Theme.foreground : Theme.comment
              text: root.netConnected ? Format.rate(root.netTxRate) : "--"
            }
          }
          Row {
            width: parent.width
            height: root.mCaptionH
            spacing: Theme.gapSmall
            Caption {
              width: parent.width - Theme.latencyColWidth - Theme.gapSmall
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideNone
              clip: true
              text: root.wifiSsid.length > 0 ? root.wifiSsid : "\u2014"
            }
            Body {
              width: Theme.latencyColWidth
              height: parent.height
              horizontalAlignment: Text.AlignRight
              verticalAlignment: Text.AlignVCenter
              color: Theme.latencyColor(root.netLatency)
              text: Format.latency(root.netLatency)
            }
          }
        }
      }

      // --- weather (2u) ------------------------------------------------------
      Card {
        width: colB.width
        height: root.h2
        entranceIndex: 9

        Row {
          width: root.weatherInnerW
          height: parent.height - 2 * Theme.cardPadYDense
          anchors.centerIn: parent
          spacing: root.gut

          Item {
            width: Theme.weatherGlyphSize
            height: parent.height
            WeatherGlyph {
              anchors.centerIn: parent
              width: Theme.weatherGlyphSize
              height: Theme.weatherGlyphSize
              weatherCode: root.weatherService ? root.weatherService.weatherCode : -1
              isDay: root.weatherService ? root.weatherService.isDay : true
              glyphColor: Theme.label
            }
          }

          Item {
            width: root.weatherTextActualW
            height: parent.height
            Column {
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0
              Caption {
                width: parent.width
                height: root.mCaptionH
                verticalAlignment: Text.AlignVCenter
                text: root.weatherCityText
                color: Theme.weatherCity
              }
              Value {
                width: parent.width
                height: root.mValueH
                verticalAlignment: Text.AlignVCenter
                text: root.weatherService ? Format.temp(root.weatherService.tempC) : "--"
              }
              Body {
                width: parent.width
                height: root.conditionSize === Theme.fontSizeBody
                  ? root.mBodyH : root.mCaptionH
                verticalAlignment: Text.AlignVCenter
                variant: root.conditionSize === Theme.fontSizeBody ? "body" : "caption"
                text: root.conditionText
              }
              Caption {
                id: weatherSummary
                width: parent.width
                height: root.mCaptionH
                verticalAlignment: Text.AlignVCenter
                text: root.weatherSummaryText
                upper: false
                ToolTip.visible: weatherSummaryHover.hovered && root.weatherSummaryText !== root.highLowText
                ToolTip.text: "Feels like " + Format.temp(root.weatherService ? root.weatherService.feelsLikeC : 0)
                ToolTip.delay: Theme.tooltipDelay
                HoverHandler { id: weatherSummaryHover }
              }
            }
          }

          Item {
            visible: root.weatherShowSun && root.weatherHasSun
            width: Theme.weatherSunColWidth
            height: parent.height
            Column {
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0
              Caption {
                width: parent.width
                height: root.mCaptionH
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: root.weatherService
                  ? "\u2191 " + root.weatherService.sunriseText : "--"
              }
              Caption {
                width: parent.width
                height: root.mCaptionH
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: root.weatherService
                  ? "\u2193 " + root.weatherService.sunsetText : "--"
              }
            }
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // RIGHT — 196px — identity (1u) · power (3u) · profile|gpu (1u) ·
    // storage (4u) · updates|uptime (1u)
    // -------------------------------------------------------------------------
    Column {
      id: colC
      width: root.colCW
      height: grid.height
      spacing: root.gut

      // --- identity (1u) -----------------------------------------------------
      Card {
        width: colC.width
        height: root.h1
        entranceIndex: 10

        Item {
          anchors.fill: parent
          anchors.leftMargin: Theme.cardPadXFlush
          anchors.rightMargin: Theme.cardPadXFlush

          Column {
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Value {
              width: parent.width
              height: root.mValueH
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideNone
              clip: true
              text: root.userName.length > 0 ? root.userName : "\u2014"
            }
            Caption {
              width: parent.width
              height: root.mCaptionH
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideNone
              clip: true
              text: root.hostLine
            }
          }
        }
      }

      // --- power (4u) --------------------------------------------------------
      Card {
        width: colC.width
        height: root.h4
        entranceIndex: 11

        Column {
          width: colC.width - 2 * Theme.cardPadX
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Hero {
            width: parent.width
            height: root.mHeroH
            verticalAlignment: Text.AlignVCenter
            color: root.hasBattery
              ? Theme.batteryColor(root.batteryCapacity, root.batteryCharging) : Theme.comment
            text: root.hasBattery ? Format.percent(root.batteryCapacity) : "--"
          }

          Item {
            width: parent.width
            height: Theme.gapSmall
          }

          Row {
            width: parent.width
            height: Theme.batteryBarHeight
            spacing: Theme.batteryBarGap

            Repeater {
              model: Theme.batteryBarSegments
              delegate: Rectangle {
                required property int index
                width: (parent.width - (Theme.batteryBarSegments - 1)
                  * Theme.batteryBarGap) / Theme.batteryBarSegments
                height: Theme.batteryBarHeight
                radius: Theme.batteryBarRadius
                color: index < root.batteryFillSegments
                  ? Theme.batteryColor(root.batteryCapacity, root.batteryCharging)
                  : Theme.selection
              }
            }
          }

          Item {
            width: parent.width
            height: Theme.gapSmall
          }

          Body {
            width: parent.width
            height: root.mBodyH
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideNone
            clip: true
            text: root.batteryStatusText
          }

          Body {
            width: parent.width
            height: root.mBodyH
            verticalAlignment: Text.AlignVCenter
            color: Theme.comment
            text: root.batteryTimeText
            visible: root.batteryTimeText.length > 0
          }

          Item {
            // No asusd means no threshold to show or set, so the spacer and the
            // whole limit row go away instead of printing a placeholder.
            visible: root.chargeLimitSupported
            width: parent.width
            height: Theme.gapSmall
          }

          Row {
            visible: root.chargeLimitSupported
            width: parent.width
            height: Theme.chipHeight
            spacing: Theme.gapSmall
            Caption {
              // Only a failed/absent read falls back to text. The three presets
              // stay clickable even when the EC reports a value outside them —
              // otherwise a machine left on 60% would lose its controls.
              visible: !root.chargeLimitRead
              width: parent.width
              height: parent.height
              verticalAlignment: Text.AlignVCenter
              color: root.batteryService && root.batteryService.chargeLimitReading
                ? Theme.comment : Theme.label
              text: root.batteryService && root.batteryService.chargeLimitReading
                ? "LIMIT WAIT" : "LIMIT N/A"
            }

            Row {
              visible: root.chargeLimitRead
              width: parent.width
              height: Theme.chipHeight
              spacing: Theme.gapSmall
              Repeater {
                model: root.chargeLimitRead
                  ? root.chargeLimitPresets.map(function (p) { return p.pct }) : []
                delegate: LimitChip {
                  required property int modelData
                  limit: modelData
                  height: Theme.chipHeight
                  width: Math.floor((parent.width
                    - (root.chargeLimitPresets.length - 1) * Theme.gapSmall)
                    / root.chargeLimitPresets.length)
                }
              }
            }
          }
        }
      }

      // --- profile | gpu mode (1u, ASUS only) --------------------------------
      Row {
        width: colC.width
        height: root.h1
        spacing: root.gut
        visible: root.asusRowVisible

        Card {
          visible: root.profileToolAvailable
          width: root.gpuToolAvailable ? root.halfCW : colC.width
          height: parent.height
          entranceIndex: 12

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.gpuModeService) root.gpuModeService.cyclePowerProfile()
              root.userActivity()
            }
          }

          Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadXDense
            anchors.rightMargin: Theme.cardPadXDense

            Column {
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0
              Caption {
                width: parent.width
                height: root.mCaptionH
                verticalAlignment: Text.AlignVCenter
                text: "PROFILE"
              }
              Value {
                width: parent.width
                height: root.mBodyH
                verticalAlignment: Text.AlignVCenter
                variant: "body"
                text: root.profileText
                elide: Text.ElideRight
                clip: true
              }
            }
          }
        }

        Card {
          visible: root.gpuToolAvailable
          width: root.profileToolAvailable ? root.halfCW : colC.width
          height: parent.height
          entranceIndex: 13

          MouseArea {
            anchors.fill: parent
            cursorShape: root.nextGpuMode.length > 0
              ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.nextGpuMode.length > 0
            onClicked: {
              root.pendingGpuMode = root.nextGpuMode
              root.gpuConfirming = true
              root.userActivity()
            }
          }

          Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadXDense
            anchors.rightMargin: Theme.cardPadXDense

            Column {
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0
              Row {
                width: parent.width
                height: root.mCaptionH
                spacing: Theme.gapTight
                Caption {
                  width: parent.width - 2 * Theme.gapTight
                  height: parent.height
                  verticalAlignment: Text.AlignVCenter
                  text: "GPU MODE"
                }
                Rectangle {
                  width: Theme.gapTight
                  height: Theme.gapTight
                  radius: Theme.gapTight / 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: root.gpuStateText === "SUSPENDED" ? Theme.comment : Theme.accent
                }
              }
              Value {
                width: parent.width
                height: root.mBodyH
                verticalAlignment: Text.AlignVCenter
                variant: "body"
                text: root.gpuModeText
                elide: Text.ElideRight
                clip: true
              }
            }
          }
        }
      }

      // --- storage (4u, or 5u when the ASUS row is hidden) --------------------
      Card {
        width: colC.width
        height: root.asusRowVisible ? root.h4 : root.h4 + root.h1 + root.gut
        entranceIndex: 14

        Item {
          anchors.fill: parent
          anchors.leftMargin: Theme.cardPadX
          anchors.rightMargin: Theme.cardPadX
          anchors.topMargin: Theme.cardPadY
          anchors.bottomMargin: Theme.cardPadY

          Caption {
            id: storageCaption
            width: parent.width
            height: root.mCaptionH
            verticalAlignment: Text.AlignVCenter
            text: "STORAGE"
          }

          Item {
            id: storageHost
            anchors.top: storageCaption.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.topMargin: Theme.gapMedium

            Row {
              id: storageRow
              width: parent.width
              height: parent.height
              spacing: root.gut

              Repeater {
                model: root.volumes
                delegate: Item {
                  id: storageCell
                  required property var modelData
                  width: root.storageCellW
                  height: storageRow.height

                  Column {
                    width: parent.width
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Item {
                      width: parent.width
                      height: root.storageRingSize
                      RingGauge {
                        anchors.centerIn: parent
                        diameter: root.storageRingSize
                        thickness: Theme.ringThickness
                        value: storageCell.modelData.percent
                      }
                    }
                    Item {
                      width: parent.width
                      height: Theme.gapSmall
                    }
                    Row {
                      width: parent.width
                      height: root.mCaptionH
                      spacing: Theme.gapTight
                      DriveIcon {
                        width: Theme.toggleIconSize
                        height: root.mCaptionH
                        anchors.verticalCenter: parent.verticalCenter
                      }
                      Caption {
                        width: parent.width - Theme.toggleIconSize - Theme.gapTight
                        height: parent.height
                        verticalAlignment: Text.AlignVCenter
                        text: storageCell.modelData.label
                      }
                    }
                    Item {
                      width: parent.width
                      height: Theme.gapTight
                    }
                    Body {
                      width: parent.width
                      height: root.mBodyH
                      horizontalAlignment: Text.AlignHCenter
                      verticalAlignment: Text.AlignVCenter
                      text: Format.usedTotal(storageCell.modelData.used,
                        storageCell.modelData.size)
                    }
                  }
                }
              }
            }
          }
        }
      }

      // --- updates | uptime (1u) ---------------------------------------------
      Row {
        width: colC.width
        height: root.h1
        spacing: root.gut

        Card {
          width: root.halfCW
          height: parent.height
          entranceIndex: 15

          Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadXDense
            anchors.rightMargin: Theme.cardPadXDense

            Column {
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0
              Caption {
                width: parent.width
                height: root.mCaptionH
                verticalAlignment: Text.AlignVCenter
                text: "UPDATES"
              }
              Value {
                width: parent.width
                height: root.updateIsCount ? root.mValueH : root.mBodyH
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                variant: root.updateIsCount ? "value" : "body"
                color: root.updateCount === 0 ? Theme.green
                  : (root.updateCount > 0 ? Theme.foreground : Theme.comment)
                text: root.updateText
              }
            }
          }
        }

        Card {
          width: root.halfCW
          height: parent.height
          entranceIndex: 16

          Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.cardPadXDense
            anchors.rightMargin: Theme.cardPadXDense

            Column {
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: 0
              Caption {
                width: parent.width
                height: root.mCaptionH
                verticalAlignment: Text.AlignVCenter
                text: "UPTIME"
              }
              Value {
                width: parent.width
                height: root.mValueH
                verticalAlignment: Text.AlignVCenter
                text: root.uptimeText
              }
            }
          }
        }
      }
    }
  }

  // Switching GPU mode can require a logout or reboot. Ask inside the panel
  // and issue the command only from the explicit confirmation button.
  Rectangle {
    anchors.fill: parent
    visible: root.gpuConfirming
    color: Theme.background
    z: 100

    MouseArea {
      anchors.fill: parent
      onClicked: {}
    }

    Rectangle {
      width: Math.min(parent.width - Theme.gapWide * 2, 360)
      height: 150
      anchors.centerIn: parent
      radius: Theme.cardRadius
      color: Theme.cardFill
      border.width: Theme.cardBorderWidth
      border.color: Theme.cardBorderColor
      CardEdges {}

      Column {
        anchors.fill: parent
        anchors.margins: Theme.cardPadX
        spacing: Theme.gapSmall

        Caption {
          width: parent.width
          text: "CONFIRM GPU MODE"
        }
        Body {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Switch to " + root.pendingGpuMode + "? A logout or reboot may be required."
        }
        Row {
          spacing: Theme.gapSmall
          Rectangle {
            width: 88
            height: Theme.chipHeight
            radius: Theme.chipRadius
            color: Theme.selection
            Txt {
              anchors.centerIn: parent
              width: parent.width
              text: "CANCEL"
              color: Theme.foreground
              variant: "caption"
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideNone
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.gpuConfirming = false
            }
          }
          Rectangle {
            width: 88
            height: Theme.chipHeight
            radius: Theme.chipRadius
            color: Theme.accent
            Txt {
              anchors.centerIn: parent
              width: parent.width
              text: "CONFIRM"
              color: Theme.background
              variant: "caption"
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideNone
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (root.gpuModeService)
                  root.gpuModeService.setGpuMode(root.pendingGpuMode)
                root.gpuConfirming = false
              }
            }
          }
        }
      }
    }
  }

  // ===========================================================================
  // Building blocks
  // ===========================================================================

  component Card: Rectangle {
    property int entranceIndex: 0
    opacity: root.cardAlpha(entranceIndex)
    radius: Theme.cardRadius
    color: Theme.cardFill
    border.width: Theme.cardBorderWidth
    border.color: Theme.cardBorderColor
    antialiasing: true
    CardEdges {}
  }

  // caption: 10px / 600 / uppercase / 1px tracking / one muted lavender
  component Caption: Txt {
    color: Theme.label
    variant: "caption"
    elide: Text.ElideNone
    clip: true
  }

  // body: 12px / regular / foreground
  component Body: Txt {
    color: Theme.foreground
    variant: "body"
    elide: Text.ElideNone
    clip: true
  }

  // value: 15px / 700 / foreground
  component Value: Txt {
    color: Theme.foreground
    variant: "value"
    elide: Text.ElideNone
    clip: true
  }

  // hero: 24px / 700 — the clock and the battery percentage, nothing else
  component Hero: Txt {
    color: Theme.foreground
    variant: "hero"
    elide: Text.ElideNone
    clip: true
  }

  // A charge limit chip: active one is outlined and tinted, the rest is flat.
  component LimitChip: Rectangle {
    id: limitChip
    property int limit: 0
    readonly property bool isActive: root.batteryService
      ? root.batteryService.chargeLimitRead
        && root.batteryService.chargeLimit === limitChip.limit : false

    width: (parent && parent.width ? (parent.width - 2 * Theme.gapSmall) / 3 : chipLabel.width + 2 * Theme.chipPadX)
    height: Theme.chipHeight
    radius: Theme.chipRadius
    color: limitChip.isActive ? Theme.chargeLimitActiveTint : Theme.cardFill
    border.width: Theme.cardBorderWidth
    border.color: limitChip.isActive ? Theme.chargeLimitActive : Theme.cardBorderColor
    antialiasing: true
    clip: true

    Txt {
      id: chipLabel
      anchors.centerIn: parent
      width: parent.width - 2 * Theme.chipPadX
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      text: Format.percent(limitChip.limit)
      color: limitChip.isActive ? Theme.chargeLimitActive : Theme.label
      variant: "body"
      elide: Text.ElideNone
      clip: true
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.userActivity()
        if (root.batteryService) root.batteryService.setLimit(limitChip.limit)
      }
    }
  }

  // Speaker, muted as a cross. Painted once per state change.
  component SpeakerIcon: Canvas {
    id: speakerIcon
    property bool muted: false
    property color strokeColor: Theme.label

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
      ctx.strokeStyle = speakerIcon.strokeColor
      ctx.lineWidth = Math.max(1, s * 0.1)
      ctx.lineCap = "round"
      ctx.lineJoin = "round"

      ctx.beginPath()
      ctx.moveTo(s * 0.08, s * 0.36)
      ctx.lineTo(s * 0.26, s * 0.36)
      ctx.lineTo(s * 0.44, s * 0.16)
      ctx.lineTo(s * 0.44, s * 0.84)
      ctx.lineTo(s * 0.26, s * 0.64)
      ctx.lineTo(s * 0.08, s * 0.64)
      ctx.closePath()
      ctx.stroke()

      if (!speakerIcon.muted) {
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

  // Sun: a disc with eight rays.
  component SunIcon: Canvas {
    id: sunIcon
    property color strokeColor: Theme.label

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
      ctx.strokeStyle = sunIcon.strokeColor
      ctx.lineWidth = Math.max(1, s * 0.1)
      ctx.lineCap = "round"

      ctx.beginPath()
      ctx.arc(s * 0.5, s * 0.5, s * 0.22, 0, Math.PI * 2, false)
      ctx.stroke()

      for (var i = 0; i < 8; i++) {
        var a = i * Math.PI / 4
        ctx.beginPath()
        ctx.moveTo(s * (0.5 + Math.cos(a) * 0.34), s * (0.5 + Math.sin(a) * 0.34))
        ctx.lineTo(s * (0.5 + Math.cos(a) * 0.45), s * (0.5 + Math.sin(a) * 0.45))
        ctx.stroke()
      }
    }
  }

  // Downward chevron for the output device menu.
  component ChevronIcon: Canvas {
    id: chevronIcon
    property color strokeColor: Theme.label

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
      ctx.strokeStyle = chevronIcon.strokeColor
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

  component DriveIcon: Canvas {
    property color strokeColor: Theme.label
    renderTarget: Canvas.Image
    antialiasing: true
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = strokeColor
      ctx.lineWidth = Theme.toggleIconLineWidth
      ctx.lineCap = "round"
      ctx.lineJoin = "round"
      ctx.beginPath()
      ctx.rect(width * 0.08, height * 0.18, width * 0.84, height * 0.64)
      ctx.stroke()
      ctx.beginPath()
      ctx.moveTo(width * 0.18, height * 0.52)
      ctx.lineTo(width * 0.82, height * 0.52)
      ctx.moveTo(width * 0.68, height * 0.69)
      ctx.lineTo(width * 0.69, height * 0.69)
      ctx.stroke()
    }
  }

  // Slim slider: a 4px track, a filled part, drag and wheel. No behaviour on
  // the value itself, so it repaints only when the fill actually changes.
  component SliderBar: Rectangle {
    id: sliderBar
    property real minValue: 0
    property real maxValue: 1
    property real value: 0
    property real step: 0
    property color fillColor: Theme.accent
    signal changed(real v)
    signal interaction()

    implicitHeight: Theme.sliderTrackHeight
    radius: Theme.sliderTrackRadius
    color: Theme.selection

    Rectangle {
      height: parent.height
      radius: parent.radius
      color: sliderBar.fillColor
      width: sliderBar.maxValue > sliderBar.minValue
        ? Math.max(0, Math.min(parent.width,
          parent.width * (sliderBar.value - sliderBar.minValue)
            / (sliderBar.maxValue - sliderBar.minValue)))
        : 0
    }

    MouseArea {
      anchors.fill: parent
      onPressed: mouse => { sliderBar.interaction(); sliderBar._set(mouse.x) }
      onPositionChanged: mouse => {
        if (pressed) { sliderBar.interaction(); sliderBar._set(mouse.x) }
      }
      onWheel: event => {
        sliderBar.interaction()
        var dir = event.angleDelta.y > 0 ? 1 : -1
        var effStep = sliderBar.step > 0
          ? sliderBar.step : (sliderBar.maxValue - sliderBar.minValue) / 20
        sliderBar._setValue(sliderBar.value + dir * effStep)
        event.accepted = true
      }
    }

    function _set(x) {
      if (sliderBar.width <= 0) return
      var ratio = Math.max(0, Math.min(1, x / sliderBar.width))
      sliderBar._setValue(sliderBar.minValue + ratio * (sliderBar.maxValue - sliderBar.minValue))
    }
    function _setValue(v) {
      var clamped = Math.max(sliderBar.minValue, Math.min(sliderBar.maxValue, v))
      if (Math.abs(clamped - sliderBar.value) > 0.001) sliderBar.changed(clamped)
    }
  }

}
