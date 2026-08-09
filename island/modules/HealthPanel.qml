import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../config"

Item {
  id: root

  property bool active: false

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
  property int batteryCapacity: 0
  property string gpuMode: ""
  property string gpuPowerStatus: ""
  property string powerProfile: ""
  property string kernelVersion: ""
  property string userName: ""
  property string hostName: ""

  property int panelPadding: 14

  property int _lastRx: 0
  property int _lastTx: 0
  property string _iface: ""

  // --- forwarded services (instantiated in FloatingHealth) ---
  property var audioService: null
  property var brightnessService: null
  property var batteryService: null

  onBatteryServiceChanged: {
    if (root.batteryService) {
      root.batteryCapacity = Qt.binding(() => root.batteryService.capacity)
      root.batteryCharging = Qt.binding(() => root.batteryService.charging)
      root.batteryPower = Qt.binding(() => root.batteryService.power)
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
  readonly property real contentHeight: Math.max(300, root.panelPadding * 2 + ringRow.height + 10 + calCol.height)

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
    return "C:" + pad(isNaN(root.cpuFanSpeed) ? 0 : Math.round(root.cpuFanSpeed), 4) + "  G:" + pad(isNaN(root.gpuFanSpeed) ? 0 : Math.round(root.gpuFanSpeed), 4)
  }

  function netText() {
    return "\u2193 " + padRight(root.formatBytes(root.netRxRate), 9) + "   \u2191 " + padRight(root.formatBytes(root.netTxRate), 9)
  }

  function networkSubText() {
    if (root._iface.length === 0) return "OFFLINE"
    if (root.wifiSsid.length > 0) return root.wifiSsid
    if (root._iface.indexOf("wl") === 0) return "WIFI"
    return "ETHERNET"
  }

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
    root.month -= 1
    if (root.month < 0) {
      root.month = 11
      root.year -= 1
    }
    root.rebuild()
  }

  function nextMonth() {
    root.month += 1
    if (root.month > 11) {
      root.month = 0
      root.year += 1
    }
    root.rebuild()
  }

  function start() {
    root.active = true
    detectIface()
    cpuCountProc.running = true
    gfxModeProc.running = true
    pwrProfileProc.running = true
    sysInfoProc.running = true
    ssidProc.running = true
    collectData.running = true
    collectGpu.running = true
    if (collectGpu) collectGpu.triggered()
  }

  function stop() {
    root.active = false
    collectData.running = false
    collectGpu.running = false
  }

  function detectIface() {
    ifProc.running = true
  }

  Timer {
    id: collectData
    interval: 2000
    running: false
    repeat: true
    onTriggered: {
      loadProc.running = true
      memProc.running = true
      cpuTempProc.running = true
      fanProc.running = true
      netDataProc.running = true
      ssidProc.running = true
    }
  }

  Timer {
    id: collectGpu
    interval: 5000
    running: false
    repeat: true
    onTriggered: {
      gpuDataProc.running = true
    }
  }

  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.rebuild()
  }

  Process {
    id: ifProc
    command: ["sh", "-c", "ip -4 route show default | awk '{print $5}' | head -1"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = data.trim()
        if (v.length > 0) {
          root._iface = v
          if (root.active && root.collectData) root.collectData.triggered()
        }
      }
    }
  }

  Process {
    id: cpuCountProc
    command: ["nproc"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var n = parseInt(data.trim())
        if (!isNaN(n) && n > 0) root.cpuCount = n
      }
    }
  }

  Process {
    id: gfxModeProc
    command: ["sh", "-c", "echo M:$(supergfxctl -g) && echo S:$(supergfxctl -S)"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim()
        if (line.indexOf("M:") === 0) root.gpuMode = line.substring(2)
        else if (line.indexOf("S:") === 0) root.gpuPowerStatus = line.substring(2)
      }
    }
  }

  Process {
    id: pwrProfileProc
    command: ["sh", "-c", "asusctl profile get 2>/dev/null | head -1 | cut -d: -f2 | xargs"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = data.trim()
        if (v.length > 0) root.powerProfile = v
      }
    }
  }

  Process {
    id: sysInfoProc
    command: ["sh", "-c", "echo K:$(uname -r) && echo U:$(whoami) && echo H:$(uname -n)"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim()
        if (line.indexOf("K:") === 0) root.kernelVersion = line.substring(2)
        else if (line.indexOf("U:") === 0) root.userName = line.substring(2)
        else if (line.indexOf("H:") === 0) root.hostName = line.substring(2)
      }
    }
  }

  Process {
    id: loadProc
    command: ["sh", "-c", "cat /proc/loadavg"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var parts = data.trim().split(/\s+/)
        if (parts.length >= 3) {
          var raw = parseFloat(parts[0])
          if (!isNaN(raw) && root.cpuCount > 0)
            root.cpuLoad = Math.min(100, raw * 100 / root.cpuCount)
        }
      }
    }
  }

  Process {
    id: memProc
    command: ["sh", "-c", "awk '/MemTotal/ {mt=$2} /MemAvailable/ {ma=$2} END {print mt, ma}' /proc/meminfo"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var vals = data.trim().split(/\s+/)
        if (vals.length >= 2) {
          var memTotalKb = parseInt(vals[0])
          var memAvailKb = parseInt(vals[1])
          if (memTotalKb > 0) {
            root.ramTotal = memTotalKb * 1024
            root.ramUsed = (memTotalKb - memAvailKb) * 1024
            root.ramPercent = root.ramUsed / root.ramTotal * 100
          }
        }
      }
    }
  }

  Process {
    id: cpuTempProc
    command: ["sh", "-c", "cat /sys/class/hwmon/hwmon6/temp1_input"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var temp = parseInt(data.trim())
        if (!isNaN(temp) && temp > 0)
          root.cpuTemp = temp / 1000
      }
    }
  }

  Process {
    id: fanProc
    command: ["sh", "-c", "paste -d ' ' /sys/class/hwmon/hwmon10/fan1_input /sys/class/hwmon/hwmon10/fan2_input"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var vals = data.trim().split(/\s+/)
        if (vals.length >= 2) {
          var fan1 = parseInt(vals[0])
          var fan2 = parseInt(vals[1])
          if (!isNaN(fan1) && fan1 >= 0) root.cpuFanSpeed = fan1
          if (!isNaN(fan2) && fan2 >= 0) root.gpuFanSpeed = fan2
        }
      }
    }
  }

  Process {
    id: gpuDataProc
    command: ["sh", "-c", "nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,fan.speed --format=csv,noheader,nounits 2>/dev/null || echo '--,--,--'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var parts = data.trim().split(/,\s*/)
        if (parts.length >= 2) {
          root.gpuTemp = parseFloat(parts[0]) || 0
          root.gpuLoad = parseFloat(parts[1]) || 0
        }
      }
    }
  }

  Process {
    id: netDataProc
    command: ["sh", "-c", "paste -d ' ' /sys/class/net/" + root._iface + "/statistics/rx_bytes /sys/class/net/" + root._iface + "/statistics/tx_bytes 2>/dev/null || echo '0 0'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        if (root._iface.length === 0) return
        var vals = data.trim().split(/\s+/)
        if (vals.length >= 2) {
          var rx = parseInt(vals[0]) || 0
          var tx = parseInt(vals[1]) || 0
          if (root._lastRx > 0) {
            root.netRxRate = Math.max(0, (rx - root._lastRx) / 2)
            root.netTxRate = Math.max(0, (tx - root._lastTx) / 2)
          }
          root._lastRx = rx
          root._lastTx = tx
        }
      }
    }
  }

  Process {
    id: ssidProc
    command: ["sh", "-c", "nmcli -t -f ACTIVE,SSID device wifi 2>/dev/null | grep '^yes:' | cut -d: -f2- | head -1"]
    running: false
    stdout: SplitParser {
      onRead: data => root.wifiSsid = data.trim()
    }
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

      // ---------- LEFT: rings + calendar ----------
      ColumnLayout {
        Layout.preferredWidth: root._colW1
        Layout.alignment: Qt.AlignTop
        spacing: 10

        RowLayout {
          id: ringRow
          Layout.preferredWidth: root._colBlock
          Layout.alignment: Qt.AlignHCenter
          spacing: 10

          MeterRing {
            value: root.cpuLoad / 100
            ringColor: root.ringColor(root.cpuLoad)
            label: "CPU"
            CpuIcon {}
          }

          MeterRing {
            value: root.ramPercent / 100
            ringColor: root.ringColor(root.ramPercent)
            label: "RAM"
            RamIcon {}
          }

          MeterRing {
            value: root.gpuLoad / 100
            ringColor: root.ringColor(root.gpuLoad)
            label: "GPU"
            GpuIcon {}
          }
        }

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
              running: true
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
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: audioService.toggleMute()
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
            minValue: 0
            maxValue: 100
            step: 5
            value: brightnessService.displayPercent
            fillColor: brightnessService.displayPercent > 20 ? Theme.yellow : Theme.red
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
            CpuIcon {}
          }

          StatTile {
            title: "GPU"
            valueColor: root.loadTempColor(root.gpuLoad, root.gpuTemp)
            valueText: root.loadTempText(root.gpuLoad, root.gpuTemp, "")
            GpuIcon {}
          }

          StatTile {
            title: "RAM"
            valueColor: root.ringColor(root.ramPercent)
            valueText: (root.ramUsed / (1024*1024*1024)).toFixed(1) + " / " + (root.ramTotal / (1024*1024*1024)).toFixed(1) + " GB"
            RamIcon {}
          }

          StatTile {
            title: "FAN"
            valueText: root.fanText()
            FanIcon {}
          }

          StatTile {
            Layout.columnSpan: 2
            Layout.fillWidth: true
            title: "NET"
            valueText: root.netText()
            subText: root.networkSubText()
            NetIcon {}
          }
        }
      }

      // ---------- RIGHT: battery / power / gpu / identity ----------
      ColumnLayout {
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
                text: root.batteryCharging ? "CHARGING" : "BATTERY"
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
      }
    }
  }

  // --- Canvas Icons (Lucide-style) ---

  component CpuIcon: Canvas {
    antialiasing: true
    width: Theme.iconSize; height: Theme.iconSize
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.accent; ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.rect(3, 3, 10, 10); ctx.stroke()
      ctx.beginPath(); ctx.rect(5.5, 5.5, 5, 5); ctx.stroke()
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.rect(5 + i * 3, 0, 2, 3); ctx.fill() }
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.rect(5 + i * 3, 13, 2, 3); ctx.fill() }
    }
    Component.onCompleted: requestPaint()
  }

  component GpuIcon: Canvas {
    antialiasing: true
    width: Theme.iconSize; height: Theme.iconSize
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.pink; ctx.fillStyle = Theme.pink; ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"
      ctx.beginPath(); ctx.rect(3, 3, 10, 10); ctx.stroke()
      ctx.beginPath(); ctx.rect(5.5, 5.5, 5, 5); ctx.stroke()
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.rect(0, 5 + i * 3, 2, 2); ctx.fill() }
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.rect(14, 5 + i * 3, 2, 2); ctx.fill() }
    }
    Component.onCompleted: requestPaint()
  }

  component RamIcon: Canvas {
    width: Theme.iconSize; height: Theme.iconSize; antialiasing: true
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.cyan; ctx.fillStyle = Theme.cyan; ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"
      // DIMM body
      ctx.beginPath(); ctx.rect(3, 2, 10, 12); ctx.stroke()
      // gold pins at bottom
      for (var i = 0; i < 6; i++) {
        ctx.beginPath(); ctx.rect(4 + i * 1.5, 12, 1.2, 3); ctx.fill()
      }
      // alignment notch
      ctx.fillStyle = Theme.background
      ctx.beginPath(); ctx.rect(7, 5, 2, 2); ctx.fill()
      // top chip markers
      ctx.fillStyle = Theme.cyan
      ctx.beginPath(); ctx.rect(4.5, 4, 3, 3.5); ctx.fill()
    }
    Component.onCompleted: requestPaint()
  }

  component FanIcon: Canvas {
    antialiasing: true
    width: Theme.iconSize; height: Theme.iconSize
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.orange; ctx.fillStyle = Theme.orange; ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"; ctx.lineJoin = "round"
      // outer ring
      ctx.beginPath(); ctx.arc(8, 8, 5.5, 0, Math.PI * 2); ctx.stroke()
      // three smooth blades using bezier curves
      for (var i = 0; i < 3; i++) {
        var a = i * Math.PI * 2 / 3 - Math.PI / 2
        var ax = Math.cos(a), ay = Math.sin(a)
        var bx = Math.cos(a + 0.5), by = Math.sin(a + 0.5)
        var cx = Math.cos(a - 0.5), cy = Math.sin(a - 0.5)
        ctx.beginPath(); ctx.moveTo(8, 8)
        ctx.bezierCurveTo(8 + ax * 2, 8 + ay * 2, 8 + bx * 5, 8 + by * 5, 8 + ax * 5.5, 8 + ay * 5.5)
        ctx.bezierCurveTo(8 + cx * 5, 8 + cy * 5, 8 + ax * 2, 8 + ay * 2, 8, 8)
        ctx.fill()
      }
      // center hub
      ctx.fillStyle = Theme.background
      ctx.beginPath(); ctx.arc(8, 8, 1.8, 0, Math.PI * 2); ctx.fill()
      ctx.strokeStyle = Theme.orange; ctx.beginPath(); ctx.arc(8, 8, 1.8, 0, Math.PI * 2); ctx.stroke()
    }
    Component.onCompleted: requestPaint()
  }

  component BatIcon: Canvas {
    antialiasing: true
    width: Theme.iconSize; height: Theme.iconSize
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = root.batteryCharging ? Theme.green : Theme.foreground
      ctx.fillStyle = root.batteryCharging ? Theme.green : Theme.foreground
      ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.rect(1, 3, 10, 10); ctx.stroke()
      ctx.beginPath(); ctx.rect(11, 5.5, 3, 5); ctx.fill()
      var fillW = Math.max(0, Math.min(8, 8 * root.batteryCapacity / 100))
      if (fillW > 0) { ctx.beginPath(); ctx.rect(3, 5, fillW, 6); ctx.fill() }
      if (root.batteryCharging) {
        ctx.strokeStyle = Theme.background; ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"
        ctx.beginPath(); ctx.moveTo(7, 4); ctx.lineTo(5, 8); ctx.lineTo(7, 8); ctx.lineTo(5, 12)
        ctx.stroke()
      }
    }
    Component.onCompleted: requestPaint()
  }

  component PwrIcon: Canvas {
    antialiasing: true
    width: Theme.iconSize; height: Theme.iconSize
    onPaint: {
      var ctx = getContext("2d")
      ctx.strokeStyle = Theme.green; ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.moveTo(10, 1); ctx.lineTo(5, 8); ctx.lineTo(8, 8); ctx.lineTo(6, 15)
      ctx.stroke()
    }
    Component.onCompleted: requestPaint()
  }

  component NetIcon: Canvas {
    antialiasing: true
    width: Theme.iconSize; height: Theme.iconSize
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.green; ctx.fillStyle = Theme.green; ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.moveTo(8, 2); ctx.lineTo(4, 7); ctx.lineTo(8, 12); ctx.stroke()
      ctx.moveTo(8, 2); ctx.lineTo(12, 7); ctx.lineTo(8, 12); ctx.stroke()
    }
    Component.onCompleted: requestPaint()
  }

  component TuxIcon: Canvas {
    width: Theme.iconSize; height: Theme.iconSize; antialiasing: true
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = Theme.comment
      // body
      ctx.beginPath(); ctx.arc(8, 11, 5, 0, Math.PI * 2); ctx.fill()
      // head
      ctx.beginPath(); ctx.arc(8, 5, 3.5, 0, Math.PI * 2); ctx.fill()
      // eyes (white)
      ctx.fillStyle = Theme.background
      ctx.beginPath(); ctx.arc(6, 4.5, 1.2, 0, Math.PI * 2); ctx.fill()
      ctx.beginPath(); ctx.arc(10, 4.5, 1.2, 0, Math.PI * 2); ctx.fill()
      // pupils
      ctx.fillStyle = Theme.comment
      ctx.beginPath(); ctx.arc(6.5, 4.5, 0.5, 0, Math.PI * 2); ctx.fill()
      ctx.beginPath(); ctx.arc(10.5, 4.5, 0.5, 0, Math.PI * 2); ctx.fill()
      // beak
      ctx.fillStyle = Theme.orange
      ctx.beginPath(); ctx.moveTo(7, 6.5); ctx.lineTo(9, 6.5); ctx.lineTo(8, 8); ctx.closePath(); ctx.fill()
      // feet
      ctx.beginPath(); ctx.arc(5, 14.5, 1.8, 0, Math.PI * 2); ctx.fill()
      ctx.beginPath(); ctx.arc(11, 14.5, 1.8, 0, Math.PI * 2); ctx.fill()
    }
    Component.onCompleted: requestPaint()
  }

  component SpeakerIcon: Canvas {
    id: sicon
    antialiasing: true
    width: Theme.iconSize; height: Theme.iconSize
    property real volume: 0
    property bool muted: false
    onVolumeChanged: requestPaint()
    onMutedChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var c = 8
      ctx.fillStyle = sicon.muted ? Theme.red : Theme.accent
      ctx.strokeStyle = sicon.muted ? Theme.red : Theme.accent
      ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.rect(c - 5, c - 4, 4, 8); ctx.fill()
      ctx.beginPath(); ctx.moveTo(c - 1, c - 5); ctx.lineTo(c + 4, c - 9); ctx.lineTo(c + 4, c + 9); ctx.lineTo(c - 1, c + 5); ctx.closePath(); ctx.fill()
      if (!sicon.muted && sicon.volume > 0) {
        ctx.beginPath(); ctx.arc(c + 6, c, 3, 5.8, 6.6, false); ctx.stroke()
        if (sicon.volume > 0.33) { ctx.beginPath(); ctx.arc(c + 6, c, 5, 5.8, 6.6, false); ctx.stroke() }
        if (sicon.volume > 0.66) { ctx.beginPath(); ctx.arc(c + 6, c, 7, 5.8, 6.6, false); ctx.stroke() }
      }
    }
    Component.onCompleted: requestPaint()
  }

  component SunIcon: Canvas {
    id: sun
    antialiasing: true
    width: Theme.iconSize; height: Theme.iconSize
    property real percent: 100
    onPercentChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var c = 8
      ctx.strokeStyle = Theme.yellow
      ctx.lineWidth = Theme.iconLineWidth; ctx.lineCap = "round"
      ctx.beginPath(); ctx.arc(c, c, 3.5, 0, Math.PI * 2); ctx.stroke()
      ctx.lineWidth = Theme.iconLineWidth
      for (var i = 0; i < 4; i++) {
        var a = i * Math.PI / 2
        ctx.beginPath()
        ctx.moveTo(c + Math.cos(a) * 5.2, c + Math.sin(a) * 5.2)
        ctx.lineTo(c + Math.cos(a) * 7.5, c + Math.sin(a) * 7.5)
        ctx.stroke()
      }
    }
    Component.onCompleted: requestPaint()
  }

  // --- animated circular progress ring ---

  component MeterRing: Item {
    id: ring
    default property alias ringContent: iconSlot.data
    property real value: 0
    property color ringColor: Theme.green
    property string label: ""
    property real arc: 0

    implicitWidth: 58
    implicitHeight: 92

    Behavior on arc {
      NumberAnimation { duration: Theme.animDurationSlow; easing: Easing.OutCubic }
    }

    onValueChanged: ring.arc = Math.max(0, Math.min(1, ring.value))

    Canvas {
      id: ringCanvas
      antialiasing: true
      width: 52
      height: 52
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter

      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        var c = 26, r = 20, lw = 4.5
        ctx.lineCap = "round"
        ctx.lineWidth = lw
        ctx.strokeStyle = Qt.rgba(Theme.comment.r, Theme.comment.g, Theme.comment.b, 0.5)
        ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke()
        if (ring.arc > 0.005) {
          ctx.strokeStyle = ring.ringColor
          ctx.beginPath()
          ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + ring.arc * Math.PI * 2, false)
          ctx.stroke()
        }
      }

      Connections {
        target: ring
        function onArcChanged() { ringCanvas.requestPaint() }
      }
    }

    Item {
      id: iconSlot
      width: 16
      height: 16
      anchors.centerIn: ringCanvas
    }

    Text {
      id: pctText
      text: Math.round(ring.value * 100) + "%"
      color: ring.ringColor
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeValue
      font.bold: true
      anchors.top: ringCanvas.bottom
      anchors.topMargin: 6
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Text {
      text: ring.label
      color: Theme.comment
      font.family: Theme.fontFamily
      font.pixelSize: Theme.fontSizeLabel
      font.bold: true
      font.letterSpacing: 1.2
      anchors.top: pctText.bottom
      anchors.topMargin: 3
      anchors.horizontalCenter: parent.horizontalCenter
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
      onPressed: mouse => sbar._set(mouse.x)
      onPositionChanged: mouse => { if (pressed) sbar._set(mouse.x) }
      onWheel: event => {
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
    property int valueSize: Theme.fontSizeValue

    radius: 8
    color: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.3)
    border.width: 1
    border.color: Qt.rgba(Theme.selection.r, Theme.selection.g, Theme.selection.b, 0.55)
    implicitHeight: tile.subText.length > 0 ? 74 : 56
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

        Text {
          visible: tile.subText.length > 0
          text: tile.subText
          color: Theme.comment
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSizeLabel
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }
    }
  }
}
