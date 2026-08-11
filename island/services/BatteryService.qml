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
  property bool charging: !UPower.onBattery
  property real power: root.battery ? root.battery.changeRate : 0
  property int chargeLimit: 0

  function refreshChargeLimit() {
    getLimitProc.running = true
  }

  function setLimit(pct) {
    root.chargeLimit = Math.max(20, Math.min(100, pct))
    setLimitProc.running = true
  }

  Process {
    id: getLimitProc
    command: ["sh", "-c", "echo \"$(asusctl battery info 2>/dev/null)\" | grep -o '[0-9]*' | head -1"]
    running: false
    stdout: SplitParser {
      onRead: data => {
        var v = parseInt(String(data).trim(), 10)
        if (!isNaN(v) && v >= 20 && v <= 100) root.chargeLimit = v
      }
    }
  }

  Process {
    id: setLimitProc
    command: ["sh", "-c", "asusctl battery limit " + root.chargeLimit + " 2>/dev/null"]
    running: false
    onExited: () => { root.refreshChargeLimit() }
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
    root.refreshChargeLimit()
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    onTriggered: {
      if (!root.battery) root.pickBattery()
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    onTriggered: root.refreshChargeLimit()
  }
}
