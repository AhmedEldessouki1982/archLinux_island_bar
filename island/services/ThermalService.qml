import QtQuick
import Quickshell
import Quickshell.Io
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

  function start() {
    hwmonResolveProc.running = true
    collectData.running = true
    collectGpu.running = true
  }

  function stop() {
    collectData.running = false
    collectGpu.running = false
  }

  Timer {
    id: collectData
    interval: 2000
    running: false
    repeat: true
    onTriggered: {
      cpuTempProc.running = true
      fanProc.running = true
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

  Process {
    id: hwmonResolveProc
    command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do echo \"$(basename $d) $(cat $d/name 2>/dev/null)\"; done"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var lines = data.trim().split("\n")
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
      }
    }
  }

  Process {
    id: cpuTempProc
    command: ["sh", "-c", root._hwmonTempPath.length > 0 ? "cat " + root._hwmonTempPath : "echo 0"]
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
    command: ["sh", "-c", root._hwmonFanPath.length > 0 ? "paste -d ' ' " + root._hwmonFanPath + "/fan1_input " + root._hwmonFanPath + "/fan2_input" : "echo '0 0'"]
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
}