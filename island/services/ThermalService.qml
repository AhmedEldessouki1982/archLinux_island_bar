import Quickshell.Io
import QtQuick

// Hardware telemetry exists only while the health panel is open. ASUS fan
// readings come directly from hwmon; NVIDIA is queried only while its PCI
// function reports runtime_status=active. On hybrid laptops that means the
// discrete GPU is runtime-suspended most of the time, so the AMD integrated
// GPU (always powered) is read as the fallback source for the GPU card.
Item {
  id: root
  visible: false

  property real cpuTemp: 0
  property real cpuFanSpeed: -1
  property real gpuFanSpeed: -1
  property real gpuTemp: -1
  property real gpuLoad: -1
  property bool gpuSuspended: true
  property bool active: false
  property real igpuTemp: -1
  property real igpuLoad: -1
  property bool igpuAvailable: false
  property string _asusHwmon: ""
  property string _cpuTempPath: ""
  property string _cpuFanPath: ""
  property string _gpuFanPath: ""
  property string _gpuRuntimePath: ""
  property string _igpuTempPath: ""
  property string _igpuLoadPath: ""
  property string _igpuLoadCmd: ""

  // Which reading the GPU card should show. The dGPU wins whenever it is
  // awake; otherwise the always-on integrated GPU keeps the card live instead
  // of blanking it to dashes.
  readonly property bool showIgpu: root.gpuSuspended && root.igpuAvailable
  readonly property bool gpuReading: !root.gpuSuspended || root.showIgpu
  readonly property real gpuTempOut: root.gpuSuspended ? root.igpuTemp : root.gpuTemp
  readonly property real gpuLoadOut: root.gpuSuspended ? root.igpuLoad : root.gpuLoad

  function start() {
    if (root.active) return
    root.active = true
    root.gpuLoad = -1
    root.gpuTemp = -1
    root.gpuSuspended = true
    root.igpuTemp = -1
    root.igpuLoad = -1
    root.igpuAvailable = false
    if (!resolveProc.running) resolveProc.running = true
  }

  function stop() {
    root.active = false
    resolveProc.running = false
    gpuSampleProc.running = false
    igpuLoadProc.running = false
    runtimePoll.stop()
    root.gpuLoad = -1
    root.gpuTemp = -1
    root.gpuSuspended = true
    root.igpuTemp = -1
    root.igpuLoad = -1
    root.igpuAvailable = false
  }

  Process {
    id: resolveProc
    command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat $d/name 2>/dev/null); [ \"$n\" = asus ] && echo H:$d; [ \"$n\" = k10temp ] && echo T:$d/temp1_input; [ \"$n\" = amdgpu ] && echo I:$d/temp1_input; done; for d in /sys/class/drm/card*/device; do [ -r $d/gpu_busy_percent ] && echo L:$d/gpu_busy_percent && break; done; for d in /sys/bus/pci/devices/*; do [ \"$(cat $d/vendor 2>/dev/null)\" = 0x10de ] && [ -r $d/power/runtime_status ] && echo N:$d/power/runtime_status && break; done"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        if (!root.active) return
        var line = String(data).trim()
        if (line.indexOf("H:") === 0) {
          root._asusHwmon = line.slice(2)
          root._cpuFanPath = root._asusHwmon + "/fan1_input"
          root._gpuFanPath = root._asusHwmon + "/fan2_input"
          cpuFanView.reload(); gpuFanView.reload()
        } else if (line.indexOf("T:") === 0) {
          root._cpuTempPath = line.slice(2)
          cpuTempView.reload()
        } else if (line.indexOf("I:") === 0) {
          root._igpuTempPath = line.slice(2)
          igpuTempView.reload()
        } else if (line.indexOf("L:") === 0) {
          root._igpuLoadPath = line.slice(2)
          root._igpuLoadCmd = "p=" + root._igpuLoadPath
            + "; a=$(for i in 1 2 3 4 5; do cat \"$p\" 2>/dev/null; done | sort -n)"
            + "; set -- $a; [ $# -eq 5 ] && echo $(( ($2 + $3 + $4) / 3 ))"
          if (root.active) igpuLoadProc.running = true
        } else if (line.indexOf("N:") === 0) {
          root._gpuRuntimePath = line.slice(2)
          runtimeView.reload()
          if (root.active) runtimePoll.start()
        }
      }
    }
  }

  FileView {
    id: cpuTempView
    path: root._cpuTempPath
    watchChanges: false
    onLoaded: {
      var v = parseInt(text().trim(), 10)
      if (isFinite(v) && v > 0) root.cpuTemp = v / 1000
    }
  }
  FileView {
    id: cpuFanView
    path: root._cpuFanPath
    watchChanges: false
    onLoaded: {
      var v = parseInt(text().trim(), 10)
      root.cpuFanSpeed = isFinite(v) && v >= 0 ? v : -1
    }
  }
  FileView {
    id: gpuFanView
    path: root._gpuFanPath
    watchChanges: false
    onLoaded: {
      var v = parseInt(text().trim(), 10)
      root.gpuFanSpeed = isFinite(v) && v >= 0 ? v : -1
    }
  }
  FileView {
    id: igpuTempView
    path: root._igpuTempPath
    watchChanges: false
    onLoaded: {
      var v = parseInt(text().trim(), 10)
      if (isFinite(v) && v > 0) {
        root.igpuTemp = v / 1000
        root.igpuAvailable = true
      }
    }
  }
  // amdgpu exposes gpu_busy_percent as an instantaneous snapshot that flickers
  // between 0 and 99 from one read to the next. A 5-read burst with the min and
  // max dropped gives a stable, representative figure for the 2 s refresh.
  Process {
    id: igpuLoadProc
    command: ["sh", "-c", root._igpuLoadCmd]
    running: false
    stdout: SplitParser {
      onRead: data => {
        if (!root.active) return
        var v = parseInt(String(data).trim(), 10)
        if (isFinite(v) && v >= 0 && v <= 100) {
          root.igpuLoad = v
          if (root.igpuTemp > 0) root.igpuAvailable = true
        }
      }
    }
  }
  FileView {
    id: runtimeView
    path: root._gpuRuntimePath
    watchChanges: false
    onLoaded: root.updateGpuRuntime(text().trim())
  }

  Timer {
    id: runtimePoll
    interval: 2000
    repeat: true
    running: false
    onTriggered: if (root.active && root._gpuRuntimePath.length > 0) runtimeView.reload()
  }

  function updateGpuRuntime(state) {
    if (!root.active) return
    var s = String(state).toLowerCase()
    var suspended = s.indexOf("suspend") >= 0 || s === "off" || s.indexOf("d3") >= 0
    root.gpuSuspended = suspended
    if (suspended) {
      root.gpuLoad = -1
      root.gpuTemp = -1
      gpuSampleProc.running = false
    } else {
      if (!gpuSampleProc.running) gpuSampleProc.running = true
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.active
    onTriggered: {
      if (root._cpuTempPath.length > 0) cpuTempView.reload()
      if (root._cpuFanPath.length > 0) cpuFanView.reload()
      if (root._gpuFanPath.length > 0) gpuFanView.reload()
      if (root._igpuTempPath.length > 0) igpuTempView.reload()
      if (root._igpuLoadCmd.length > 0 && !igpuLoadProc.running) igpuLoadProc.running = true
    }
  }

  Process {
    id: gpuSampleProc
    command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,power.draw", "--format=csv,noheader,nounits"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        if (!root.active || root.gpuSuspended) return
        var parts = String(data).trim().split(/,\s*/)
        var load = Number(parts[0])
        var temp = Number(parts[1])
        if (isFinite(load) && load >= 0 && load <= 100) root.gpuLoad = load
        if (isFinite(temp) && temp >= 0) root.gpuTemp = temp
      }
    }
  }
}
