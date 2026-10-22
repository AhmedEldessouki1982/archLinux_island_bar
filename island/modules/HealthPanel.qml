import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../config"
import "../components"
import "../services"

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
  property var cpuSamples: []
  property var gpuSamples: []
  property var ramSamples: []

  property int panelPadding: 14

  // --- forwarded services (instantiated in FloatingHealth) ---
  property var audioService: null
  property var brightnessService: null
  property var batteryService: null
  property var weatherService: null
  property var networkService: null

  // --- tier-3 services (instantiated in FloatingHealth) ---
  property var systemStatsService: null
  property var thermalService: null
  property var gpuModeService: null

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

  // --- calendar state (merged from CalendarPopup) ---
  property int year: new Date().getFullYear()
  property int month: new Date().getMonth()

  ListModel { id: gridModel }

  // --- panel geometry ---
  property int _colW1: 200
  property int _colW2: 340
  property int _colW3: 196
  property int _colGap: 12
  property int _colBlock: 194
  property color cardColor: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.3)
  property color cardBorder: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.55)

  readonly property real contentWidth: root.panelPadding * 2 + root._colW1 + root._colGap * 2 + root._colW2 + root._colW3
  readonly property real gridHeight: Math.ceil(gridModel.count / 7) * 28 - 2
  readonly property real contentHeight: Math.max(300, root.panelPadding * 2 + Math.max(calCol.height, rightCol.implicitHeight))

  width: contentWidth
  height: contentHeight

  function formatBytes(b) {
    if (b < 1024) return b.toFixed(0) + " B/s"
    if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
    return (b / 1048576).toFixed(1) + " MB/s"
  }

  function levelColor(val, warn, crit) {
    if (val >= crit) return Theme.red
    if (val >= warn) return Theme.yellow
    return Theme.foreground
  }

  function ringColor(v) {
    if (v >= 85) return Theme.red
    if (v >= 60) return Theme.yellow
    return Theme.green
  }

  function loadTempColor(load, temp) {
    var lc = levelColor(load, 60, 80)
    var tc = levelColor(temp, 65, 80)
    if (lc === Theme.red || tc === Theme.red) return Theme.red
    if (lc === Theme.yellow || tc === Theme.yellow) return Theme.yellow
    return Theme.foreground
  }

  function batteryColor(pct, charging) {
    if (charging) return Theme.green
    if (pct <= 15) return Theme.red
    if (pct <= 30) return Theme.yellow
    return Theme.foreground
  }

  function weatherStatus(code) {
    if (code === 0) return "Clear"
    if (code >= 1 && code <= 3) return "Partly Cloudy"
    if (code === 45 || code === 48) return "Foggy"
    if (code >= 51 && code <= 67) return "Raining"
    if (code >= 71 && code <= 77) return "Snowing"
    if (code >= 80 && code <= 82) return "Showers"
    if (code >= 95 && code <= 99) return "Storm"
    return "--"
  }

  // --- fixed-width value formatting (monospace subtext keeps columns aligned) ---

  function pad(s, w) {
    var str = String(s)
    while (str.length < w) str = " " + str
    return str
  }

  function padRight(s, w) {
    var str = String(s)
    while (str.length < w) str += " "
    return str
  }

  function loadTempText(load, temp, extra) {
    var t = pad(isNaN(load) ? 0 : Math.round(load), 3) + "% \u00b7 " + pad(isNaN(temp) ? 0 : temp.toFixed(0), 2) + "\u00b0"
    if (extra && extra.length > 0) t += " " + extra
    return t
  }

  function gpuStatusShown() {
    return root.gpuPowerStatus.length > 0
      && root.gpuPowerStatus !== "active"
      && root.gpuPowerStatus !== "unknown"
      && root.gpuPowerStatus !== "unset"
  }

  function fanText() {
    var cpu = isNaN(root.cpuFanSpeed) ? 0 : Math.round(root.cpuFanSpeed)
    var gpu = isNaN(root.gpuFanSpeed) ? 0 : Math.round(root.gpuFanSpeed)
    if (cpu <= 0 && gpu <= 0)
      return "IDLE"
    return "C:" + pad(cpu, 4) + " G:" + pad(gpu, 4) + " RPM"
  }

  function netText() {
    var base = "\u2193 " + padRight(root.formatBytes(root.netRxRate), 9) + "   \u2191 " + padRight(root.formatBytes(root.netTxRate), 9)
    var lat = root.networkService && root.networkService.latencyMs >= 0 ? Math.round(root.networkService.latencyMs) + "ms" : "--ms"
    return base + " \u00b7 " + lat
  }

  function networkSubText() {
    var iface = root.networkService ? root.networkService.iface : ""
    if (iface.length === 0)
      return "OFFLINE"
    var ssid = root.wifiSsid.length > 0 ? root.wifiSsid : (iface.indexOf("wl") === 0 ? "WIFI" : "ETHERNET")
    if (root.networkService && root.networkService.latencyMs >= 0)
      return ssid + " \u00b7 " + Math.round(root.networkService.latencyMs) + "ms (" + root.networkService.qualityStatus + ")"
    return ssid
  }

  function appendSample(series, value) {
    var next = series.slice(Math.max(0, series.length - 59))
    next.push(Math.max(0, Math.min(100, Number(value) || 0)))
    return next
  }

  onCpuLoadChanged: if (root.active) root.cpuSamples = root.appendSample(root.cpuSamples, root.cpuLoad)
  onGpuLoadChanged: if (root.active) root.gpuSamples = root.appendSample(root.gpuSamples, root.gpuLoad)
  onRamPercentChanged: if (root.active) root.ramSamples = root.appendSample(root.ramSamples, root.ramPercent)

  // --- calendar navigation (merged from CalendarPopup) ---

  function rebuild() {
    gridModel.clear()
    var first = new Date(root.year, root.month, 1)
    var startDow = first.getDay()
    var days = new Date(root.year, root.month + 1, 0).getDate()
    var now = new Date()
    for (var i = 0; i < startDow; i++)
      gridModel.append({ label: "", isToday: false, isPast: false })
    for (var d = 1; d <= days; d++) {
      gridModel.append({
        label: String(d),
        isToday: d === now.getDate() && root.month === now.getMonth() && root.year === now.getFullYear(),
        isPast: new Date(root.year, root.month, d) < new Date(now.getFullYear(), now.getMonth(), now.getDate())
      })
    }
  }

  function prevMonth() {
    root.userActivity()
    root.month -= 1
    if (root.month < 0) {
      root.month = 11
      root.year -= 1
    }
    root.rebuild()
  }

  function nextMonth() {
    root.userActivity()
    root.month += 1
    if (root.month > 11) {
      root.month = 0
      root.year += 1
    }
    root.rebuild()
  }

  function start() {
    root.active = true
    if (root.systemStatsService) root.systemStatsService.start()
    if (root.thermalService) root.thermalService.start()
    if (root.gpuModeService) root.gpuModeService.start()
    if (root.networkService) root.networkService.startStats()
  }

  function stop() {
    root.active = false
    if (root.systemStatsService) root.systemStatsService.stop()
    if (root.thermalService) root.thermalService.stop()
    if (root.gpuModeService) root.gpuModeService.stop()
    if (root.networkService) root.networkService.stopStats()
  }

  Timer {
    interval: 60000
    running: root.active
    repeat: true
    onTriggered: root.rebuild()
  }

  opacity: root.active ? 1 : 0
  visible: opacity > 0

  Behavior on opacity {
    NumberAnimation { duration: Theme.animDurationFast }
  }

  Component.onCompleted: root.rebuild()

  // --- three-column layout ---

  ColumnLayout {
    id: panelLayout
    anchors.fill: parent
    anchors.margins: root.panelPadding
    spacing: 0

    RowLayout {
      id: columnsRow
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      spacing: root._colGap

      // ---------- LEFT: calendar ----------
      ColumnLayout {
        Layout.preferredWidth: root._colW1
        Layout.alignment: Qt.AlignTop
        spacing: 10

        ColumnLayout {
          id: calCol
          Layout.preferredWidth: root._colBlock
          Layout.alignment: Qt.AlignHCenter
          spacing: 4

          Text {
            id: calendarClock
            text: Qt.formatDateTime(new Date(), "HH:mm")
            color: Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeValue
            font.bold: true
            Layout.alignment: Qt.AlignHCenter

            Timer {
              interval: 1000
              running: root.active
              repeat: true
              onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm")
            }
          }

          RowLayout {
            id: monthRow
            Layout.fillWidth: true
            spacing: 6

            Text {
              text: "\u25c0"
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeLabel
              Layout.alignment: Qt.AlignVCenter

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.prevMonth()
              }
            }

            Text {
              text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
              color: Theme.foreground
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeTitle
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              text: "\u25b6"
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeLabel
              Layout.alignment: Qt.AlignVCenter

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.nextMonth()
              }
            }
          }

          Grid {
            id: weekdayGrid
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            spacing: 2

            Repeater {
              model: ["S", "M", "T", "W", "T", "F", "S"]

              Text {
                width: 26
                height: 14
                text: modelData
                color: Theme.comment
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          Grid {
            id: dayGrid
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Math.ceil(gridModel.count / 7) * 28 - 2
            Layout.minimumHeight: Math.ceil(gridModel.count / 7) * 28 - 2
            height: Math.ceil(gridModel.count / 7) * 28 - 2
            columns: 7
            spacing: 2

            Repeater {
              model: gridModel

              Rectangle {
                required property string label
                required property bool isToday
                required property bool isPast
                width: 26
                height: 26
                radius: 13
                color: isToday ? Theme.accent : "transparent"

                Text {
                  anchors.centerIn: parent
                  text: parent.label
                  color: isToday ? Theme.background
                                 : (isPast ? Theme.comment : Theme.foreground)
                  font.family: Theme.fontFamily
                  font.pixelSize: isToday ? 12 : 11
                  font.bold: isToday
                }
              }
            }
          }
        }
      }

      // ---------- MIDDLE: sliders + tiles ----------
      ColumnLayout {
        Layout.preferredWidth: root._colW2
        Layout.alignment: Qt.AlignTop
        spacing: 8

        Text {
          text: "CONTROLS"
          color: Theme.comment
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeLabel
          font.bold: true
          font.letterSpacing: 1.6
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Item {
            width: 16
            height: 16
            Layout.alignment: Qt.AlignVCenter

            SpeakerIcon {
              anchors.fill: parent
              volume: audioService.volume
              muted: audioService.muted
              headphoneConnected: audioService.headphoneConnected
              micConnected: audioService.micConnected
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.userActivity()
                audioService.toggleMute()
              }
            }
          }

          SliderBar {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            minValue: 0
            maxValue: 1
            step: 0.05
            value: audioService.volume
            fillColor: audioService.muted ? Theme.red : Theme.accent
            onInteraction: root.userActivity()
            onChanged: v => {
              audioService.requestFastPoll()
              audioService.setVolume(v)
            }
          }

          Text {
            text: Math.round(audioService.volume * 100) + "%"
            color: audioService.muted ? Theme.red : Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeValue
            font.bold: true
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 36
            Layout.alignment: Qt.AlignVCenter
          }

          Item {
            id: deviceMenuAnchor
            width: 14
            height: 16
            Layout.alignment: Qt.AlignVCenter

            Text {
              anchors.centerIn: parent
              text: "\uF078"
              color: chevronMouse.containsMouse ? Theme.accent : Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: 11
            }

            MouseArea {
              id: chevronMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.userActivity()
                if (audioService)
                  audioService.refreshDevices()
                audioDeviceMenu.open()
              }
            }

            AudioDeviceMenu {
              id: audioDeviceMenu
              x: -(width - parent.width)
              y: parent.height + 6
              audioService: root.audioService
              onUserActivity: root.userActivity()
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 8

          Item {
            width: 16
            height: 16
            Layout.alignment: Qt.AlignVCenter

            SunIcon {
              anchors.fill: parent
              percent: brightnessService.displayPercent
            }
          }

          SliderBar {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            minValue: 1
            maxValue: 100
            step: 5
            value: brightnessService.displayPercent
            fillColor: brightnessService.displayPercent > 20 ? Theme.yellow : Theme.red
            onInteraction: root.userActivity()
            onChanged: v => {
              brightnessService.requestFastPoll()
              brightnessService.setPercent(v)
            }
          }

          Text {
            text: Math.round(brightnessService.displayPercent) + "%"
            color: Theme.yellow
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeValue
            font.bold: true
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 36
            Layout.alignment: Qt.AlignVCenter
          }
        }

        Text {
          text: "SYSTEM"
          color: Theme.comment
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeLabel
          font.bold: true
          font.letterSpacing: 1.6
          anchors.topMargin: 2
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 2
          columnSpacing: 8
          rowSpacing: 8

          StatTile {
            title: "CPU"
            valueColor: root.loadTempColor(root.cpuLoad, root.cpuTemp)
            valueText: root.loadTempText(root.cpuLoad, root.cpuTemp, "")
            sparkSamples: root.cpuSamples
            sparkColor: valueColor
            CpuIcon {}
          }

          StatTile {
            title: "GPU"
            valueColor: root.loadTempColor(root.gpuLoad, root.gpuTemp)
            valueText: root.loadTempText(root.gpuLoad, root.gpuTemp, "")
            sparkSamples: root.gpuSamples
            sparkColor: valueColor
            GpuIcon {}
          }

          StatTile {
            title: "RAM"
            valueColor: root.ringColor(root.ramPercent)
            valueText: (root.ramUsed / (1024*1024*1024)).toFixed(1) + " / " + (root.ramTotal / (1024*1024*1024)).toFixed(1) + " GB"
            sparkSamples: root.ramSamples
            sparkColor: valueColor
            RamIcon {}
          }

          StatTile {
            title: "FAN"
            valueText: root.fanText()
            valueColor: root.cpuFanSpeed <= 0 && root.gpuFanSpeed <= 0 ? Theme.comment : Theme.orange
            FanIcon {}
          }

          StatTile {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            title: "NET"
            valueText: root.netText()
            subText: root.networkSubText()
            subTextColor: root.networkService ? root.networkService.qualityColor : Theme.comment
            NetIcon {}
          }
        }
      }

      // ---------- RIGHT: battery / power / gpu / identity ----------
      ColumnLayout {
        id: rightCol
        Layout.preferredWidth: root._colW3
        Layout.alignment: Qt.AlignTop
        spacing: 8

        Rectangle {
          id: identityCard
          Layout.fillWidth: true
          radius: 8
          color: root.cardColor
          border.width: 1
          border.color: root.cardBorder
          implicitHeight: 54

          ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 8
            anchors.bottomMargin: 12
            spacing: 3

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              TuxIcon { Layout.alignment: Qt.AlignVCenter }

              Text {
                text: root.userName + "@" + root.hostName
                color: Theme.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
              }
            }

            Text {
              text: root.kernelVersion
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeValue
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          radius: 8
          color: root.cardColor
          border.width: 1
          border.color: root.cardBorder
          implicitHeight: 62

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 3

            RowLayout {
              Layout.fillWidth: true
              spacing: 6

              BatIcon { Layout.alignment: Qt.AlignVCenter }

              Text {
                text: root.batteryCharging ? "CHARGING" : root.batteryOnAc ? "AC POWER" : "BATTERY"
                color: Theme.comment
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                font.bold: true
                font.letterSpacing: 1.2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
              }
            }

            RowLayout {
              Layout.fillWidth: true

              Text {
                text: root.batteryCapacity + "%"
                color: root.batteryColor(root.batteryCapacity, root.batteryCharging)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeHero
                font.bold: true
              }

              Item { Layout.fillWidth: true }

              Text {
                text: root.batteryPower.toFixed(0) + " W"
                color: Theme.comment
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeLabel
                Layout.alignment: Qt.AlignVCenter
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 4
              radius: 2
              color: Theme.selection

              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.batteryCapacity / 100))
                height: parent.height
                radius: parent.radius
                color: root.batteryColor(root.batteryCapacity, root.batteryCharging)
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          radius: 8
          color: root.cardColor
          border.width: 1
          border.color: root.cardBorder
          implicitHeight: 44

          RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            PwrIcon { Layout.alignment: Qt.AlignVCenter }

            Text {
              text: "PROFILE"
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeLabel
              font.bold: true
              font.letterSpacing: 1.2
              Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Text {
              text: root.powerProfile.length > 0 ? root.powerProfile : "--"
              color: root.powerProfile === "Performance" ? Theme.green : root.powerProfile === "Quiet" ? Theme.cyan : Theme.foreground
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeValue
              font.bold: true
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          radius: 8
          color: root.cardColor
          border.width: 1
          border.color: root.cardBorder
          implicitHeight: 44

          RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            GpuIcon { Layout.alignment: Qt.AlignVCenter }

            Text {
              text: "GPU"
              color: Theme.comment
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeLabel
              font.bold: true
              font.letterSpacing: 1.2
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              text: {
                var t = root.gpuMode.length > 0 ? root.gpuMode : "--"
                if (root.gpuStatusShown())
                  t += " \u00b7 " + root.gpuPowerStatus
                return t
              }
              color: Theme.pink
              font.family: Theme.fontFamily
              font.pixelSize: Theme.fontSizeValue
              font.bold: true
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignRight
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          radius: 8
          color: root.cardColor
          border.width: 1
          border.color: root.cardBorder
          implicitHeight: weatherLabel.height + weatherValue.height + 32

          Text {
            id: weatherLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 15
            text: "WEATHER"
            color: Theme.comment
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeLabel
            font.bold: true
            font.letterSpacing: 1.2
          }

          Text {
            id: weatherValue
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: weatherLabel.bottom
            anchors.topMargin: 2
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: contentHeight
            text: {
              if (!root.weatherService) return "--"
              var c = root.weatherService.city
              if (c.length === 0) return "--"
              return c + " \u00b7 " + Math.round(root.weatherService.tempC) + "\u00b0C \u00b7 " + root.weatherStatus(root.weatherService.weatherCode)
            }
            color: Theme.cyan
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeValue
            font.bold: true
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
          }
        }
      }
    }
  }

  // --- Canvas Icons (Lucide-style) ---

  component CpuIcon: Text {
    width: Theme.iconSize; height: Theme.iconSize
    text: "󰻠"
    color: Theme.accent
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component GpuIcon: Text {
    width: Theme.iconSize; height: Theme.iconSize
    text: "󰘚"
    color: Theme.pink
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component RamIcon: Text {
    width: Theme.iconSize; height: Theme.iconSize
    text: "󰍛"
    color: Theme.cyan
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component FanIcon: Text {
    width: Theme.iconSize; height: Theme.iconSize
    text: "󰈐"
    color: Theme.orange
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component BatIcon: Text {
    width: Theme.iconSize; height: Theme.iconSize
    text: root.batteryCharging ? "󰂄" : "󰁹"
    color: root.batteryCharging ? Theme.green : (root.batteryCapacity > 20 ? Theme.foreground : Theme.red)
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component PwrIcon: Text {
    width: Theme.iconSize; height: Theme.iconSize
    text: "󰐥"
    color: Theme.green
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component NetIcon: Text {
    width: Theme.iconSize; height: Theme.iconSize
    text: "󰖩"
    color: Theme.green
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component TuxIcon: Text {
    width: Theme.iconSize; height: Theme.iconSize
    text: "\uF17C"
    color: Theme.comment
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component SpeakerIcon: Text {
    id: sicon
    property real volume: 0
    property bool muted: false
    property bool headphoneConnected: false
    property bool micConnected: false

    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: sicon.muted ? Theme.red : Theme.accent
    text: {
      if (sicon.headphoneConnected && sicon.micConnected) return "󰋎"
      if (sicon.headphoneConnected) return "󰋋"
      if (sicon.micConnected) return "󰍬"
      if (sicon.muted) return "\uF026"
      var v = sicon.volume
      if (v >= 0.67) return "\uF028"
      if (v >= 0.34) return "\uF027"
      if (v > 0) return "\uF026"
      return "\uF026"
    }
  }

  component SunIcon: Text {
    id: sun
    width: Theme.iconSize; height: Theme.iconSize
    property real percent: 100
    text: "󰖙"
    color: Theme.yellow
    font.family: Theme.fontFamily
    font.pixelSize: Theme.iconFontSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  component Sparkline: Canvas {
    id: spark
    property var samples: []
    property color lineColor: Theme.cyan
    renderTarget: Canvas.Image
    antialiasing: true

    onSamplesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      if (!spark.samples || spark.samples.length < 2 || width <= 1 || height <= 1)
        return
      var count = spark.samples.length
      var dx = width / Math.max(1, count - 1)
      ctx.strokeStyle = spark.lineColor
      ctx.lineWidth = 1.25
      ctx.lineJoin = "round"
      ctx.beginPath()
      for (var i = 0; i < count; i++) {
        var x = i * dx
        var y = height - 1 - Math.max(0, Math.min(100, spark.samples[i])) / 100 * (height - 2)
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }
      ctx.stroke()
    }
  }

  // --- draggable slider bar ---

  component SliderBar: Rectangle {
    id: sbar
    property real minValue: 0
    property real maxValue: 1
    property real value: 0
    property real step: 0
    property color fillColor: Theme.accent
    signal changed(real v)
    signal interaction()

    implicitHeight: 5
    radius: 2.5
    color: Theme.selection

    Rectangle {
      id: sbarFill
      height: parent.height
      radius: parent.radius
      color: sbar.fillColor
      width: sbar.maxValue > sbar.minValue
        ? Math.max(0, Math.min(parent.width, parent.width * (sbar.value - sbar.minValue) / (sbar.maxValue - sbar.minValue)))
        : 0

      Behavior on width {
        NumberAnimation { duration: Theme.animDurationFast; easing: Easing.OutQuad }
      }
    }

    MouseArea {
      anchors.fill: parent
      onPressed: mouse => {
        sbar.interaction()
        sbar._set(mouse.x)
      }
      onPositionChanged: mouse => {
        if (pressed) {
          sbar.interaction()
          sbar._set(mouse.x)
        }
      }
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
      if (Math.abs(clamped - sbar.value) > 0.001)
        sbar.changed(clamped)
    }
  }

  // --- stat tile (icon + bold title + mono subtext) ---

  component StatTile: Rectangle {
    id: tile
    default property alias tileContent: iconSlot.data
    property string title: ""
    property color valueColor: Theme.foreground
    property string valueText: ""
    property string subText: ""
    property color subTextColor: Theme.comment
    property int valueSize: Theme.fontSizeValue
    property var sparkSamples: []
    property color sparkColor: Theme.cyan

    radius: 8
    color: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.3)
    border.width: 1
    border.color: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.55)
    implicitHeight: tile.subText.length > 0 || tile.sparkSamples.length > 1 ? 74 : 56
    Layout.preferredWidth: 140
    Layout.fillWidth: true

    RowLayout {
      id: contentArea
      anchors.fill: parent
      anchors.leftMargin: 9
      anchors.rightMargin: 9
      anchors.topMargin: 10
      anchors.bottomMargin: 10
      spacing: 9

      Item {
        id: iconSlot
        width: 16
        height: 16
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        Text {
          text: tile.title
          color: Theme.foreground
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeTitle
          font.bold: true
          font.letterSpacing: 0.6
        }

        Text {
          text: tile.valueText
          color: tile.valueColor
          font.family: Theme.fontFamily
          font.pixelSize: tile.valueSize
          elide: Text.ElideRight
          Layout.fillWidth: true
        }

        Sparkline {
          visible: tile.sparkSamples.length > 1
          samples: tile.sparkSamples
          lineColor: tile.sparkColor
          Layout.fillWidth: true
          Layout.preferredHeight: 16
        }

        Text {
          visible: tile.subText.length > 0
          text: tile.subText
          color: tile.subTextColor
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeLabel
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }
  }
}
