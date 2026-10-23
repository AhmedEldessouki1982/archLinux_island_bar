import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// UPower verification on Quickshell 0.3.0 (unlike Quickshell.Services.Pipewire,
// where PwNodeAudio.volume/.muted read 0 and PwLink.state is stuck):
//   - UPowerDevice.percentage -> 0..1 fraction (NOT 0..100), live
//   - UPowerDevice.state      -> raw UPowerDeviceState (Charging=1,
//     Discharging=2, FullyCharged=4, PendingCharge=5); stateChanged fires on
//     AC plug/unplug
//   - UPowerDevice.changeRate -> real watts, changeRateChanged fires
// All three verified against sysfs /sys/class/power_supply/BAT0 through a live
// AC plug/unplug cycle. No polling fallback needed.

Item {
  id: root
  visible: false

  property var battery: null
  property int capacity: root.battery ? Math.round(root.battery.percentage * 100) : 0
  property bool charging: root.battery ? root.battery.state === UPowerDeviceState.Charging : false
  readonly property bool onAcPower: !UPower.onBattery
  property real power: root.battery ? root.battery.changeRate : 0
  property int chargeLimit: 0
  property bool chargeLimitRead: false
  property bool chargeLimitSupported: false
  property bool chargeLimitMonitoring: false
  property bool chargeLimitReading: false
  property bool chargeLimitSetting: false
  property bool chargeLimitError: false
  property bool chargeLimitSetConfirmed: false
  property int _expectedChargeLimit: -1
  property bool _verifyingChargeLimit: false

  function refreshChargeLimit() {
    if (!getLimitProc.running) {
      root.chargeLimitRead = false
      root.chargeLimitReading = true
      getLimitProc.running = true
    }
  }

  function setLimit(pct) {
    if (!root.chargeLimitSupported || getLimitProc.running || setLimitProc.running) return
    root.chargeLimitSetting = true
    root.chargeLimitError = false
    root.chargeLimitSetConfirmed = false
    root._expectedChargeLimit = Math.max(20, Math.min(100, pct))
    root._verifyingChargeLimit = false
    setLimitProc.command = ["asusctl", "battery", "limit", String(Math.max(20, Math.min(100, pct)))]
    setLimitProc.running = true
  }

  Process {
    id: getLimitProc
    command: ["sh", "-c", "if asusctl battery --help 2>/dev/null | grep -Eq 'limit.*20-100'; then echo S:1; asusctl battery info 2>/dev/null | sed 's/^/V:/'; else echo S:0; fi"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var line = String(data).trim()
        if (line === "S:1") root.chargeLimitSupported = true
        else if (line === "S:0") root.chargeLimitSupported = false
        else if (line.indexOf("V:") === 0) {
          // Match only a labelled limit field, never the present battery
          // percentage if the command prints both on the same line.
          var match = line.match(/(?:charge\s+limit|limit)\s*[:=]?\s*([0-9]{1,3})\s*%?/i)
          var v = match ? parseInt(match[1], 10) : NaN
          if (!isNaN(v) && v >= 20 && v <= 100) {
            root.chargeLimit = v
            root.chargeLimitRead = true
            if (root._verifyingChargeLimit) {
              root._verifyingChargeLimit = false
              root.chargeLimitSetting = false
              if (v === root._expectedChargeLimit) {
                root.chargeLimitError = false
                root.chargeLimitSetConfirmed = true
              } else {
                root.chargeLimitError = true
              }
            }
          }
        }
      }
    }
    onExited: (exitCode, exitStatus) => {
      root.chargeLimitReading = false
      if (root._verifyingChargeLimit && !root.chargeLimitRead) {
        root._verifyingChargeLimit = false
        root.chargeLimitSetting = false
        root.chargeLimitError = true
      }
    }
  }

  Process {
    id: setLimitProc
    command: ["true"]
    running: false
    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0 || exitStatus !== 0) {
        root.chargeLimitSetting = false
        root.chargeLimitError = true
        root._verifyingChargeLimit = false
      } else {
        root._verifyingChargeLimit = true
        root.refreshChargeLimit()
      }
    }
  }

  function pickBattery() {
    var vals = UPower.devices.values
    for (var i = 0; i < vals.length; i++) {
      var d = vals[i]
      if (d.isLaptopBattery) {
        root.battery = d
        return
      }
    }
  }

  Connections {
    target: UPower.devices
    function onValuesChanged() { root.pickBattery() }
  }

  Component.onCompleted: {
    root.pickBattery()
  }

  onChargeLimitMonitoringChanged: if (root.chargeLimitMonitoring) root.refreshChargeLimit()

}
