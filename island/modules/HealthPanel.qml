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
  property real gpuFan: 0
  property real cpuFanSpeed: 0
  property real gpuFanSpeed: 0
  property real netRxRate: 0
  property real netTxRate: 0
  property real batteryPower: 0
  property bool batteryCharging: false
  property int batteryCapacity: 0
  property string gpuMode: ""
  property string gpuPowerStatus: ""
  property string powerProfile: ""
  property string kernelVersion: ""
  property string userName: ""
  property string hostName: ""

  property int _lastRx: 0
  property int _lastTx: 0
  property string _iface: ""

  width: 340
  height: 195

  function formatBytes(b) {
    if (b < 1024) return b.toFixed(0) + " B/s"
    if (b < 1048576) return (b / 1024).toFixed(1) + " KB/s"
    return (b / 1048576).toFixed(1) + " MB/s"
  }

  function formatRam(v) {
    if (v < 1073741824) return (v / 1048576).toFixed(0) + " MB"
    return (v / 1073741824).toFixed(1) + " GB"
  }

  function levelColor(val, warn, crit) {
    if (val >= crit) return Theme.red
    if (val >= warn) return Theme.yellow
    return Theme.foreground
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

  function start() {
    root.active = true
    detectIface()
    cpuCountProc.running = true
    gfxModeProc.running = true
    pwrProfileProc.running = true
    sysInfoProc.running = true
    collectData.running = true
    collectData.triggered()
  }

  function stop() {
    root.active = false
    collectData.running = false
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
      gpuDataProc.running = true
      netDataProc.running = true
    }
  }

  Process {
    id: ifProc
    command: ["sh", "-c", "ip -4 route show default | awk '{print $5}' | head -1"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = data.trim()
        if (v.length > 0) root._iface = v
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
          var fan = parseFloat(parts[2])
          root.gpuFan = isNaN(fan) ? 0 : fan
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

  opacity: root.active ? 1 : 0
  visible: opacity > 0

  Behavior on opacity {
    NumberAnimation { duration: 100 }
  }

  GridLayout {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: separatorLine.top
    anchors.topMargin: 10
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    anchors.bottomMargin: 8
    columns: 2
    columnSpacing: 16
    rowSpacing: 6

    // --- CPU row ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      CpuIcon { Layout.alignment: Qt.AlignVCenter }

      ColumnLayout {
        spacing: 1
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: "CPU"
          color: Theme.comment
          font.pixelSize: 9
          font.letterSpacing: 0.5
        }
        Text {
          text: (isNaN(root.cpuLoad) ? 0 : Math.round(root.cpuLoad)) + "%  " + (isNaN(root.cpuTemp) ? 0 : root.cpuTemp.toFixed(0)) + "°"
          color: root.loadTempColor(root.cpuLoad, root.cpuTemp)
          font.pixelSize: 12
          font.letterSpacing: 0.3
        }
      }
    }

    // --- GPU row ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      GpuIcon { Layout.alignment: Qt.AlignVCenter }

      ColumnLayout {
        spacing: 1
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: "GPU"
          color: Theme.comment
          font.pixelSize: 9
          font.letterSpacing: 0.5
        }
        Text {
          text: {
            var extra = ""
            if (root.gpuMode.length > 0) extra += "  " + root.gpuMode
            if (root.gpuPowerStatus.length > 0 && root.gpuPowerStatus !== "active") extra += " " + root.gpuPowerStatus
            return (isNaN(root.gpuLoad) ? 0 : Math.round(root.gpuLoad)) + "%  " + (isNaN(root.gpuTemp) ? 0 : root.gpuTemp.toFixed(0)) + "°" + extra
          }
          color: root.loadTempColor(root.gpuLoad, root.gpuTemp)
          font.pixelSize: 12
          font.letterSpacing: 0.3
        }
      }
    }

    // --- RAM row ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      RamIcon { Layout.alignment: Qt.AlignVCenter }

      ColumnLayout {
        spacing: 1
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: "RAM"
          color: Theme.comment
          font.pixelSize: 9
          font.letterSpacing: 0.5
        }
        Text {
          text: formatRam(root.ramUsed) + " / " + formatRam(root.ramTotal) + "  [" + (isNaN(root.ramPercent) ? 0 : Math.round(root.ramPercent)) + "%]"
          color: root.levelColor(root.ramPercent, 70, 85)
          font.pixelSize: 12
          font.letterSpacing: 0.3
        }
      }
    }

    // --- FAN row ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      FanIcon { Layout.alignment: Qt.AlignVCenter }

      ColumnLayout {
        spacing: 1
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: "FAN"
          color: Theme.comment
          font.pixelSize: 9
          font.letterSpacing: 0.5
        }
        Text {
          text: "C:" + (isNaN(root.cpuFanSpeed) ? 0 : root.cpuFanSpeed.toFixed(0)) + "  G:" + (isNaN(root.gpuFanSpeed) ? 0 : root.gpuFanSpeed.toFixed(0))
          color: Theme.foreground
          font.pixelSize: 12
          font.letterSpacing: 0.3
        }
      }
    }

    // --- BAT row ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      BatIcon { Layout.alignment: Qt.AlignVCenter }

      ColumnLayout {
        spacing: 1
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: root.batteryCharging ? "CHR" : "BAT"
          color: Theme.comment
          font.pixelSize: 9
          font.letterSpacing: 0.5
        }
        Text {
          text: root.batteryCharging ? root.batteryPower.toFixed(0) + "W" : root.batteryCapacity + "%"
          color: root.batteryColor(root.batteryCapacity, root.batteryCharging)
          font.pixelSize: 12
          font.letterSpacing: 0.3
        }
      }
    }

    // --- PWR row ---
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      PwrIcon { Layout.alignment: Qt.AlignVCenter }

      ColumnLayout {
        spacing: 1
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: "PWR"
          color: Theme.comment
          font.pixelSize: 9
          font.letterSpacing: 0.5
        }
        Text {
          text: root.powerProfile
          color: root.powerProfile === "Performance" ? Theme.green : root.powerProfile === "Quiet" ? Theme.blue : Theme.foreground
          font.pixelSize: 12
          font.letterSpacing: 0.3
        }
      }
    }

    // --- NET row (spans 2 columns) ---
    RowLayout {
      Layout.columnSpan: 2
      Layout.fillWidth: true
      spacing: 6

      NetIcon { Layout.alignment: Qt.AlignVCenter }

      ColumnLayout {
        spacing: 1
        Layout.alignment: Qt.AlignVCenter

        Text {
          text: "NET"
          color: Theme.comment
          font.pixelSize: 9
          font.letterSpacing: 0.5
        }
        Text {
          text: "\u2193 " + formatBytes(root.netRxRate) + "  \u2191 " + formatBytes(root.netTxRate)
          color: Theme.foreground
          font.pixelSize: 12
          font.letterSpacing: 0.3
        }
      }
    }
  }

  Rectangle {
    id: separatorLine
    width: parent.width - 20
    height: 1
    color: Theme.selection
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: footerRow.top
    anchors.bottomMargin: 5
  }

  RowLayout {
    id: footerRow
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    spacing: 6

    TuxIcon { Layout.alignment: Qt.AlignVCenter }

    Text {
      text: root.kernelVersion
      color: Theme.comment
      font.pixelSize: 9
      font.family: "monospace"
      Layout.alignment: Qt.AlignVCenter
    }

    Item { Layout.fillWidth: true }

    Text {
      text: root.userName + "@" + root.hostName
      color: Theme.comment
      font.pixelSize: 9
      font.family: "monospace"
      Layout.alignment: Qt.AlignVCenter
    }
  }

  // --- Canvas Icons (Lucide-style) ---

  component CpuIcon: Canvas {
    width: 16; height: 16
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.accent; ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.rect(3, 3, 10, 10); ctx.stroke()
      ctx.beginPath(); ctx.rect(5.5, 5.5, 5, 5); ctx.stroke()
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.rect(5 + i * 3, 0, 2, 3); ctx.fill() }
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.rect(5 + i * 3, 13, 2, 3); ctx.fill() }
    }
    Component.onCompleted: requestPaint()
  }

  component GpuIcon: Canvas {
    width: 16; height: 16
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.pink; ctx.fillStyle = Theme.pink; ctx.lineWidth = 1.5; ctx.lineCap = "round"
      ctx.beginPath(); ctx.rect(3, 3, 10, 10); ctx.stroke()
      ctx.beginPath(); ctx.rect(5.5, 5.5, 5, 5); ctx.stroke()
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.rect(0, 5 + i * 3, 2, 2); ctx.fill() }
      for (var i = 0; i < 3; i++) { ctx.beginPath(); ctx.rect(14, 5 + i * 3, 2, 2); ctx.fill() }
    }
    Component.onCompleted: requestPaint()
  }

  component RamIcon: Canvas {
    width: 16; height: 16; antialiasing: true
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.cyan; ctx.fillStyle = Theme.cyan; ctx.lineWidth = 1.5; ctx.lineCap = "round"
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
    width: 16; height: 16
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.orange; ctx.fillStyle = Theme.orange; ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round"
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
    width: 16; height: 16
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = root.batteryCharging ? Theme.green : Theme.foreground
      ctx.fillStyle = root.batteryCharging ? Theme.green : Theme.foreground
      ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.rect(1, 3, 10, 10); ctx.stroke()
      ctx.beginPath(); ctx.rect(11, 5.5, 3, 5); ctx.fill()
      var fillW = Math.max(0, Math.min(8, 8 * root.batteryCapacity / 100))
      if (fillW > 0) { ctx.beginPath(); ctx.rect(3, 5, fillW, 6); ctx.fill() }
      if (root.batteryCharging) {
        ctx.strokeStyle = Theme.background; ctx.lineWidth = 1.5; ctx.lineCap = "round"
        ctx.beginPath(); ctx.moveTo(7, 4); ctx.lineTo(5, 8); ctx.lineTo(7, 8); ctx.lineTo(5, 12)
        ctx.stroke()
      }
    }
    Component.onCompleted: requestPaint()
  }

  component PwrIcon: Canvas {
    width: 16; height: 16
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.green; ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.moveTo(10, 1); ctx.lineTo(5, 8); ctx.lineTo(8, 8); ctx.lineTo(6, 15)
      ctx.stroke()
    }
    Component.onCompleted: requestPaint()
  }

  component NetIcon: Canvas {
    width: 16; height: 16
    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.strokeStyle = Theme.green; ctx.fillStyle = Theme.green; ctx.lineWidth = 1.5; ctx.lineCap = "round"; ctx.lineJoin = "round"
      ctx.beginPath(); ctx.moveTo(8, 2); ctx.lineTo(4, 7); ctx.lineTo(8, 12); ctx.stroke()
      ctx.moveTo(8, 2); ctx.lineTo(12, 7); ctx.lineTo(8, 12); ctx.stroke()
    }
    Component.onCompleted: requestPaint()
  }

  component TuxIcon: Canvas {
    width: 16; height: 16; antialiasing: true
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
}
