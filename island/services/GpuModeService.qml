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

  // asusctl and supergfxctl are optional. The panel hides the ASUS cards when
  // the matching tool is missing, so a machine without them never shows an
  // empty GPU MODE card or a PROFILE chip that cannot do anything.
  property bool asusctlAvailable: false
  property bool supergfxctlAvailable: false
  property bool toolsChecked: false

  function start() {
    if (!root.toolsChecked) {
      if (!toolsProc.running) toolsProc.running = true
      return
    }
    root.startReaders()
  }

  function startReaders() {
    if (root.supergfxctlAvailable && !gfxModeProc.running) gfxModeProc.running = true
    if (root.asusctlAvailable && !pwrProfileProc.running) pwrProfileProc.running = true
  }

  function cyclePowerProfile() {
    if (!root.asusctlAvailable || root.profileChanging || pwrProfileProc.running) return
    var profiles = root.availableProfiles.length > 0
      ? root.availableProfiles : ["Quiet", "Balanced", "Performance"]
    var current = profiles.indexOf(root.powerProfile)
    root.powerProfile = profiles[(current + 1) % profiles.length]
    root.profileChanging = true
    profileCycleProc.running = true
  }

  function setGpuMode(mode) {
    if (!root.supergfxctlAvailable || root.gpuModeChanging || !mode
        || root.availableGpuModes.indexOf(mode) < 0)
      return
    root.gpuModeChanging = true
    setGpuModeProc.command = ["supergfxctl", "-m", mode]
    setGpuModeProc.running = true
  }

  function stop() {
    // one-shot; no timer to stop
  }

  // One `command -v` per tool, once per shell lifetime. Both tools print their
  // state, so the panel never has to guess whether a blank value means "off",
  // "loading" or "not installed".
  Process {
    id: toolsProc
    command: ["sh", "-c", "command -v supergfxctl >/dev/null 2>&1 && echo S:1 || echo S:0; command -v asusctl >/dev/null 2>&1 && echo A:1 || echo A:0"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = String(data).trim()
        if (line === "S:1") root.supergfxctlAvailable = true
        else if (line === "S:0") root.supergfxctlAvailable = false
        else if (line === "A:1") root.asusctlAvailable = true
        else if (line === "A:0") root.asusctlAvailable = false
      }
    }
    onExited: {
      root.toolsChecked = true
      root.startReaders()
    }
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
