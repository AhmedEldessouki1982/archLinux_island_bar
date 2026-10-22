import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Item {
  id: root
  visible: false

  property string gpuMode: ""
  property string gpuPowerStatus: ""
  property var availableGpuModes: []
  property bool gpuModeChanging: false
  property string powerProfile: ""
  property var availableProfiles: []
  property bool profileChanging: false

  function start() {
    if (!gfxModeProc.running) gfxModeProc.running = true
    if (!pwrProfileProc.running) pwrProfileProc.running = true
  }

  function cyclePowerProfile() {
    if (root.profileChanging || pwrProfileProc.running) return
    var profiles = root.availableProfiles.length > 0
      ? root.availableProfiles : ["Quiet", "Balanced", "Performance"]
    var current = profiles.indexOf(root.powerProfile)
    root.powerProfile = profiles[(current + 1) % profiles.length]
    root.profileChanging = true
    profileCycleProc.running = true
  }

  function setGpuMode(mode) {
    if (root.gpuModeChanging || !mode || root.availableGpuModes.indexOf(mode) < 0)
      return
    root.gpuModeChanging = true
    setGpuModeProc.command = ["supergfxctl", "-m", mode]
    setGpuModeProc.running = true
  }

  function stop() {
    // one-shot; no timer to stop
  }

  Process {
    id: gfxModeProc
    command: ["sh", "-c", "echo M:$(supergfxctl -g) && echo S:$(supergfxctl -S) && echo L:$(supergfxctl -s)"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = data.trim()
        if (line.indexOf("M:") === 0) root.gpuMode = line.substring(2)
        else if (line.indexOf("S:") === 0) root.gpuPowerStatus = line.substring(2)
        else if (line.indexOf("L:") === 0) {
          var raw = line.substring(2).replace(/[\[\]]/g, "")
          root.availableGpuModes = raw.split(",").map(v => v.trim()).filter(v => v.length > 0)
        }
      }
    }
  }

  Process {
    id: pwrProfileProc
    command: ["sh", "-c", "asusctl profile list 2>/dev/null | sed 's/^/L:/'; asusctl profile get 2>/dev/null | sed -n '1s/^/A:/p'"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = data.trim()
        if (v.indexOf("L:") === 0) {
          var profile = v.substring(2).trim()
          if (profile.length > 0 && root.availableProfiles.indexOf(profile) < 0) {
            var copy = root.availableProfiles.slice()
            copy.push(profile)
            root.availableProfiles = copy
          }
        } else if (v.indexOf("A:Active profile:") === 0) {
          root.powerProfile = v.substring("A:Active profile:".length).trim()
        }
      }
    }
  }

  Process {
    id: profileCycleProc
    command: ["asusctl", "profile", "next"]
    running: false
    onExited: code => {
      root.profileChanging = false
      if (!pwrProfileProc.running) pwrProfileProc.running = true
    }
  }


  Process {
    id: setGpuModeProc
    command: ["true"]
    running: false
    onExited: code => {
      root.gpuModeChanging = false
      if (!gfxModeProc.running) gfxModeProc.running = true
    }
  }
}
