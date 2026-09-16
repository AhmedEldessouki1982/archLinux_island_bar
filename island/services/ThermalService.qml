import Quickshell
import Quickshell.Io
import QtQuick
import "../config"

Item {
  id: root
  visible: false

  property real cpuTemp: 0
  property real cpuFanSpeed: 0
  property real gpuFanSpeed: 0
  property real gpuTemp: 0
  property real gpuLoad: 0

  property string _hwmonTempPath: ""
  property string _hwmonFanPath: ""
  property bool _active: false

  function start() {
    root._active = true
    hwmonResolveProc.running = true
    gpuDataProc.running = true
  }

  function stop() {
    root._active = false
    collectGpu.running = false
  }

  // --- one-shot: resolve hwmon paths (no sysfs glob equivalent) ---
  Process {
    id: hwmonResolveProc
    command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do echo \"$(basename $d) $(cat $d/name 2>/dev/null)\"; done"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var lines = data.trim().split("
")
        for (var i = 0; i < lines.length; i++) {
          var parts = lines[i].split(" ")
          if (parts.length >= 2) {
            var hwmon = parts[0]
            var name = parts.slice(1).join(" ")
            if (name === "k10temp" && root._hwmonTempPath.length === 0)
              root._hwmonTempPath = "/sys/class/hwmon/" + hwmon + "/temp1_input"
            if (name === "asus" && root._hwmonFanPath.length === 0)
              root._hwmonFanPath = "/sys/class/hwmon/" + hwmon
          }
        }
        // start reading once paths resolved
        if (root._hwmonTempPath.length > 0) cpuTempView.reload()
        if (root._hwmonFanPath.length > 0) {
          fan1View.reload()
          fan2View.reload()
        }
      }
    }
  }

  // --- FileView: zero-fork cpu temp ---
  FileView {
    id: cpuTempView
    path: root._hwmonTempPath
    watchChanges: false
    onLoaded: {
      var temp = parseInt(text().trim())
      if (!isNaN(temp) && temp > 0)
        root.cpuTemp = temp / 1000
    }
  }

  // --- FileView: zero-fork fan1 ---
  FileView {
    id: fan1View
    path: root._hwmonFanPath.length > 0 ? root._hwmonFanPath + "/fan1_input" : ""
    watchChanges: false
    onLoaded: {
      var fan1 = parseInt(text().trim())
      if (!isNaN(fan1) && fan1 >= 0) root.cpuFanSpeed = fan1
    }
  }

  // --- FileView: zero-fork fan2 ---
  FileView {
    id: fan2View
    path: root._hwmonFanPath.length > 0 ? root._hwmonFanPath + "/fan2_input" : ""
    watchChanges: false
    onLoaded: {
      var fan2 = parseInt(text().trim())
      if (!isNaN(fan2) && fan2 >= 0) root.gpuFanSpeed = fan2
    }
  }

  // --- poll timer: reloads FileViews instead of forking shells ---
  Timer {
    id: collectData
    interval: 2000
    running: root._active
    repeat: true
    onTriggered: {
      if (root._hwmonTempPath.length > 0) cpuTempView.reload()
      if (root._hwmonFanPath.length > 0) {
        fan1View.reload()
        fan2View.reload()
      }
    }
  }

  // --- nvidia-smi: no sysfs equivalent, keep as shell (5s interval) ---
  Timer {
    id: collectGpu
    interval: 5000
    running: false
    repeat: true
    onTriggered: gpuDataProc.running = true
  }

  Process {
    id: gpuDataProc
    command: ["sh", "-c", "nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,fan.speed --format=csv,noheader,nounits 2>/dev/null || echo '--,--,--'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var parts = data.trim().split(/,s*/)
        if (parts.length >= 2) {
          root.gpuTemp = parseFloat(parts[0]) || 0
          root.gpuLoad = parseFloat(parts[1]) || 0
        }
      }
    }
  }
}
